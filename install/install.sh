#!/usr/bin/env bash
# Installs the PS5 trophy themes into Steam Achievement Notifier (SAN) on Linux.
#
# Usage:
#   bash install.sh [--dir <SAN data folder>] [--no-activate]
#   bash install.sh --help
#   curl -fsSL https://raw.githubusercontent.com/ianraubet/san-ps5-trophy-themes/main/install/install.sh | bash
#
# Options:
#   --dir <path>      SAN data folder containing config.json (env: SAN_DIR)
#   --no-activate     Only add/replace the themes; keep the active theme and trophy mode
#   -h, --help        Show this help
#
# Environment (for piped runs): SAN_DIR, SAN_NO_ACTIVATE=1
# Testing only: SAN_SKIP_PROCESS_CHECK=1 skips the "SAN is running" check.

set -euo pipefail

REPO="ianraubet/san-ps5-trophy-themes"
BRANCH="main"
# <file name>:<SAN type>
THEME_FILES=(
    "1.ps5_bronze.san:main"
    "2.ps5_silver.san:semi"
    "3.ps5_gold.san:rare"
    "4.ps5_platinum.san:plat"
)

TMP_DIR=""
cleanup() {
    if [[ -n "${TMP_DIR:-}" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

die() {
    echo "ERROR: $*" >&2
    exit 1
}

info() {
    echo "==> $*"
}

usage() {
    cat <<'EOF'
Steam Achievement Notifier - PS5 trophy theme installer (Linux)

Usage:
  bash install.sh [--dir <SAN data folder>] [--no-activate]

Options:
  --dir <path>    SAN data folder containing config.json, e.g.
                  "$HOME/.local/share/Steam Achievement Notifier (V1.9)"
                  (default: the highest installed version)
  --no-activate   Only add or replace the themes. The active theme and
                  trophy mode are left unchanged.
  -h, --help      Show this help

Environment variables (useful when piping the script into bash):
  SAN_DIR=<path>          Same as --dir
  SAN_NO_ACTIVATE=1       Same as --no-activate
EOF
}

SAN_DIR_OVERRIDE="${SAN_DIR:-}"
ACTIVATE=1
if [[ "${SAN_NO_ACTIVATE:-}" == "1" ]]; then
    ACTIVATE=0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            [[ $# -ge 2 ]] || die "--dir needs a path"
            SAN_DIR_OVERRIDE="$2"
            shift 2
            ;;
        --dir=*)
            SAN_DIR_OVERRIDE="${1#--dir=}"
            shift
            ;;
        --no-activate)
            ACTIVATE=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die "unknown option: $1"
            ;;
    esac
done

command -v python3 >/dev/null 2>&1 || die "python3 is required but was not found in PATH"

# ---------------------------------------------------------------------------
# 1. Locate the theme files (next to this script, or download them)
# ---------------------------------------------------------------------------
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

THEMES_DIR=""
if [[ -n "$SCRIPT_DIR" && -d "$SCRIPT_DIR/../themes" ]]; then
    all_local=1
    for entry in "${THEME_FILES[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/../themes/${entry%%:*}" ]]; then
            all_local=0
        fi
    done
    if [[ "$all_local" -eq 1 ]]; then
        THEMES_DIR="$(cd "$SCRIPT_DIR/../themes" && pwd)"
        info "Using theme files from $THEMES_DIR"
    fi
fi

if [[ -z "$THEMES_DIR" ]]; then
    command -v curl >/dev/null 2>&1 || die "curl is required to download the theme files"
    TMP_DIR="$(mktemp -d)"
    THEMES_DIR="$TMP_DIR/themes"
    mkdir -p "$THEMES_DIR"
    info "Downloading theme files from $REPO ($BRANCH)"
    for entry in "${THEME_FILES[@]}"; do
        name="${entry%%:*}"
        curl -fsSL --proto '=https' --tlsv1.2 \
            -o "$THEMES_DIR/$name" \
            "https://raw.githubusercontent.com/$REPO/$BRANCH/themes/$name" \
            || die "could not download themes/$name"
    done
fi

# ---------------------------------------------------------------------------
# 2. Find the SAN data folder
# ---------------------------------------------------------------------------
DATA_DIR="$(python3 -I - "$SAN_DIR_OVERRIDE" "$HOME/.local/share" <<'PY'
import os
import re
import sys

override, base = sys.argv[1], sys.argv[2]


def fail(msg):
    sys.stderr.write("ERROR: " + msg + "\n")
    sys.exit(1)


if override:
    path = os.path.abspath(os.path.expanduser(override))
    if not os.path.isfile(os.path.join(path, "config.json")):
        fail('no config.json in "%s". Check --dir, or open SAN once first.' % path)
    print(path)
    sys.exit(0)

pattern = re.compile(r"^Steam Achievement Notifier \(V(\d+)\.(\d+)\)$")
found = []
if os.path.isdir(base):
    for name in os.listdir(base):
        match = pattern.match(name)
        full = os.path.join(base, name)
        if match and os.path.isdir(full):
            found.append(((int(match.group(1)), int(match.group(2))), full))

if not found:
    fail('no Steam Achievement Notifier data folder found in "%s". Open SAN once first, or use --dir.' % base)

found.sort(reverse=True)
for version, path in found:
    if os.path.isfile(os.path.join(path, "config.json")):
        if len(found) > 1:
            sys.stderr.write("Found %d SAN data folders; using the highest version (V%d.%d). Use --dir to choose another.\n" % (len(found), version[0], version[1]))
        print(path)
        sys.exit(0)

fail('found "%s" but it has no config.json. Open SAN once first, or use --dir.' % found[0][1])
PY
)" || die "could not find the SAN data folder"

