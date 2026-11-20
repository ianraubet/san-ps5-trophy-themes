# Installs the PS5 trophy themes into Steam Achievement Notifier (SAN) on Windows.
# Works with Windows PowerShell 5.1 and PowerShell 7.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install.ps1 [-SanDir <SAN data folder>] [-NoActivate]
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Help
#   irm https://raw.githubusercontent.com/ianraubet/san-ps5-trophy-themes/main/install/install.ps1 | iex
#
# Options:
#   -SanDir <path>    SAN data folder containing config.json (env: SAN_DIR)
#   -NoActivate       Only add/replace the themes; keep the active theme and trophy mode
#   -Help, -h         Show help
#
# Environment (for iex runs, which cannot take arguments): SAN_DIR, SAN_NO_ACTIVATE=1
# Testing only: SAN_SKIP_PROCESS_CHECK=1 skips the "SAN is running" check.

param(
    [string]$SanDir = $env:SAN_DIR,
    [switch]$NoActivate,
    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Repo = 'ianraubet/san-ps5-trophy-themes'
$Branch = 'main'
# File name -> SAN type
$ThemeFiles = @(
    @{ Name = '1.ps5_bronze.san';   Type = 'main' },
    @{ Name = '2.ps5_silver.san';   Type = 'semi' },
    @{ Name = '3.ps5_gold.san';     Type = 'rare' },
    @{ Name = '4.ps5_platinum.san'; Type = 'plat' }
)

# Mirrors customfilekeys / settingslvlkeys in src/app/config.ts
$CustomFileKeys = @(
    'bgimg', 'customfont', 'customicons', 'customimgicon', 'hiddenicon',
    'maskimg', 'sounddir', 'soundfile',
    'percentbadgeimgbronze', 'sspercentbadgeimgbronze',
    'percentbadgeimgsilver', 'sspercentbadgeimgsilver',
    'percentbadgeimggold', 'sspercentbadgeimggold',
    'iconborderimgbronze', 'iconborderimgsilver', 'iconborderimg'
)
$SettingsKeys = @('ovpos', 'ovx', 'ovy', 'ovmatch', 'elemsmatch')

function Show-Help {
    @"
Steam Achievement Notifier - PS5 trophy theme installer (Windows)

Usage:
  powershell -ExecutionPolicy Bypass -File install.ps1 [-SanDir <path>] [-NoActivate]

Options:
  -SanDir <path>   SAN data folder containing config.json, e.g.
                   "%LOCALAPPDATA%\Steam Achievement Notifier (V1.9)"
                   (default: the highest installed version)
  -NoActivate      Only add or replace the themes. The active theme and
                   trophy mode are left unchanged.
  -Help, -h        Show this help

Environment variables (for iex runs, which cannot take arguments):
  SAN_DIR=<path>          Same as -SanDir
  SAN_NO_ACTIVATE=1       Same as -NoActivate
"@ | Write-Host
}

function Has-Prop {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $false }
    return [bool]($Obj.PSObject.Properties[$Name])
}

function Get-Prop {
    param($Obj, [string]$Name)
    if (Has-Prop $Obj $Name) { return ,$Obj.PSObject.Properties[$Name].Value }
    return $null
}

