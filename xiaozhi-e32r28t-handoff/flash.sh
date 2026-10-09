#!/usr/bin/env bash
# Flash the prebuilt xiaozhi firmware to the LCDWiki E32R28T on Perlinpinpin.
# Usage: ./flash.sh [port]   (default /dev/ttyUSB0)
set -euo pipefail
PORT="${1:-/dev/ttyUSB0}"
BIN="$(dirname "$0")/xiaozhi-v2.5.1-lcdwiki-e32r28t-en-jarvis-merged.bin"
EXPECTED_SHA="4b4402954141d1f69de82035cab8ffd25b38619a3990d301a971e44f8dae1976"

command -v esptool >/dev/null || pipx install esptool
[ -e "$PORT" ] || { echo "No $PORT. Check: lsusb | grep 1a86 ; journalctl -k | grep -i 'ch34\|brltty' | tail"; exit 1; }
echo "$EXPECTED_SHA  $BIN" | sha256sum -c -

esptool --chip esp32 -p "$PORT" -b 460800 erase-flash
esptool --chip esp32 -p "$PORT" -b 460800 write-flash 0x0 "$BIN"
echo "Flashed. Serial log:  pipx run --spec pyserial pyserial-miniterm --raw $PORT 115200   (Ctrl-] to quit)"