info "SAN data folder: $DATA_DIR"

# ---------------------------------------------------------------------------
# 3. Refuse to run while SAN is running
# ---------------------------------------------------------------------------
if [[ "${SAN_SKIP_PROCESS_CHECK:-}" != "1" ]]; then
    running=""
    for proc in /proc/[0-9]*; do
        pid="${proc#/proc/}"
        if [[ "$pid" == "$$" || "$pid" == "$PPID" ]]; then
            continue
        fi
        comm="$(cat "$proc/comm" 2>/dev/null || true)"
        lc="${comm,,}"
        # Process names are truncated to 15 characters, e.g. "steamachievemen"
        if [[ "$lc" == steam*achiev* ]]; then
            running="$pid ($comm)"
            break
        fi
    done
    if [[ -n "$running" ]]; then
        die "Steam Achievement Notifier appears to be running: PID $running.
Quit it from the system tray (right-click the icon, then Quit), then run this installer again."
    fi
else
    info "SAN_SKIP_PROCESS_CHECK=1 set - skipping the running-process check"
fi

# ---------------------------------------------------------------------------
# 4. Back up config.json, install the themes and update config.json
# ---------------------------------------------------------------------------
THEME_ARGS=()
for entry in "${THEME_FILES[@]}"; do
    name="${entry%%:*}"
    type="${entry##*:}"
    THEME_ARGS+=("$type=$THEMES_DIR/$name")
done

python3 -I - "$DATA_DIR" "$ACTIVATE" "${THEME_ARGS[@]}" <<'PY'
import copy
import datetime
import json
import os
import re
import shutil
import sys
import zipfile

data_dir = sys.argv[1]
activate = sys.argv[2] == "1"
themes = [arg.split("=", 1) for arg in sys.argv[3:]]

# Mirrors customfilekeys / settingslvlkeys in src/app/config.ts
CUSTOMFILEKEYS = [
    "bgimg", "customfont", "customicons", "customimgicon", "hiddenicon",
    "maskimg", "sounddir", "soundfile",
    "percentbadgeimgbronze", "sspercentbadgeimgbronze",
    "percentbadgeimgsilver", "sspercentbadgeimgsilver",
    "percentbadgeimggold", "sspercentbadgeimggold",
    "iconborderimgbronze", "iconborderimgsilver", "iconborderimg",
]
SETTINGS_KEYS = ["ovpos", "ovx", "ovy", "ovmatch", "elemsmatch"]


