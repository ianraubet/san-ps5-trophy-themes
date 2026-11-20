**English** | [Português (Brasil)](README.pt-BR.md)

# PS5 Trophy Themes for Steam Achievement Notifier

PS5-style trophy notification themes for [Steam Achievement Notifier](https://github.com/steamachievementnotifier/steamachievementnotifier) (SAN), for Windows and Linux.

## What's included

| File | SAN Trophy Mode slot |
| --- | --- |
| `themes/1.ps5_bronze.san` | Bronze → Bronze (main) |
| `themes/2.ps5_silver.san` | Silver → Silver (semi) |
| `themes/3.ps5_gold.san` | Gold → Gold (rare) |
| `themes/4.ps5_platinum.san` | Platinum → Platinum (plat) |

The platinum theme uses the animated `.webp` trophy and the platinum sound. The other three use the standard trophy sound.

## Requirements

- Steam Achievement Notifier installed, and opened at least once (Windows or Linux AppImage).
- Linux installer only: `python3`.

## Automatic install

**Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/ianraubet/san-ps5-trophy-themes/main/install/install.sh | bash
```

Or from a clone of this repository:

```bash
./install/install.sh
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/ianraubet/san-ps5-trophy-themes/main/install/install.ps1 | iex
```

Or from a clone of this repository:

```powershell
powershell -ExecutionPolicy Bypass -File install\install.ps1
```

### What the installer does

1. Asks you to close SAN first (it must not be running).
2. Backs up SAN's `config.json` to `config.json.bak-<timestamp>` in the SAN data folder.
3. Extracts each theme into SAN's `userthemes` folder.
4. Adds the four themes (replacing them if they already exist) and activates them.
5. Enables Trophy Mode.

Options:

- `--dir <path>` (Linux) / `-SanDir <path>` (Windows): point the installer at the SAN data folder if it is not in the default location.
- `--no-activate` (Linux) / `-NoActivate` (Windows): only add the themes, without switching the active theme or turning on Trophy Mode.

SAN data folder locations:

- Linux: `~/.local/share/Steam Achievement Notifier (V<version>)`
- Windows: `%LOCALAPPDATA%\Steam Achievement Notifier (V<version>)`

### Restoring your previous settings

Close SAN, then copy the backup over `config.json` in the SAN data folder.

## Manual install

1. In SAN, enable **Settings → Trophy Mode**.
2. For each notification type, open **Customiser → Theme Switcher → Import** and choose the matching `.san` file from `themes/`.

## Raw resources

For people building their own themes:

- `images/`: trophy icons (bronze, silver, gold, plat, hidden) and the PS button icon.
- `sounds/`: trophy and platinum sounds (`.mp3`).
- `videos/`: the animated platinum trophy (`.webp`).

## License

- The MIT License (see [LICENSE](LICENSE)) covers the theme configurations, install scripts and documentation.
- Trophy icons, sounds and animation are property of Sony Interactive Entertainment and are included for non-commercial personalization only. SAN project images bundled in the `.san` files belong to the Steam Achievement Notifier project. See [NOTICE.md](NOTICE.md) for details.
- This project is not affiliated with or endorsed by Sony, Valve, or the Steam Achievement Notifier project. "PlayStation" and "PS5" are trademarks of Sony.
