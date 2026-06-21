#!/usr/bin/env bash
# ============================================================
#  connect.sh  —  Interactive SSH session with fallback logic
# ============================================================

# --- Connection details --------------------------------------
USERNAME="student"
SERVER="4.247.209.128"
KEY_PATH="ubuntu_key.pem"   # Must be in same folder as this script
SSH_TIMEOUT=10               # Seconds before connection is considered timed out
MAX_RETRIES=3                # How many times to retry on transient failure
# -------------------------------------------------------------

# ── Colour helpers ───────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DARK_YELLOW='\033[0;33m'
RESET='\033[0m'

write_status() { echo -e "\n${CYAN}[*] $1${RESET}"; }
write_ok()     { echo -e "\n${GREEN}[+] $1${RESET}"; }
write_fail()   { echo -e "\n${RED}[!] $1${RESET}"; }
write_warn()   { echo -e "${DARK_YELLOW}    $1${RESET}"; }


# ── Helper: extra diagnostics printed on exit 255 ────────────
diagnose_failure() {
    echo -e "\n  ${YELLOW}Possible causes:${RESET}"
    write_warn "• Connection timed out  — server unreachable or port 22 blocked."
    write_warn "• Connection refused    — SSH daemon not running on $SERVER."
    write_warn "• Permission denied     — wrong key or wrong username."
    write_warn "• Host key changed      — run: ssh-keygen -R $SERVER  to clear it."
}


# ── 1. Check: is ssh available? ──────────────────────────────
write_status "Checking for SSH client..."
if ! command -v ssh &>/dev/null; then
    write_fail "ssh not found. Install it with:"
    echo -e "  ${YELLOW}Ubuntu/Debian : sudo apt install openssh-client${RESET}"
    echo -e "  ${YELLOW}macOS         : brew install openssh${RESET}"
    exit 1
fi
write_ok "SSH client found."


# ── 2. Check: does the key file exist? ───────────────────────
write_status "Locating key file..."

# Resolve key path relative to the script's own folder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVED_KEY="$SCRIPT_DIR/$KEY_PATH"

if [[ ! -f "$RESOLVED_KEY" ]]; then
    write_fail "Key file not found: $RESOLVED_KEY"
    echo -e "  ${YELLOW}Make sure '$KEY_PATH' is in the same folder as this script.${RESET}"
    exit 1
fi
write_ok "Key file found: $RESOLVED_KEY"


# ── 3. Check: key file permissions ───────────────────────────
write_status "Checking key file permissions..."
KEY_PERMS=$(stat -c "%a" "$RESOLVED_KEY" 2>/dev/null || stat -f "%OLp" "$RESOLVED_KEY" 2>/dev/null)

if [[ "$KEY_PERMS" != "600" && "$KEY_PERMS" != "400" ]]; then
    echo -e "${YELLOW}[~] Key permissions are $KEY_PERMS — SSH will reject anything looser than 600.${RESET}"
    echo -e "    ${YELLOW}Fixing automatically...${RESET}"
    chmod 600 "$RESOLVED_KEY"
    if [[ $? -eq 0 ]]; then
        write_ok "Permissions fixed (set to 600)."
    else
        write_fail "Could not fix permissions. Run manually: chmod 600 $RESOLVED_KEY"
        exit 1
    fi
else
    write_ok "Key permissions are correct ($KEY_PERMS)."
fi


# ── 4. Check: can we reach the server at all? ────────────────
write_status "Pinging $SERVER (1 packet)..."
if ! ping -c 1 -W 3 "$SERVER" &>/dev/null; then
    echo -e "${YELLOW}[~] Ping failed — server may block ICMP. Proceeding anyway...${RESET}"
else
    write_ok "Server is reachable."
fi


# ── 5. Retry loop — attempt the SSH connection ───────────────
attempt=0
connected=false

while [[ $attempt -lt $MAX_RETRIES && $connected == false ]]; do
    attempt=$((attempt + 1))
    write_status "Connection attempt $attempt of $MAX_RETRIES..."

    ssh \
        -i "$RESOLVED_KEY" \
        -o "ConnectTimeout=$SSH_TIMEOUT" \
        -o "BatchMode=no" \
        -o "StrictHostKeyChecking=accept-new" \
        "$USERNAME@$SERVER"

    EXIT_CODE=$?

    case $EXIT_CODE in
        0)
            # Clean exit — user typed 'exit' or connection closed normally
            write_ok "Session ended cleanly."
            connected=true
            ;;
        255)
            # OpenSSH returns 255 for connection-level errors (timeout, refused, bad key…)
            write_fail "SSH could not establish a connection (exit 255)."
            diagnose_failure
            if [[ $attempt -lt $MAX_RETRIES ]]; then
                echo -e "  ${YELLOW}Retrying in 3 seconds...${RESET}"
                sleep 3
            fi
            ;;
        *)
            # Non-zero exit from the remote shell or other SSH error
            write_fail "SSH exited with code $EXIT_CODE."
            if [[ $attempt -lt $MAX_RETRIES ]]; then
                echo -e "  ${YELLOW}Retrying in 3 seconds...${RESET}"
                sleep 3
            fi
            ;;
    esac
done


# ── 6. Final verdict ─────────────────────────────────────────
if [[ $connected == false ]]; then
    write_fail "All $MAX_RETRIES attempts failed. Could not connect to $SERVER."
    echo -e "${YELLOW}
Troubleshooting checklist:
  1. VPN / firewall  — is port 22 open to $SERVER ?
  2. Key mismatch    — is '$KEY_PATH' the right key for user '$USERNAME'?
  3. Wrong user      — try 'ubuntu', 'ec2-user', or 'azureuser' instead of '$USERNAME'.
  4. Server down     — confirm the VM is running in your cloud console.
  5. Timeout too low — increase SSH_TIMEOUT at the top of this script.
${RESET}"
    exit 1
fi
