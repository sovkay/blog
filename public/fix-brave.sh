#!/bin/sh
# fix-brave.sh — turn Brave into "just the browser" using enterprise policies.
# Reproduces the paid Brave Origin build for free, on macOS + Linux.
# What it does: writes a managed-policy file that disables Wallet, Rewards,
# Leo AI, VPN, News, Talk, Tor, and telemetry. Nothing is installed or removed;
# it only flips Brave's own switches. Undo any time with --undo.
# Guide: https://ksorv.com/blog/brave-origin-for-free
set -eu

BARE=0
UNDO=0
for arg in "$@"; do
  case "$arg" in
    --bare) BARE=1 ;;
    --undo) UNDO=1 ;;
    -h|--help)
      echo "Usage: sudo sh fix-brave.sh [--bare] [--undo]"
      echo "  --bare  also disable password manager, autofill, and translate"
      echo "  --undo  remove the policy and restore stock Brave"
      exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "This writes a system policy file and needs root." >&2
  echo "Re-run: sudo sh fix-brave.sh $*" >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin) OS=mac;   DEST="/Library/Managed Preferences/com.brave.Browser.plist" ;;
  Linux)  OS=linux; DEST="/etc/brave/policies/managed/fix-brave.json" ;;
  *) echo "Unsupported OS (macOS + Linux only)." >&2; exit 1 ;;
esac

if [ "$UNDO" -eq 1 ]; then
  rm -f "$DEST"
  echo "Removed $DEST"
  echo "Quit Brave (Cmd/Ctrl+Q) and reopen to restore stock Brave."
  exit 0
fi

mkdir -p "$(dirname "$DEST")"

if [ "$OS" = mac ]; then
  {
    cat <<'HEAD'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>BraveWalletDisabled</key><true/>
  <key>BraveRewardsDisabled</key><true/>
  <key>BraveAIChatEnabled</key><false/>
  <key>BraveVPNDisabled</key><true/>
  <key>BraveNewsDisabled</key><true/>
  <key>BraveTalkDisabled</key><true/>
  <key>TorDisabled</key><true/>
  <key>BravePlaylistEnabled</key><false/>
  <key>BraveSpeedreaderEnabled</key><false/>
  <key>BraveWaybackMachineEnabled</key><false/>
  <key>BraveWebDiscoveryEnabled</key><false/>
  <key>BraveP3AEnabled</key><false/>
  <key>BraveStatsPingEnabled</key><false/>
  <key>MetricsReportingEnabled</key><false/>
HEAD
    [ "$BARE" -eq 1 ] && cat <<'EXTRA'
  <key>PasswordManagerEnabled</key><false/>
  <key>AutofillAddressEnabled</key><false/>
  <key>AutofillCreditCardEnabled</key><false/>
  <key>TranslateEnabled</key><false/>
EXTRA
    cat <<'FOOT'
</dict>
</plist>
FOOT
  } > "$DEST"
else
  {
    cat <<'HEAD'
{
  "BraveWalletDisabled": true,
  "BraveRewardsDisabled": true,
  "BraveAIChatEnabled": false,
  "BraveVPNDisabled": true,
  "BraveNewsDisabled": true,
  "BraveTalkDisabled": true,
  "TorDisabled": true,
  "BravePlaylistEnabled": false,
  "BraveSpeedreaderEnabled": false,
  "BraveWaybackMachineEnabled": false,
  "BraveWebDiscoveryEnabled": false,
  "BraveP3AEnabled": false,
  "BraveStatsPingEnabled": false,
  "MetricsReportingEnabled": false
HEAD
    [ "$BARE" -eq 1 ] && cat <<'EXTRA'
  ,"PasswordManagerEnabled": false,
  "AutofillAddressEnabled": false,
  "AutofillCreditCardEnabled": false,
  "TranslateEnabled": false
EXTRA
    cat <<'FOOT'
}
FOOT
  } > "$DEST"
fi

echo "Wrote $DEST"
[ "$BARE" -eq 1 ] && echo "(--bare: password manager, autofill, and translate also disabled)"
echo "Now fully quit Brave (Cmd/Ctrl+Q) and reopen it, then check brave://policy."
