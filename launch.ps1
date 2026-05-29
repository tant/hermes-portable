# ============================================================================
# Hermes Agent - Portable Launcher (Windows, PowerShell)
# ============================================================================
# Invoked by launch.bat (double-click) or directly: pwsh -File launch.ps1
# On first run, downloads ~600MB of runtime files. All data stays in data\.
# ============================================================================
$ErrorActionPreference = "Stop"

$PortableRoot = $PSScriptRoot
$HermesHome   = Join-Path $PortableRoot "data"
$CacheDir     = Join-Path $PortableRoot ".cache"
$RuntimeDir   = Join-Path $CacheDir "runtimes\windows-x64"
$SrcDir       = Join-Path $PortableRoot "src"
$AgentDir     = Join-Path $SrcDir "hermes-agent"

# ---- First-run setup ----
if (-not (Test-Path (Join-Path $RuntimeDir "ready.flag"))) {
    Write-Host ""
    Write-Host "============================================"
    Write-Host "    Hermes Portable - First Run Setup"
    Write-Host "============================================"
    Write-Host "  This will download ~600MB for Windows x64."
    Write-Host "============================================"
    Write-Host ""
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PortableRoot "scripts\setup-windows.ps1") -Root $PortableRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Setup failed. Check your internet connection and try again."
        Read-Host "Press Enter to exit"; exit 1
    }
}

# ---- Environment isolation ----
$VenvDir = Join-Path $RuntimeDir "venv"
$env:HERMES_HOME            = $HermesHome
$env:VIRTUAL_ENV           = $VenvDir
$env:PATH                  = (Join-Path $VenvDir "Scripts") + ";" + (Join-Path $RuntimeDir "python") + ";" + (Join-Path $RuntimeDir "python\Scripts") + ";" + (Join-Path $RuntimeDir "node") + ";" + (Join-Path $RuntimeDir "uv") + ";" + (Join-Path $RuntimeDir "bin") + ";" + $env:PATH
$env:PYTHONNOUSERSITE      = "1"
$env:PYTHONHOME            = ""
$env:PYTHONPATH            = ""
$env:UV_NO_CONFIG          = "1"
$env:UV_PYTHON             = Join-Path $RuntimeDir "python\python.exe"
$env:PLAYWRIGHT_BROWSERS_PATH = Join-Path $RuntimeDir "playwright"
$env:NODE_PATH             = Join-Path $RuntimeDir "node\node_modules"
$env:NPM_CONFIG_PREFIX     = Join-Path $RuntimeDir "node"
$env:APPDATA               = Join-Path $CacheDir "windows-appdata"
$env:LOCALAPPDATA          = Join-Path $CacheDir "windows-localappdata"
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

# ---- Active profile (launcher-managed) ----
# Per-profile alias wrappers live under the isolated home; put them on PATH.
$env:PATH = (Join-Path $env:APPDATA "..\.local\bin") + ";" + $env:PATH

$ActiveProfileFile = Join-Path $HermesHome ".active-profile"
$ActiveProfile = "default"
if (Test-Path $ActiveProfileFile) {
    $ActiveProfile = (Get-Content $ActiveProfileFile -Raw).Trim()
    if (-not $ActiveProfile) { $ActiveProfile = "default" }
}
if ($ActiveProfile -ne "default" -and -not (Test-Path (Join-Path $HermesHome "profiles\$ActiveProfile"))) {
    $ActiveProfile = "default"
}
if ($ActiveProfile -eq "default") { $ProfileDir = $HermesHome }
else { $ProfileDir = Join-Path $HermesHome "profiles\$ActiveProfile" }

# Route Hermes calls to the active profile (no -p for default).
function Invoke-Hermes {
    if ($ActiveProfile -eq "default") { & hermes @args }
    else { & hermes -p $ActiveProfile @args }
}

function Set-ActiveProfile($name) {
    Set-Content -Path $ActiveProfileFile -Value $name -NoNewline
    $script:ActiveProfile = $name
    if ($name -eq "default") { $script:ProfileDir = $HermesHome }
    else { $script:ProfileDir = Join-Path $HermesHome "profiles\$name" }
    & hermes profile use $name 2>$null | Out-Null
}

