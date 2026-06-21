# ============================================================
#  connect.ps1  —  Interactive SSH session with fallback logic
# ============================================================

# --- Connection details --------------------------------------
$Username   = "student"
$Server     = "4.247.209.128"
$KeyPath    = "ubuntu_key.pem"       # Must be in same folder as this script
$SSHTimeout = 10                     # Seconds before connection is considered timed out
$MaxRetries = 3                      # How many times to retry on transient failure
# -------------------------------------------------------------

function Write-Status($msg, $color = "Cyan") {
    Write-Host "`n[*] $msg" -ForegroundColor $color
}

function Write-Fail($msg) {
    Write-Host "`n[!] $msg" -ForegroundColor Red
}

function Write-Ok($msg) {
    Write-Host "`n[+] $msg" -ForegroundColor Green
}

# ── 1. Check: is ssh.exe available? ─────────────────────────
Write-Status "Checking for SSH client..."
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Fail "ssh.exe not found. Enable it via:"
    Write-Host "  Settings > Apps > Optional Features > OpenSSH Client" -ForegroundColor Yellow
    exit 1
}
Write-Ok "SSH client found."


# ── 2. Check: does the key file exist? ──────────────────────
Write-Status "Locating key file..."

# Resolve key path relative to the script's own folder
$ScriptDir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$ResolvedKeyPath = Join-Path $ScriptDir $KeyPath

if (-not (Test-Path $ResolvedKeyPath)) {
    Write-Fail "Key file not found: $ResolvedKeyPath"
    Write-Host "  Make sure '$KeyPath' is in the same folder as this script." -ForegroundColor Yellow
    exit 1
}
Write-Ok "Key file found: $ResolvedKeyPath"


# ── 3. Check: key permissions (warn only — Windows is lenient) ──
Write-Status "Checking key file permissions..."
$acl        = Get-Acl $ResolvedKeyPath
$identities = $acl.Access | Select-Object -ExpandProperty IdentityReference
$others     = $identities | Where-Object { $_ -notmatch [regex]::Escape($env:USERNAME) -and $_ -notmatch "SYSTEM" }
if ($others) {
    Write-Host "[~] Warning: key may be readable by other accounts. SSH might reject it." -ForegroundColor Yellow
    Write-Host "    Identities with access: $($others -join ', ')" -ForegroundColor DarkYellow
    Write-Host "    To fix: right-click key > Properties > Security > remove extra entries." -ForegroundColor DarkYellow
} else {
    Write-Ok "Key permissions look fine."
}


# ── 4. Check: can we reach the server at all? ───────────────
Write-Status "Pinging $Server (1 packet)..."
$ping = Test-Connection -ComputerName $Server -Count 1 -Quiet -ErrorAction SilentlyContinue
if (-not $ping) {
    Write-Host "[~] Ping failed — server may block ICMP. Proceeding anyway..." -ForegroundColor Yellow
} else {
    Write-Ok "Server is reachable."
}


# ── 5. Retry loop — attempt the SSH connection ──────────────
$attempt = 0
$connected = $false

while ($attempt -lt $MaxRetries -and -not $connected) {
    $attempt++
    Write-Status "Connection attempt $attempt of $MaxRetries..."

    # Build SSH args — ConnectTimeout is honoured by OpenSSH
    $sshArgs = @(
        "-i", $ResolvedKeyPath,
        "-o", "ConnectTimeout=$SSHTimeout",
        "-o", "BatchMode=no",          # allow interactive prompts (host key etc.)
        "-o", "StrictHostKeyChecking=accept-new",  # auto-accept new host keys; reject changed ones
        "$Username@$Server"
    )

    try {
        # Start SSH and wait for it to finish
        $proc = Start-Process -FilePath "ssh" `
                              -ArgumentList $sshArgs `
                              -NoNewWindow `
                              -PassThru `
                              -Wait

        $exit = $proc.ExitCode

        switch ($exit) {
            0 {
                # Clean exit — user typed 'exit' or connection closed normally
                Write-Ok "Session ended cleanly."
                $connected = $true
            }
            255 {
                # OpenSSH returns 255 for connection-level errors (timeout, refused, bad key…)
                Write-Fail "SSH could not establish a connection (exit 255)."
                Diagnose-Failure
                if ($attempt -lt $MaxRetries) {
                    Write-Host "  Retrying in 3 seconds..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 3
                }
            }
            default {
                # Non-zero exit from the remote shell or other SSH error
                Write-Fail "SSH exited with code $exit."
                if ($attempt -lt $MaxRetries) {
                    Write-Host "  Retrying in 3 seconds..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 3
                }
            }
        }
    }
    catch {
        Write-Fail "Unexpected error launching SSH: $_"
        break
    }
}


# ── 6. Final verdict ────────────────────────────────────────
if (-not $connected) {
    Write-Fail "All $MaxRetries attempts failed. Could not connect to $Server."
    Write-Host @"

Troubleshooting checklist:
  1. VPN / firewall  — is port 22 open to $Server ?
  2. Key mismatch    — is '$KeyPath' the right key for user '$Username'?
  3. Wrong user      — try 'ubuntu', 'ec2-user', or 'azureuser' instead of '$Username'.
  4. Server down     — confirm the VM is running in your cloud console.
  5. Timeout too low — increase `$SSHTimeout` at the top of this script.
"@ -ForegroundColor Yellow
    exit 1
}


# ── Helper: extra diagnostics printed on exit 255 ───────────
function Diagnose-Failure {
    Write-Host "`n  Possible causes:" -ForegroundColor DarkYellow
    Write-Host "    • Connection timed out  — server unreachable or port 22 blocked." -ForegroundColor DarkYellow
    Write-Host "    • Connection refused     — SSH daemon not running on $Server." -ForegroundColor DarkYellow
    Write-Host "    • Permission denied      — wrong key or wrong username." -ForegroundColor DarkYellow
    Write-Host "    • Host key changed       — run: ssh-keygen -R $Server  to clear it." -ForegroundColor DarkYellow
}
