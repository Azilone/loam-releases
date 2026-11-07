#!/bin/bash
# Installs Loam on a Mac, or updates it:
#
#   curl -fsSL https://raw.githubusercontent.com/Azilone/loam-releases/main/install.sh | bash   (or https://loam.md/install.sh)
#   curl -fsSL https://raw.githubusercontent.com/Azilone/loam-releases/main/install.sh | bash -s -- --beta --no-cli --no-open
#
# It reads the release feed, downloads the app with curl, checks its SHA-256, puts Loam.app in /Applications (or
# ~/Applications), links the `loam` command line into ~/.local/bin and opens the app. A download made by curl carries
# no quarantine flag, so macOS does not stop the first launch. After that, Loam updates itself.
set -euo pipefail

feed="${LOAM_FEED:-https://raw.githubusercontent.com/Azilone/loam-releases/main}"
channel=stable
link_cli=1
open_app=1
for flag in "$@"; do
  case "$flag" in
    --beta) channel=beta ;;
    --no-cli) link_cli=0 ;;
    --no-open) open_app=0 ;;
    *) echo "Unknown option: $flag" >&2; exit 2 ;;
  esac
done

fail() { echo "Loam: $*" >&2; exit 1; }
say() { echo "==> $*"; }

[ "$(uname -s)" = Darwin ] || fail "Loam runs on macOS only."
[ "$(uname -m)" = arm64 ] || fail "Loam needs a Mac with Apple silicon."
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 26 ] || fail "Loam needs macOS 26 or later (this Mac runs $(sw_vers -productVersion))."

say "Reading the $channel release"
json="$(curl -fsSL "$feed/$channel.json")" || fail "cannot reach $feed/$channel.json"
field() { plutil -extract "$1" raw -o - - <<<"$json"; }
version="$(field version)"
url="$(field url)"
sha256="$(field sha256)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
say "Downloading Loam $version"
curl -fL --progress-bar -o "$work/Loam.zip" "$url" || fail "download failed: $url"
[ "$(shasum -a 256 "$work/Loam.zip" | cut -d' ' -f1)" = "$sha256" ] || fail "the download is damaged (SHA-256 mismatch)"
ditto -x -k "$work/Loam.zip" "$work/unpacked"
[ -d "$work/unpacked/Loam.app" ] || fail "the archive holds no Loam.app"

if [ -n "${LOAM_APPS_DIR:-}" ]; then apps="$LOAM_APPS_DIR"; mkdir -p "$apps"
elif [ -w /Applications ]; then apps=/Applications; else apps="$HOME/Applications"; mkdir -p "$apps"; fi
if [ -z "${LOAM_APPS_DIR:-}" ] && pgrep -xq Loam; then
  say "Quitting Loam"
  osascript -e 'tell application "Loam" to quit' >/dev/null 2>&1 || true
  for _ in $(seq 1 50); do pgrep -xq Loam || break; sleep 0.2; done
  pgrep -xq Loam && fail "Loam is still running: quit it and run this again."
fi
rm -rf "$apps/Loam.app"
mv "$work/unpacked/Loam.app" "$apps/Loam.app"
xattr -dr com.apple.quarantine "$apps/Loam.app" 2>/dev/null || true
say "Installed Loam $version in $apps"

if [ "$link_cli" = 1 ]; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$apps/Loam.app/Contents/Helpers/loam" "$HOME/.local/bin/loam"
  say "Linked the command line: ~/.local/bin/loam"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "    ~/.local/bin is not on your PATH. Add it: echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc" ;;
  esac
fi

[ "$open_app" = 1 ] && open "$apps/Loam.app"
say "Done. Loam checks for updates by itself once a day."
