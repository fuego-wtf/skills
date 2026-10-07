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
  local failed=0 usb_output events last_event
  local app="${OPENDISPLAY_APP_PATH:-/Applications/OpenDisplay.app}"
  local log="${OPENDISPLAY_LOG_PATH:-$HOME/Library/Logs/OpenDisplay/opendisplay.log}"
  if [[ -d "$app" ]]; then
    echo "sender: installed"
  else
    echo "sender: missing"; failed=1
  fi
  if usb_output=$(system_profiler SPUSBDataType 2>/dev/null); then
    if printf '%s\n' "$usb_output" | rg -qi '^[[:space:]]*(iPad|iPhone)([[:space:]][^:]*)?:[[:space:]]*$'; then
      echo "iPad/iPhone USB: detected"
    else
      echo "iPad/iPhone USB: not detected"; failed=1
    fi
  else
    echo "iPad/iPhone USB: inspection failed"; failed=1
  fi
  if [[ ! -f "$log" ]]; then
    echo "OpenDisplay log: not found ($log)"; failed=1
  elif [[ ! -r "$log" ]]; then
    echo "OpenDisplay log: unreadable ($log)"; failed=1
  elif events=$(tail -80 "$log" | rg 'Extending to (iPad|iPhone)|Mirroring to (iPad|iPhone)|Connection lost|Failed to find any displays|virtual display created|mode (extend|mirror)'); then
    printf '%s\n' "$events"
    last_event=$(printf '%s\n' "$events" | tail -1)
    if printf '%s\n' "$last_event" | rg -q 'Extending to (iPad|iPhone)|mode extend'; then
      echo "OpenDisplay log: latest relevant event indicates Extend"
    else
      echo "OpenDisplay log: Extend not confirmed by latest relevant event"; failed=1
    fi
  else
    echo "OpenDisplay log: present, but no relevant events in the last 80 lines"; failed=1
  fi
  echo "Confirm live updates on the receiver with the physical monitor unplugged; historical logs alone cannot prove a live stream."
  return "$failed"
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
