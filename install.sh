#!/bin/bash
# Install OmaVolume (idempotent). Links source files into place so edits here go live.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

mkdir -p ~/.local/bin ~/.config/omarchy/plugins ~/.config/wireplumber/wireplumber.conf.d
chmod +x "$here/scripts/master-volume"
ln -sfn "$here/scripts/master-volume" ~/.local/bin/master-volume
ln -sfn "$here" ~/.config/omarchy/plugins/blackcode.omavolume
# Older name of this plugin: drop the link if present
[[ -L ~/.config/omarchy/plugins/blackcode.audio ]] && rm ~/.config/omarchy/plugins/blackcode.audio || true
conf=~/.config/wireplumber/wireplumber.conf.d/51-bluez-software-volume.conf
changed=0
cmp -s "$here/config/51-bluez-software-volume.conf" "$conf" 2>/dev/null || { cp "$here/config/51-bluez-software-volume.conf" "$conf"; changed=1; }

b=~/.config/hypr/bindings.lua
if ! grep -q "master-volume raise" "$b" 2>/dev/null; then
  { echo; sed '/Open the OmaVolume panel/,$d' "$here/config/bindings.lua.snippet"; } >> "$b"
fi
if ! grep -q 'panel = "blackcode.omavolume"' "$b" 2>/dev/null; then
  { echo; sed -n '/Open the OmaVolume panel/,$p' "$here/config/bindings.lua.snippet"; } >> "$b"
fi
hyprctl reload >/dev/null 2>&1 || true

if [[ $changed == 1 ]]; then
  systemctl --user restart wireplumber
  echo "WirePlumber config changed: reconnect your Bluetooth headset once."
fi
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
echo "OmaVolume installed."