# ---- Auto-check & update source (never blocks; offline-safe) ----
function Get-RemoteSha {
    param([string]$Repo = "NousResearch/hermes-agent", [string]$Branch = "main")
    try {
        $sha = (Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/commits/$Branch" `
            -Headers @{ "Accept" = "application/vnd.github.sha"; "User-Agent" = "hermes-portable" } `
            -TimeoutSec 8)
        if ($sha -match '^[0-9a-f]{40}$') { return "$sha" }
    } catch { }
    return $null
}

function Check-AndUpdateSource {
    if (-not (Test-Path $AgentDir)) { return }
    $shaFile = Join-Path $AgentDir ".source-sha"
    $remote = Get-RemoteSha
    if (-not $remote) { Write-Host "[WARN]  Could not check for updates (offline?) - using existing source."; return }
    $localSha = ""
    if (Test-Path $shaFile) { $localSha = (Get-Content $shaFile -Raw).Trim() }
    if (-not $localSha) { Set-Content -Path $shaFile -Value $remote -NoNewline; return }
    if ($remote -eq $localSha) { return }

    Write-Host "[INFO]  New Hermes version available - updating ($localSha -> $remote) ..."
    $tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("hermes-upd-" + [guid]::NewGuid().ToString("N")))
    $archive = Join-Path $tmp "source.tar.gz"
    try {
        & curl.exe -fL --retry 3 --connect-timeout 30 --max-time 600 "https://github.com/NousResearch/hermes-agent/archive/$remote.tar.gz" -o $archive
        if ($LASTEXITCODE -ne 0) { throw "download failed" }
        $extract = Join-Path $tmp "extracted"
        New-Item -ItemType Directory -Force -Path $extract | Out-Null
        & tar.exe -xzf $archive -C $extract --strip-components=1
        if ($LASTEXITCODE -ne 0) { throw "extract failed" }
        Remove-Item -Recurse -Force $AgentDir
        Move-Item $extract $AgentDir
        Set-Content -Path (Join-Path $AgentDir ".source-sha") -Value $remote -NoNewline
        Write-Host "[INFO]  Reinstalling dependencies for the update ..."
        # The venv is created without pip, so use uv (which the runtime ships);
        # the editable reinstall also re-points the venv at this drive's source.
        $uvExe = Join-Path $RuntimeDir "uv\uv.exe"
        $venvPy = Join-Path $VenvDir "Scripts\python.exe"
        & $uvExe pip install --python $venvPy --link-mode=copy -e "$AgentDir[all]" "python-telegram-bot[webhooks]==22.6" 2>$null
        if ($LASTEXITCODE -ne 0) { & $venvPy -m pip install --quiet -e "$AgentDir[all]" "python-telegram-bot[webhooks]==22.6" 2>$null }
        if ($LASTEXITCODE -eq 0) { Write-Host "[OK]    Updated to $remote." }
        else { Write-Host "[WARN]  Update installed but dependency refresh failed - use Advanced > Update if Hermes misbehaves." }
    } catch {
        Write-Host "[WARN]  Update failed ($_) - keeping current source."
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}
Check-AndUpdateSource

# ---- Launch ----
if (-not (Test-Path $AgentDir)) {
    Write-Host "[ERROR] Hermes source not found. Delete .cache and try again."
    Read-Host "Press Enter to exit"; exit 1
}
Set-Location $AgentDir

# Strip a leading "hermes" token, then pass through explicit args.
$cliArgs = $args
if ($cliArgs.Count -gt 0 -and $cliArgs[0] -ieq "hermes") {
    if ($cliArgs.Count -gt 1) { $cliArgs = $cliArgs[1..($cliArgs.Count-1)] } else { $cliArgs = @() }
}
if ($cliArgs.Count -gt 0) { Invoke-Hermes @cliArgs; exit }

function Get-Status {
    $script:SetupStatus = "Not configured"
    $envFile = Join-Path $ProfileDir ".env"
    if ((Test-Path $envFile) -and (Select-String -Path $envFile -Pattern '^[A-Z].*=' -Quiet)) {
        $script:SetupStatus = "Configured"
    }
    $script:GatewayStatus = "Stopped"
    $pidFile = Join-Path $ProfileDir "gateway.pid"
    if (Test-Path $pidFile) {
        $m = Select-String -Path $pidFile -Pattern '"pid":(\d+)'
        if ($m) {
            $gpid = $m.Matches[0].Groups[1].Value
            if (Get-Process -Id $gpid -ErrorAction SilentlyContinue) { $script:GatewayStatus = "Running (PID $gpid)" }
            else { $script:GatewayStatus = "Stopped (stale lock)" }
        }
    }
}

function Show-Menu {
    while ($true) {
        Get-Status
        Clear-Host
        Write-Host ""
        Write-Host "----------------------------------------------------------------"
        Write-Host "                    HERMES PORTABLE LAUNCHER"
        Write-Host "----------------------------------------------------------------"
        Write-Host (" Setup    " + $script:SetupStatus)
        Write-Host (" Profile  " + $ActiveProfile)
        Write-Host (" Gateway  " + $script:GatewayStatus)
        Write-Host "----------------------------------------------------------------"
        Write-Host "  [1]  Start Hermes Chat"
        Write-Host "  [2]  Setup / Reconfigure Hermes"
        if ($script:GatewayStatus -like "Running*") { Write-Host "  [3]  Stop Gateway  [live]" }
        else { Write-Host "  [3]  Start Gateway" }
        Write-Host "  [4]  Profiles  ->"
        Write-Host "  [5]  Advanced Options  ->"
        Write-Host "  [6]  Exit"
        Write-Host "----------------------------------------------------------------"
        $choice = Read-Host "Select option"
        switch ($choice) {
            "1" { Clear-Host; Invoke-Hermes }
            "2" { Clear-Host; Invoke-Hermes setup }
            "3" {
                if ($script:GatewayStatus -like "Running*") { Invoke-Hermes gateway stop }
                else {
                    if ($ActiveProfile -eq "default") { Start-Process -NoNewWindow hermes -ArgumentList "gateway" }
                    else { Start-Process -NoNewWindow hermes -ArgumentList "-p","$ActiveProfile","gateway" }
                    Start-Sleep 2
                }
                Read-Host "Press Enter to continue"
            }
            "4" { Show-Profiles }
            "5" { Show-Advanced }
            "6" { Clear-Host; Write-Host "Goodbye!"; exit }
            default { }
        }
    }
}

function Show-Advanced {
    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "----------------------------------------------------------------"
        Write-Host "                       Advanced Options"
        Write-Host "----------------------------------------------------------------"
        Write-Host "  [1]  Run Doctor"
        Write-Host "  [2]  View Logs"
        Write-Host "  [3]  Edit Config"
        Write-Host "  [4]  Restart Gateway"
        Write-Host "  [5]  Update Hermes"
        Write-Host "  [6]  Back to Main Menu"
        Write-Host "----------------------------------------------------------------"
        $choice = Read-Host "Select option"
        switch ($choice) {
            "1" { Clear-Host; Invoke-Hermes doctor; Read-Host "Press Enter to continue" }
            "2" {
                Clear-Host
                $log = Join-Path $ProfileDir "logs\gateway.log"
                if (Test-Path $log) { Write-Host "=== Gateway Log (last 20 lines) ==="; Get-Content $log -Tail 20 }
                else { Write-Host "No logs found." }
                Read-Host "Press Enter to continue"
            }
            "3" { Clear-Host; Invoke-Hermes config edit }
            "4" { Invoke-Hermes gateway restart; Read-Host "Press Enter to continue" }
            "5" { Clear-Host; Invoke-Hermes update; Read-Host "Press Enter to continue" }
            "6" { return }
            default { }
        }
    }
}

function Show-Profiles {
    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "----------------------------------------------------------------"
        Write-Host "                          Profiles"
        Write-Host "----------------------------------------------------------------"
        Write-Host (" Active  " + $ActiveProfile)
        Write-Host ""
        & hermes profile list
        Write-Host "----------------------------------------------------------------"
        Write-Host "  [1]  Switch profile"
        Write-Host "  [2]  Create profile"
        Write-Host "  [3]  Rename profile"
        Write-Host "  [4]  Delete profile"
        Write-Host "  [5]  Export profile"
        Write-Host "  [6]  Import profile"
        Write-Host "  [7]  Back to Main Menu"
        Write-Host "----------------------------------------------------------------"
        $choice = Read-Host "Select option"
        switch ($choice) {
            "1" {
                & hermes profile list
                $name = Read-Host "Profile name to switch to (blank = cancel)"
                if ($name) {
                    & hermes profile use $name
                    if ($LASTEXITCODE -eq 0) { Set-ActiveProfile $name; Write-Host "Active profile: $name" }
                    else { Write-Host "Could not switch to '$name'." }
                    Read-Host "Press Enter to continue"
                }
            }
            "2" {
                $name = Read-Host "New profile name (lowercase, alphanumeric, blank = cancel)"
                if ($name) {
                    & hermes profile create $name
                    $yn = Read-Host "Switch to '$name' now? [y/N]"
                    if ($yn -match '^[yY]') { & hermes profile use $name 2>$null | Out-Null; Set-ActiveProfile $name }
                    Read-Host "Press Enter to continue"
                }
            }
            "3" {
                & hermes profile list
                $old = Read-Host "Rename which profile (blank = cancel)"
                if ($old) {
                    $new = Read-Host "New name"
                    if ($new) {
                        & hermes profile rename $old $new
                        if ($ActiveProfile -eq $old) { Set-ActiveProfile $new }
                        Read-Host "Press Enter to continue"
                    }
                }
            }
            "4" {
                & hermes profile list
                $name = Read-Host "Delete which profile (blank = cancel)"
                if ($name) {
                    & hermes profile delete $name
                    if ($ActiveProfile -eq $name) { Set-ActiveProfile "default"; Write-Host "Active profile was deleted - reset to default." }
                    Read-Host "Press Enter to continue"
                }
            }
            "5" {
                & hermes profile list
                $name = Read-Host "Export which profile (blank = cancel)"
                if ($name) {
                    $path = Read-Host "Output archive path (blank = <name>.tar.gz)"
                    if ($path) { & hermes profile export $name -o $path } else { & hermes profile export $name }
                    Read-Host "Press Enter to continue"
                }
            }
            "6" {
                $path = Read-Host "Path to profile archive (blank = cancel)"
                if ($path) { & hermes profile import $path; Read-Host "Press Enter to continue" }
            }
            "7" { return }
            default { }
        }
    }
}

Show-Menu