def fail(msg):
    sys.stderr.write("ERROR: " + msg + "\n")
    sys.exit(1)


def is_obj(value):
    return isinstance(value, dict)


def basename(value):
    return value.replace("\\", "/").rsplit("/", 1)[-1]


def rewrite_path(assetsdir, value):
    # Mirrors rewritepath() in usertheme.ts: <assetsdir>/<basename>
    return os.path.join(assetsdir, basename(value)).replace("\\", "/")


def rewrite_leaves(value, assetsdir, key, warnings):
    if is_obj(value):
        return {k: rewrite_leaves(v, assetsdir, k, warnings) for k, v in value.items()}
    if key.endswith("elems"):
        return value
    if isinstance(value, str) and value:
        return rewrite_path(assetsdir, value)
    if isinstance(value, list):
        return [rewrite_path(assetsdir, v) if isinstance(v, str) and v else v for v in value]
    return value


def extract_san(san_path, dest):
    with zipfile.ZipFile(san_path) as z:
        infos = z.infolist()
        for info in infos:
            name = info.filename.replace("\\", "/")
            parts = [p for p in name.split("/") if p not in ("", ".")]
            if name.startswith("/") or re.match(r"^[A-Za-z]:", name) or ".." in parts:
                fail('unsafe path "%s" in "%s"' % (info.filename, san_path))
        if os.path.isdir(dest):
            shutil.rmtree(dest)
        os.makedirs(dest)
        for info in infos:
            parts = [p for p in info.filename.replace("\\", "/").split("/") if p not in ("", ".")]
            if not parts:
                continue
            target = os.path.join(dest, *parts)
            if info.filename.endswith("/"):
                os.makedirs(target, exist_ok=True)
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with z.open(info) as src, open(target, "wb") as out:
                shutil.copyfileobj(src, out)


config_path = os.path.join(data_dir, "config.json")
try:
    with open(config_path, encoding="utf-8-sig") as f:
        cfg = json.load(f)
except (OSError, ValueError) as err:
    fail('could not read "%s": %s' % (config_path, err))

if not is_obj(cfg.get("customisation")):
    fail('"customisation" missing from config.json')
for typ, _ in themes:
    if not is_obj(cfg["customisation"].get(typ)):
        fail('"customisation.%s" missing from config.json' % typ)

# Back up config.json before touching anything
stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
backup = os.path.join(data_dir, "config.json.bak-" + stamp)
n = 1
while os.path.exists(backup):
    backup = os.path.join(data_dir, "config.json.bak-%s-%d" % (stamp, n))
    n += 1
shutil.copy2(config_path, backup)
print("Backed up config.json to: " + backup)

