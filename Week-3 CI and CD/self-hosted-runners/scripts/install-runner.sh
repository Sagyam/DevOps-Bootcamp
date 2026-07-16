#!/usr/bin/env bash
# ===========================================================================
# Sagyam's DevOps Bootcamp — self-hosted runner installer (macOS & Ubuntu)
#
#   1. Asks your name  -> becomes your runner's name AND its label
#   2. Asks the token  -> the instructor gives this out in class
#   3. Downloads the right runner for your OS/arch, configures, and starts it
#
# Run it from an empty folder you don't mind creating files in:
#   bash install-runner.sh
# ===========================================================================
set -euo pipefail

REPO_URL="https://github.com/Sagyam/github-actions"
FALLBACK_VERSION="2.335.1"   # used only if we can't resolve the latest

echo "=== Sagyam's DevOps Bootcamp — self-hosted runner setup ==="
echo

# --- 1. name (this becomes the runner name + a targetable label) -----------
read -rp "Your name (becomes your runner's name): " NAME
# keep only letters/numbers/space/underscore/dash, then spaces -> dashes
NAME="$(printf '%s' "$NAME" | tr -cd '[:alnum:] _-' | tr ' ' '-')"
[ -n "$NAME" ] || { echo "Name can't be empty. Re-run and enter a name."; exit 1; }

# --- 2. registration token (shared by the instructor in class) -------------
read -rp "Registration token (from the instructor): " TOKEN
[ -n "$TOKEN" ] || { echo "Token can't be empty. Ask the instructor for it."; exit 1; }

# --- 3. detect platform ----------------------------------------------------
OS_RAW="$(uname -s)"; ARCH_RAW="$(uname -m)"
case "$OS_RAW" in
  Darwin) PLAT="osx" ;;
  Linux)  PLAT="linux" ;;
  *) echo "Unsupported OS: $OS_RAW (this script is for macOS/Ubuntu)"; exit 1 ;;
esac
case "$ARCH_RAW" in
  x86_64|amd64)  ARCH="x64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "Unsupported CPU: $ARCH_RAW"; exit 1 ;;
esac
echo "Detected: $PLAT / $ARCH  ·  runner name: $NAME"

# --- 4. Ubuntu: notification dependency (no TTS) ---------------------------
if [ "$PLAT" = "linux" ] && ! command -v notify-send >/dev/null 2>&1; then
  echo "Installing libnotify-bin (for desktop notifications)..."
  sudo apt-get update -y && sudo apt-get install -y libnotify-bin \
    || echo "  (couldn't auto-install — notifications may not pop, but jobs still run)"
fi

# --- 5. resolve the latest runner version ----------------------------------
echo "Finding the latest runner version..."
VERSION="$(curl -sIL https://github.com/actions/runner/releases/latest \
  | tr -d '\r' | awk -F'/tag/v' '/^[Ll]ocation:/{print $2}' | tail -n1)"
[ -n "${VERSION:-}" ] || VERSION="$FALLBACK_VERSION"
echo "  -> v$VERSION"

# --- 6. download + extract -------------------------------------------------
mkdir -p actions-runner && cd actions-runner
PKG="actions-runner-${PLAT}-${ARCH}-${VERSION}.tar.gz"
if [ ! -f "$PKG" ]; then
  echo "Downloading $PKG..."
  curl -fL -o "$PKG" "https://github.com/actions/runner/releases/download/v${VERSION}/${PKG}"
fi
tar xzf "$PKG"

# --- 7. configure (name == label so the instructor can target just you) ----
./config.sh --url "$REPO_URL" --token "$TOKEN" \
  --name "$NAME" --labels "$NAME" --unattended --replace

# --- 8. run INTERACTIVELY (required so notifications & sounds work) ---------
echo
echo "All set, $NAME! Starting your runner — KEEP THIS WINDOW OPEN."
echo "You'll see 'Listening for Jobs'. That means you're live."
echo "Press Ctrl+C when class is over to stop it."
echo
./run.sh
