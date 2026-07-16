# ===========================================================================
# Sagyam's DevOps Bootcamp — self-hosted runner installer (Windows)
#
#   1. Asks your name  -> becomes your runner's name AND its label
#   2. Asks the token  -> the instructor gives this out in class
#   3. Downloads the right runner, configures, and starts it
#
# Run it from an empty folder, in PowerShell:
#   powershell -ExecutionPolicy Bypass -File install-runner.ps1
# ===========================================================================
$ErrorActionPreference = "Stop"

$RepoUrl  = "https://github.com/Sagyam/github-actions"
$Fallback = "2.335.1"   # used only if we can't resolve the latest

Write-Host "=== Sagyam's DevOps Bootcamp — self-hosted runner setup ==="
Write-Host ""

# --- 1. name (runner name + targetable label) ------------------------------
$Name = Read-Host "Your name (becomes your runner's name)"
$Name = (($Name -replace '[^A-Za-z0-9 _-]', '') -replace ' ', '-')
if (-not $Name) { Write-Error "Name can't be empty. Re-run and enter a name."; exit 1 }

# --- 2. registration token (shared by the instructor) ----------------------
$Token = Read-Host "Registration token (from the instructor)"
if (-not $Token) { Write-Error "Token can't be empty. Ask the instructor for it."; exit 1 }

# --- 3. detect arch --------------------------------------------------------
$Arch = if ($env:PROCESSOR_ARCHITECTURE -match "ARM") { "arm64" } else { "x64" }
Write-Host "Detected: win / $Arch  ·  runner name: $Name"

# --- 4. resolve the latest runner version ----------------------------------
Write-Host "Finding the latest runner version..."
$Version = $Fallback
try {
  $resp = Invoke-WebRequest -UseBasicParsing -Method Head `
            -Uri "https://github.com/actions/runner/releases/latest" `
            -MaximumRedirection 0 -ErrorAction Stop
} catch {
  $resp = $_.Exception.Response
}
if ($resp) {
  $loc = $null
  if ($resp.Headers -and $resp.Headers.Location) { $loc = $resp.Headers.Location.ToString() }
  elseif ($resp.Headers["Location"])             { $loc = $resp.Headers["Location"] }
  if ($loc -and $loc -match "/tag/v([\d.]+)")     { $Version = $Matches[1] }
}
Write-Host "  -> v$Version"

# --- 5. download + extract -------------------------------------------------
New-Item -ItemType Directory -Force -Path "actions-runner" | Out-Null
Set-Location "actions-runner"
$Pkg = "actions-runner-win-$Arch-$Version.zip"
if (-not (Test-Path $Pkg)) {
  Write-Host "Downloading $Pkg..."
  Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$Version/$Pkg" -OutFile $Pkg
}
Expand-Archive -Path $Pkg -DestinationPath . -Force

# --- 6. configure (name == label so the instructor can target just you) ----
./config.cmd --url $RepoUrl --token $Token `
  --name $Name --labels $Name --unattended --replace

# --- 7. run INTERACTIVELY (required so notifications work) ------------------
Write-Host ""
Write-Host "All set, $Name! Starting your runner — KEEP THIS WINDOW OPEN."
Write-Host "You'll see 'Listening for Jobs'. That means you're live."
Write-Host "Press Ctrl+C when class is over to stop it."
Write-Host ""
./run.cmd