summary = []
for typ, san_path in themes:
    file_name = os.path.basename(san_path)
    stem = os.path.splitext(file_name)[0]
    dir_name = "%s_%s" % (stem, typ)
    udir = os.path.join(data_dir, "userthemes", dir_name)
    assets = os.path.join(udir, "assets")
    warnings = []

    extract_san(san_path, udir)

    json_path = os.path.join(udir, "usertheme.json")
    if not os.path.isfile(json_path):
        fail('"usertheme.json" missing from "%s"' % file_name)
    with open(json_path, encoding="utf-8-sig") as f:
        imported = json.load(f)
    if not is_obj(imported.get("customisation")) or not imported.get("label"):
        fail('"%s" has no valid "customisation" or "label"' % file_name)

    current = cfg["customisation"][typ]

    # Rewrite asset paths into the extracted folder (SAN import)
    new_cust = dict(imported["customisation"])
    new_cust.pop("usertheme", None)
    for key in CUSTOMFILEKEYS:
        if key in new_cust:
            new_cust[key] = rewrite_leaves(new_cust[key], assets, key, warnings)

    # Blank customicons presets are filled with defaults by SAN. The defaults
    # live in the SAN install folder, so reuse the value the current config has.
    icons = new_cust.get("customicons")
    if is_obj(icons):
        cur_icons = current.get("customicons") if is_obj(current.get("customicons")) else {}
        for preset, value in icons.items():
            if value == "":
                if cur_icons.get(preset) not in (None, ""):
                    icons[preset] = copy.deepcopy(cur_icons[preset])
                else:
                    warnings.append('customicons.%s is blank and has no current default' % preset)

    imported["icon"] = os.path.join(assets, basename(str(imported.get("icon", "")))).replace("\\", "/")
    imported["userthemedir"] = dir_name
    imported["customisation"] = new_cust
    with open(json_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(imported, f, indent=4, ensure_ascii=False)

    # Count referenced files that are missing
    def walk_paths(value):
        if is_obj(value):
            for v in value.values():
                yield from walk_paths(v)
        elif isinstance(value, list):
            for v in value:
                yield from walk_paths(v)
        elif isinstance(value, str) and value.replace("\\", "/").startswith(assets.replace("\\", "/")):
            yield value

    missing = sorted({p for p in walk_paths(new_cust) if not os.path.exists(p)})
    if imported["icon"] and not os.path.exists(imported["icon"]):
        missing.append(imported["icon"])
    for path in missing:
        warnings.append("missing asset: " + path)

    # Build the usertheme entry the way usertheme.create() does
    entry_cust = copy.deepcopy(new_cust)
    for key in SETTINGS_KEYS:
        entry_cust.pop(key, None)
    user_list = current.get("usertheme")
    if not isinstance(user_list, list):
        user_list = []
        current["usertheme"] = user_list

    label = imported["label"]
    match = next((i for i, t in enumerate(user_list) if is_obj(t) and t.get("label") == label), None)
    if match is not None:
        new_id = user_list[match].get("id")
        keep_enabled = user_list[match].get("enabled") is True
    else:
        ids = [t.get("id") for t in user_list if is_obj(t) and isinstance(t.get("id"), int)]
        new_id = max(ids) + 1 if ids else 0
        keep_enabled = False

    entry = {
        "id": new_id,
        "label": label,
        "icon": imported["icon"],
        "customisation": entry_cust,
        "enabled": True if activate else keep_enabled,
        "userthemedir": dir_name,
    }
    if cfg.get("usecustomfiles"):
        entry["usecustomfiles"] = True

    if activate:
        new_list = [dict(t, enabled=False) if is_obj(t) else t for t in user_list]
    else:
        new_list = [dict(t) if is_obj(t) else t for t in user_list]
    if match is not None:
        new_list[match] = entry
    else:
        new_list.append(entry)

    if activate or entry["enabled"]:
        # Same as usertheme.set(): theme customisation + current settings-level keys + usertheme list
        active = copy.deepcopy(entry_cust)
        for key in SETTINGS_KEYS:
            if key in current:
                active[key] = current[key]
        for t in new_list:
            if is_obj(t) and is_obj(t.get("customisation")):
                t["customisation"].pop("usertheme", None)
        active["usertheme"] = new_list
        cfg["customisation"][typ] = active
    else:
        current["usertheme"] = new_list

    if activate:
        cfg["trophymode"] = True

    for warning in warnings:
        print("  WARN (%s): %s" % (typ, warning))
    summary.append((typ, label, new_id, entry["enabled"], dir_name))

text = json.dumps(cfg, indent="\t", ensure_ascii=False)
tmp_path = config_path + ".tmp-%d" % os.getpid()
with open(tmp_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())
os.replace(tmp_path, config_path)

# Verify what was written
with open(config_path, encoding="utf-8") as f:
    json.load(f)

for typ, label, new_id, enabled, dir_name in summary:
    state = "active" if enabled else "added (not active)"
    print("  %-5s %-16s id=%-3s %s  [userthemes/%s]" % (typ, label, new_id, state, dir_name))
if activate:
    print("  trophymode set to true")
else:
    print("  active themes and trophymode left unchanged (--no-activate)")
print("Restore the previous config with:")
print("  cp '%s' '%s'" % (backup, config_path))
PY

echo
info "Done. Start Steam Achievement Notifier to use the PS5 trophy themes."
