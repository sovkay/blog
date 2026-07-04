#!/bin/sh
# ============================================================================
# fix-brave.sh — make Brave "just the browser", for free.
#
# Reproduces the paid Brave Origin ($59.99) build using Brave's own enterprise
# policies. It writes ONE managed-policy file that disables Wallet, Rewards,
# Leo AI, VPN, News, Talk, Tor, and telemetry.
#
# It does NOT install, download, or delete anything — it only flips switches
# Brave already ships. Fully reversible with --undo.
#
#   Read the write-up:  https://ksorv.com/blog/brave-origin-for-free
#   Requires root:      it writes to a system-managed policy directory.
#
# Usage:
#   sudo sh fix-brave.sh            # disable the bloat, keep the browser usable
#   sudo sh fix-brave.sh --bare     # also disable password manager/autofill/translate
#   sudo sh fix-brave.sh --undo     # remove the policy, restore stock Brave
# ============================================================================
set -eu   # exit on any error (-e) or unset variable (-u)

# --- parse flags ------------------------------------------------------------
BARE=0   # 1 = also strip core conveniences (passwords, autofill, translate)
UNDO=0   # 1 = remove the policy file and exit
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

# --- require root -----------------------------------------------------------
# The policy lives in a system directory only root can write. We do NOT
# silently re-invoke sudo for you — you should see exactly what gets elevated.
if [ "$(id -u)" -ne 0 ]; then
  echo "This writes a system policy file and needs root." >&2
  echo "Re-run: sudo sh fix-brave.sh $*" >&2
  exit 1
fi

# --- pick the right policy path for this OS ---------------------------------
# Brave reads managed policies from a different place on each platform.
case "$(uname -s)" in
  Darwin) OS=mac;   DEST="/Library/Managed Preferences/com.brave.Browser.plist" ;;
  Linux)  OS=linux; DEST="/etc/brave/policies/managed/fix-brave.json" ;;
  *) echo "Unsupported OS (macOS + Linux only)." >&2; exit 1 ;;
esac

# --- undo: just delete the file and stop ------------------------------------
if [ "$UNDO" -eq 1 ]; then
  rm -f "$DEST"
  echo "Removed $DEST"
  echo "Quit Brave (Cmd/Ctrl+Q) and reopen to restore stock Brave."
  exit 0
fi

mkdir -p "$(dirname "$DEST")"

# --- write the policy -------------------------------------------------------
# Same set of keys on both platforms; only the file format differs
# (macOS wants an XML plist, Linux wants JSON). Boolean semantics:
#   *Disabled = true   -> feature OFF     (Wallet, Rewards, VPN, News, Talk, Tor)
#   *Enabled  = false  -> feature OFF     (AI chat, playlist, telemetry, etc.)
if [ "$OS" = mac ]; then
  {
    cat <<'HEAD'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- Web3 / crypto -->
  <key>BraveWalletDisabled</key><true/>
  <key>BraveRewardsDisabled</key><true/>
  <!-- AI -->
  <key>BraveAIChatEnabled</key><false/>
  <!-- Extras Origin strips -->
  <key>BraveVPNDisabled</key><true/>
  <key>BraveNewsDisabled</key><true/>
  <key>BraveTalkDisabled</key><true/>
  <key>TorDisabled</key><true/>
  <key>BravePlaylistEnabled</key><false/>
  <key>BraveSpeedreaderEnabled</key><false/>
  <key>BraveWaybackMachineEnabled</key><false/>
  <key>BraveWebDiscoveryEnabled</key><false/>
  <!-- Telemetry -->
  <key>BraveP3AEnabled</key><false/>
  <key>BraveStatsPingEnabled</key><false/>
  <key>MetricsReportingEnabled</key><false/>
HEAD
    # --bare only: these are real browser conveniences, not bloat.
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
    # --bare only: leading comma continues the object above (valid JSON).
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

# --- done -------------------------------------------------------------------
echo "Wrote $DEST"
[ "$BARE" -eq 1 ] && echo "(--bare: password manager, autofill, and translate also disabled)"
echo "Now fully quit Brave (Cmd/Ctrl+Q) and reopen it, then check brave://policy to confirm."
