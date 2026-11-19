# OmaVolume: one master volume for Omarchy

![OmaVolume: one master volume for Omarchy](poster/13-alshareedah22-omavolume-detail.webp)

Video in the browser ignores your volume keys? On Omarchy, apps and Bluetooth
headsets can each keep their own volume, so the keys seem to do nothing.
OmaVolume makes the output volume the only one that matters.

- **Bar widget**: master volume slider, output picker and per-app mixer. Moving the
  volume or muting sets every app stream (browser, YouTube, players) to 100% and
  unmutes it, and new streams get the same treatment.
- **Volume keys**: `master-volume` runs Omarchy's own volume command (with its
  on-screen popup) and syncs the app streams the same way.
- **Bluetooth fix**: some headsets ignore the hardware (AVRCP) volume PipeWire sends,
  so only mute worked. A small WirePlumber setting makes PipeWire apply the volume itself.

## Install

The widget alone (the sync happens when you use the widget):

```bash
omarchy plugin add https://github.com/alshareedah22/omavolume --enable
```

The whole thing (widget, volume keys, Bluetooth fix). Clone the repo and run the
installer; it is safe to run again:

```bash
git clone https://github.com/alshareedah22/omavolume
cd omavolume && ./install.sh
```

The installer links the plugin into `~/.config/omarchy/plugins/`, links
`master-volume` into `~/.local/bin/`, adds the key bindings to
`~/.config/hypr/bindings.lua` (once), and installs the Bluetooth setting. If that
setting changes, reconnect your headset once.

## Files

| Path | What it is |
|------|------------|
| `manifest.json`, `Panel.qml`, `Model.js` | The bar widget, plugin id `blackcode.omavolume` |
| `scripts/master-volume` | What the volume keys run |
| `config/bindings.lua.snippet` | Key bindings appended to `bindings.lua` |
| `config/51-bluez-software-volume.conf` | WirePlumber fix for headsets that ignore hardware volume |
| `install.sh` | Links everything into place |

## Settings

Set `property bool masterSync: false` in `Panel.qml` to stop the widget syncing
app streams.

## Uninstall

```bash
omarchy plugin remove blackcode.omavolume
```

Then remove the "Master volume" block from `~/.config/hypr/bindings.lua`, delete
`~/.config/wireplumber/wireplumber.conf.d/51-bluez-software-volume.conf`, and
`rm ~/.local/bin/master-volume`.

## Credits

The widget is based on Omarchy's built-in audio plugin (`omarchy.audio`). MIT licensed.
