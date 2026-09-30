#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: setup-opendisplay.sh [--install-mac] [--open-ipad-links] [--verify]
EOF
}

install_mac() {
  : "${OPENDISPLAY_DMG_URL:?Set OPENDISPLAY_DMG_URL to an operator-approved immutable release URL}"
  : "${OPENDISPLAY_DMG_SHA256:?Set OPENDISPLAY_DMG_SHA256 to the expected SHA-256}"
  local workdir="$(mktemp -d "${TMPDIR:-/tmp}/opendisplay-install.XXXXXX")"
  local mountpoint="$workdir/mount"
  local mounted=0
  cleanup() {
    if [[ "$mounted" -eq 1 ]]; then hdiutil detach "$mountpoint" >/dev/null 2>&1 || true; fi
    rm -rf -- "$workdir"
  }
  trap cleanup EXIT
  mkdir -m 700 "$mountpoint"
  curl --fail --location --proto '=https' --tlsv1.2 "$OPENDISPLAY_DMG_URL" -o "$workdir/OpenDisplay.dmg"
  printf '%s  %s\n' "$OPENDISPLAY_DMG_SHA256" "$workdir/OpenDisplay.dmg" | shasum -a 256 -c -
  hdiutil attach "$workdir/OpenDisplay.dmg" -readonly -nobrowse -mountpoint "$mountpoint" >/dev/null
  mounted=1
  [[ -d "$mountpoint/OpenDisplay.app" ]] || { echo "OpenDisplay.app not found" >&2; exit 1; }
  codesign --verify --deep --strict --verbose=2 "$mountpoint/OpenDisplay.app"
  spctl --assess --type execute --verbose=2 "$mountpoint/OpenDisplay.app"
  [[ ! -e /Applications/OpenDisplay.app ]] || { echo "Refusing to overwrite /Applications/OpenDisplay.app" >&2; exit 1; }
  ditto "$mountpoint/OpenDisplay.app" /Applications/OpenDisplay.app
  echo "Installed verified OpenDisplay.app from $OPENDISPLAY_DMG_URL"
  echo "SHA-256: $OPENDISPLAY_DMG_SHA256"
  open -g -a OpenDisplay
}

open_ipad_links() {
  open 'https://apps.apple.com/app/id6754265378'
  open 'https://testflight.apple.com/join/3NYaY11c'
}

verify() {
  [[ -d /Applications/OpenDisplay.app ]] && echo "sender: installed" || echo "sender: missing"
  system_profiler SPUSBDataType 2>/dev/null | rg -qi 'iPad|Apple' && echo "iPad USB: detected" || echo "iPad USB: not detected"
  local log="$HOME/Library/Logs/OpenDisplay/opendisplay.log"
  [[ -f "$log" ]] && tail -80 "$log" | rg 'Extending to iPad|Mirroring to iPad|Connection lost|Failed to find any displays|virtual display created' || echo "OpenDisplay log: not found"
}

[[ $# -gt 0 ]] || { usage; exit 0; }
for arg in "$@"; do
  case "$arg" in
    --install-mac) install_mac ;;
    --open-ipad-links) open_ipad_links ;;
    --verify) verify ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 2 ;;
  esac
done