function Set-Prop {
    param($Obj, [string]$Name, $Value)
    if (Has-Prop $Obj $Name) {
        $Obj.PSObject.Properties[$Name].Value = $Value
    } else {
        Add-Member -InputObject $Obj -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Copy-Obj {
    param($Obj)
    return ,(ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $Obj -Depth 100))
}

function Get-Basename {
    param([string]$Value)
    $parts = $Value.Replace('\', '/').Split('/')
    return $parts[$parts.Count - 1]
}

function Get-AssetPath {
    # Mirrors rewritepath() in usertheme.ts: <assetsdir>/<basename>, forward slashes
    param([string]$AssetsDirFwd, [string]$Value)
    return "$AssetsDirFwd/$(Get-Basename $Value)"
}

function Convert-Leaves {
    param($Value, [string]$AssetsDirFwd, [string]$Key)
    if ($Value -is [pscustomobject]) {
        $out = [pscustomobject]@{}
        foreach ($p in $Value.PSObject.Properties) {
            Add-Member -InputObject $out -NotePropertyName $p.Name -NotePropertyValue (Convert-Leaves $p.Value $AssetsDirFwd $p.Name)
        }
        return ,$out
    }
    if ($Key -clike '*elems') { return ,$Value }
    if ($Value -is [string]) {
        if ($Value -ne '') { return ,(Get-AssetPath $AssetsDirFwd $Value) }
        return ,$Value
    }
    if ($Value -is [array]) {
        $items = New-Object System.Collections.ArrayList
        foreach ($v in $Value) {
            if ($v -is [string] -and $v -ne '') {
                [void]$items.Add((Get-AssetPath $AssetsDirFwd $v))
            } else {
                [void]$items.Add($v)
            }
        }
        return ,$items.ToArray()
    }
    return ,$Value
}

function Get-AssetRefs {
    param($Value, [string]$Prefix, $Out)
    if ($Value -is [pscustomobject]) {
        foreach ($p in $Value.PSObject.Properties) { Get-AssetRefs $p.Value $Prefix $Out }
    } elseif ($Value -is [array]) {
        foreach ($v in $Value) { Get-AssetRefs $v $Prefix $Out }
    } elseif ($Value -is [string] -and $Value.StartsWith($Prefix, [StringComparison]::Ordinal)) {
        [void]$Out.Add($Value)
    }
}

function Find-SanDataDir {
    param([string]$Override)

    if ($Override) {
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Override)
        if (Test-Path -LiteralPath (Join-Path $full 'config.json') -PathType Leaf) { return $full }
        throw "No config.json in `"$full`". Check -SanDir, or open SAN once first."
    }

    $base = $env:LOCALAPPDATA
    if (-not $base) { throw 'LOCALAPPDATA is not set.' }

    $found = New-Object System.Collections.ArrayList
    foreach ($dir in @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue)) {
        if ($dir.Name -match '^Steam Achievement Notifier \(V(\d+)\.(\d+)\)$') {
            [void]$found.Add([pscustomobject]@{
                Major = [int]$matches[1]
                Minor = [int]$matches[2]
                Path  = $dir.FullName
            })
        }
    }
    if ($found.Count -eq 0) {
        throw "No Steam Achievement Notifier data folder found in `"$base`". Open SAN once first, or use -SanDir."
    }

    $sorted = @($found | Sort-Object -Property Major, Minor -Descending)
    foreach ($f in $sorted) {
        if (Test-Path -LiteralPath (Join-Path $f.Path 'config.json') -PathType Leaf) {
            if ($sorted.Count -gt 1) {
                Write-Host ("Found {0} SAN data folders; using the highest version (V{1}.{2}). Use -SanDir to choose another." -f $sorted.Count, $f.Major, $f.Minor)
            }
            return $f.Path
        }
    }
    throw "Found `"$($sorted[0].Path)`" but it has no config.json. Open SAN once first, or use -SanDir."
}

function Expand-SanArchive {
    param([string]$SanPath, [string]$Dest)

    try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch { }

    $zip = [System.IO.Compression.ZipFile]::OpenRead($SanPath)
    try {
        foreach ($e in $zip.Entries) {
            $name = $e.FullName.Replace('\', '/')
            $parts = $name.Split('/')
            if ($name.StartsWith('/') -or $name -match '^[A-Za-z]:' -or ($parts -contains '..')) {
                throw "Unsafe path `"$($e.FullName)`" in `"$SanPath`""
            }
        }

        if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null

        foreach ($e in $zip.Entries) {
            $parts = @($e.FullName.Replace('\', '/').Split('/') | Where-Object { $_ -ne '' -and $_ -ne '.' })
            if ($parts.Count -eq 0) { continue }
            $target = $Dest
            foreach ($p in $parts) { $target = Join-Path $target $p }

            if ($e.FullName.EndsWith('/')) {
                New-Item -ItemType Directory -Path $target -Force | Out-Null
                continue
            }
            $parent = Split-Path -Parent $target
            if (-not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            $in = $e.Open()
            try {
                $out = [System.IO.File]::Create($target)
                try { $in.CopyTo($out) } finally { $out.Dispose() }
            } finally {
                $in.Dispose()
            }
        }
    } finally {
        $zip.Dispose()
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

function Main {
    if ($Help) { Show-Help; return }

    if ($env:SAN_NO_ACTIVATE -eq '1') { $NoActivate = $true }
    $activate = -not $NoActivate

    # -----------------------------------------------------------------------
    # 1. Locate the theme files (next to this script, or download them)
    # -----------------------------------------------------------------------
    $scriptDir = $null
    if ($PSScriptRoot) {
        $scriptDir = $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    $themesDir = $null
    $tmpDir = $null
    if ($scriptDir) {
        $localThemes = Join-Path (Split-Path -Parent $scriptDir) 'themes'
        $allLocal = $true
        foreach ($t in $ThemeFiles) {
            if (-not (Test-Path -LiteralPath (Join-Path $localThemes $t.Name) -PathType Leaf)) { $allLocal = $false }
        }
        if ($allLocal) {
            $themesDir = (Resolve-Path -LiteralPath $localThemes).Path
            Write-Host "==> Using theme files from $themesDir"
        }
    }

    try {
        if (-not $themesDir) {
            $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ('san-ps5-' + [guid]::NewGuid().ToString('N'))
            $themesDir = Join-Path $tmpDir 'themes'
            New-Item -ItemType Directory -Path $themesDir -Force | Out-Null
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            } catch { }
            Write-Host "==> Downloading theme files from $Repo ($Branch)"
            foreach ($t in $ThemeFiles) {
                $url = "https://raw.githubusercontent.com/$Repo/$Branch/themes/$($t.Name)"
                try {
                    Invoke-WebRequest -Uri $url -OutFile (Join-Path $themesDir $t.Name) -UseBasicParsing
                } catch {
                    throw "Could not download themes/$($t.Name): $($_.Exception.Message)"
                }
            }
        }

        # -------------------------------------------------------------------
        # 2. Find the SAN data folder
        # -------------------------------------------------------------------
        $dataDir = Find-SanDataDir -Override $SanDir
        Write-Host "==> SAN data folder: $dataDir"

        # -------------------------------------------------------------------
        # 3. Refuse to run while SAN is running
        # -------------------------------------------------------------------
        if ($env:SAN_SKIP_PROCESS_CHECK -ne '1') {
            $running = @([System.Diagnostics.Process]::GetProcesses() | Where-Object { $_.ProcessName -match '(?i)steam ?achievement' })
            if ($running.Count -gt 0) {
                throw "Steam Achievement Notifier appears to be running (PID $($running[0].Id)). Quit it from the system tray (right-click the icon, then Quit), then run this installer again."
            }
        } else {
            Write-Host '==> SAN_SKIP_PROCESS_CHECK=1 set - skipping the running-process check'
        }

        # -------------------------------------------------------------------
        # 4. Back up config.json, install the themes and update config.json
        # -------------------------------------------------------------------
        $configPath = Join-Path $dataDir 'config.json'
        $raw = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
        $cfg = ConvertFrom-Json -InputObject $raw
        $cfgCust = Get-Prop $cfg 'customisation'
        if ($null -eq $cfgCust) { throw '"customisation" missing from config.json' }
        foreach ($t in $ThemeFiles) {
            if ($null -eq (Get-Prop $cfgCust $t.Type)) { throw "`"customisation.$($t.Type)`" missing from config.json" }
        }

        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = Join-Path $dataDir "config.json.bak-$stamp"
        $n = 1
        while (Test-Path -LiteralPath $backup) {
            $backup = Join-Path $dataDir "config.json.bak-$stamp-$n"
            $n++
        }
        Copy-Item -LiteralPath $configPath -Destination $backup
        Write-Host "Backed up config.json to: $backup"

        $summary = New-Object System.Collections.ArrayList

        foreach ($t in $ThemeFiles) {
            $type = $t.Type
            $sanPath = Join-Path $themesDir $t.Name
            $stem = [System.IO.Path]::GetFileNameWithoutExtension($t.Name)
            $dirName = "${stem}_$type"
            $userThemesDir = Join-Path $dataDir 'userthemes'
            $udir = Join-Path $userThemesDir $dirName
            $assetsDir = Join-Path $udir 'assets'
            $assetsFwd = $assetsDir.Replace('\', '/')
            $warnings = New-Object System.Collections.ArrayList

            Expand-SanArchive -SanPath $sanPath -Dest $udir

            $jsonPath = Join-Path $udir 'usertheme.json'
            if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf)) { throw "`"usertheme.json`" missing from `"$($t.Name)`"" }
            $imported = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($jsonPath, [System.Text.Encoding]::UTF8))
            $importedCust = Get-Prop $imported 'customisation'
            $label = [string](Get-Prop $imported 'label')
            if ($null -eq $importedCust -or -not $label) { throw "`"$($t.Name)`" has no valid `"customisation`" or `"label`"" }

            $current = Get-Prop $cfgCust $type

            # Rewrite asset paths into the extracted folder (SAN import), dropping "usertheme"
            $newCust = [pscustomobject]@{}
            foreach ($p in $importedCust.PSObject.Properties) {
                if ($p.Name -ceq 'usertheme') { continue }
                $val = $p.Value
                if ($CustomFileKeys -ccontains $p.Name) { $val = Convert-Leaves $val $assetsFwd $p.Name }
                Add-Member -InputObject $newCust -NotePropertyName $p.Name -NotePropertyValue $val
            }

            # Blank customicons presets: SAN fills them with its defaults. Those live in the
            # SAN install folder, so reuse the value the current config has for that preset.
            $icons = Get-Prop $newCust 'customicons'
            if ($icons -is [pscustomobject]) {
                $curIcons = Get-Prop $current 'customicons'
                foreach ($p in @($icons.PSObject.Properties)) {
                    if ($p.Value -is [string] -and $p.Value -eq '') {
                        $cv = Get-Prop $curIcons $p.Name
                        if ($null -ne $cv -and -not ($cv -is [string] -and $cv -eq '')) {
                            $icons.PSObject.Properties[$p.Name].Value = (Copy-Obj $cv)
                        } else {
                            [void]$warnings.Add("customicons.$($p.Name) is blank and has no current default")
                        }
                    }
                }
            }

            $iconName = Get-Basename ([string](Get-Prop $imported 'icon'))
            $newIcon = "$assetsFwd/$iconName"
            Set-Prop $imported 'icon' $newIcon
            Set-Prop $imported 'userthemedir' $dirName
            Set-Prop $imported 'customisation' $newCust
            Write-Utf8NoBom -Path $jsonPath -Text (ConvertTo-Json -InputObject $imported -Depth 100)

            # Referenced files that are missing from the extracted folder
            $refs = New-Object System.Collections.ArrayList
            Get-AssetRefs $newCust "$assetsFwd/" $refs
            [void]$refs.Add($newIcon)
            foreach ($r in @($refs | Sort-Object -Unique)) {
                if (-not (Test-Path -LiteralPath $r -PathType Leaf)) {
                    [void]$warnings.Add("missing asset: $r")
                }
            }

            # Theme entry, built the way usertheme.create() does (settings-level keys removed)
            $entryCust = [pscustomobject]@{}
            foreach ($p in $newCust.PSObject.Properties) {
                if ($SettingsKeys -cnotcontains $p.Name) {
                    Add-Member -InputObject $entryCust -NotePropertyName $p.Name -NotePropertyValue $p.Value
                }
            }

            $userList = Get-Prop $current 'usertheme'
            if ($null -eq $userList) { $userList = @() }
            $userList = @($userList)

            $match = -1
            $newId = 0
            $ids = New-Object System.Collections.ArrayList
            for ($i = 0; $i -lt $userList.Count; $i++) {
                $u = $userList[$i]
                if ($u -is [pscustomobject] -and ($u.id -is [int] -or $u.id -is [long] -or $u.id -is [double])) { [void]$ids.Add([int]$u.id) }
                if ($match -lt 0 -and $u -is [pscustomobject] -and ([string]$u.label) -ceq $label) { $match = $i }
            }
            $keepEnabled = $false
            if ($match -ge 0) {
                $newId = [int]$userList[$match].id
                $keepEnabled = ($userList[$match].enabled -eq $true)
            } elseif ($ids.Count -gt 0) {
                $newId = [int](($ids | Measure-Object -Maximum).Maximum) + 1
            }

            $entryEnabled = if ($activate) { $true } else { $keepEnabled }
            $entry = New-Object PSObject
            Add-Member -InputObject $entry -NotePropertyName 'id' -NotePropertyValue $newId
            Add-Member -InputObject $entry -NotePropertyName 'label' -NotePropertyValue $label
            Add-Member -InputObject $entry -NotePropertyName 'icon' -NotePropertyValue $newIcon
            Add-Member -InputObject $entry -NotePropertyName 'customisation' -NotePropertyValue $entryCust
            Add-Member -InputObject $entry -NotePropertyName 'enabled' -NotePropertyValue $entryEnabled
            Add-Member -InputObject $entry -NotePropertyName 'userthemedir' -NotePropertyValue $dirName
            if ((Get-Prop $cfg 'usecustomfiles') -eq $true) {
                Add-Member -InputObject $entry -NotePropertyName 'usecustomfiles' -NotePropertyValue $true
            }

            $newList = New-Object System.Collections.ArrayList
            foreach ($u in $userList) {
                if ($activate -and $u -is [pscustomobject]) { Set-Prop $u 'enabled' $false }
                [void]$newList.Add($u)
            }
            if ($match -ge 0) { $newList[$match] = $entry } else { [void]$newList.Add($entry) }
            $newListArr = $newList.ToArray()

            if ($activate -or $entryEnabled) {
                # Same as usertheme.set(): theme customisation + current settings-level keys + usertheme list
                $active = Copy-Obj $entryCust
                foreach ($k in $SettingsKeys) {
                    if (Has-Prop $current $k) { Set-Prop $active $k (Get-Prop $current $k) }
                }
                foreach ($u in $newListArr) {
                    if ($u -is [pscustomobject] -and (Has-Prop (Get-Prop $u 'customisation') 'usertheme')) {
                        (Get-Prop $u 'customisation').PSObject.Properties.Remove('usertheme')
                    }
                }
                Set-Prop $active 'usertheme' $newListArr
                Set-Prop $cfgCust $type $active
            } else {
                Set-Prop $current 'usertheme' $newListArr
            }

            if ($activate) { Set-Prop $cfg 'trophymode' $true }

            foreach ($w in $warnings) { Write-Host "  WARN ($type): $w" }
            [void]$summary.Add([pscustomobject]@{ Type = $type; Label = $label; Id = $newId; Enabled = $entryEnabled; Dir = $dirName })
        }

        # Write config.json atomically (temp file + replace), UTF-8 without BOM
        $json = ConvertTo-Json -InputObject $cfg -Depth 100
        $tmpConfig = "$configPath.tmp-$PID"
        Write-Utf8NoBom -Path $tmpConfig -Text $json
        Move-Item -LiteralPath $tmpConfig -Destination $configPath -Force

        # Verify what was written
        $null = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8))

        foreach ($s in $summary) {
            $state = if ($s.Enabled) { 'active' } else { 'added (not active)' }
            Write-Host ("  {0,-5} {1,-16} id={2,-3} {3}  [userthemes\{4}]" -f $s.Type, $s.Label, $s.Id, $state, $s.Dir)
        }
        if ($activate) {
            Write-Host '  trophymode set to true'
        } else {
            Write-Host '  active themes and trophymode left unchanged (-NoActivate)'
        }
        Write-Host 'Restore the previous config with:'
        Write-Host "  Copy-Item -LiteralPath '$backup' -Destination '$configPath' -Force"
        Write-Host ''
        Write-Host '==> Done. Start Steam Achievement Notifier to use the PS5 trophy themes.'
    } finally {
        if ($tmpDir -and (Test-Path -LiteralPath $tmpDir)) {
            Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Main
