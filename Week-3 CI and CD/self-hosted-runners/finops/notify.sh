#!/usr/bin/env bash
# Desktop notification helper — NO text-to-speech.
# Usage: bash finops/notify.sh "Title" "Message"
# Never fails the step (always exits 0).
title="${1:-GitHub Actions}"
msg="${2:-}"
# strip double-quotes so they can't break osascript
title="${title//\"/}"
msg="${msg//\"/}"

if [ "$(uname -s)" = "Darwin" ]; then
  osascript -e "display notification \"$msg\" with title \"$title\"" >/dev/null 2>&1 || true
  # a soft, reliable system sound (this is NOT tts)
  afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &
else
  notify-send "$title" "$msg" >/dev/null 2>&1 || true
  paplay /usr/share/sounds/freedesktop/stereo/message.oga >/dev/null 2>&1 &
fi
exit 0
