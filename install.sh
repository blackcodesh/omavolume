#!/bin/bash
# Install OmaVolume (safe to run again). Links the plugin and script into place, so edits here
# go live, adds the volume-key bindings once, and installs the Bluetooth software-volume setting.
#
#   ./install.sh               install
#   ./install.sh --no-restart  do not restart WirePlumber (audio and Bluetooth stay connected;
#                              reconnect your headset or restart WirePlumber yourself later)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
restart=1
for arg in "$@"; do
  case $arg in
    --no-restart) restart=0 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

plugin=~/.config/omarchy/plugins/blackcode.omavolume
script=~/.local/bin/master-volume
conf=~/.config/wireplumber/wireplumber.conf.d/51-bluez-software-volume.conf
b=~/.config/hypr/bindings.lua

# A real folder or file is somebody's install (e.g. `omarchy plugin add`): never replace it.
for target in "$plugin" "$script"; do
  if [[ -e $target && ! -L $target ]]; then
    echo "install.sh: $target exists and is not a link (installed another way?). Remove it first, or skip install.sh." >&2
    exit 1
  fi
done

mkdir -p ~/.local/bin ~/.config/omarchy/plugins ~/.config/wireplumber/wireplumber.conf.d
chmod +x "$here/scripts/master-volume"
ln -sfn "$here/scripts/master-volume" "$script"
ln -sfn "$here" "$plugin"
# Older name of this plugin: drop the link if present
[[ -L ~/.config/omarchy/plugins/blackcode.audio ]] && rm ~/.config/omarchy/plugins/blackcode.audio || true

# The WirePlumber file: keep a copy of a different file that was there before.
changed=0
if ! cmp -s "$here/config/51-bluez-software-volume.conf" "$conf" 2>/dev/null; then
  [[ -f $conf ]] && cp "$conf" "$conf.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$here/config/51-bluez-software-volume.conf" "$conf"
  changed=1
fi

# Bindings: appended once. Commented-out lines do not count as installed.
active() { grep -vE '^[[:space:]]*--' "$b" 2>/dev/null | grep -qF -- "$1"; }
if ! active "master-volume raise"; then
  { echo; sed '/Open the OmaVolume panel/,$d' "$here/config/bindings.lua.snippet"; } >> "$b"
fi
if ! active 'panel = "blackcode.omavolume"'; then
  { echo; sed -n '/Open the OmaVolume panel/,$p' "$here/config/bindings.lua.snippet"; } >> "$b"
fi
hyprctl reload >/dev/null 2>&1 || true

if [[ $changed == 1 ]]; then
  if [[ $restart == 1 ]]; then
    systemctl --user restart wireplumber
    echo "WirePlumber restarted (audio and Bluetooth reconnect): reconnect your headset once."
  else
    echo "WirePlumber config installed. Run 'systemctl --user restart wireplumber' (or reconnect your headset) to apply it."
  fi
fi
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
echo "OmaVolume installed. Enable the widget with: omarchy plugin enable blackcode.omavolume"
