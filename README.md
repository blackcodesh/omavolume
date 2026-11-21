# OmaVolume: one master volume for Omarchy

![OmaVolume: one master volume for Omarchy](poster/13-blackcodesh-omavolume-detail.webp)

Video in the browser ignores your volume keys? On Omarchy, apps and Bluetooth
headsets can each keep their own volume, so the keys seem to do nothing.
OmaVolume makes the output volume the only one that matters.

- **Bar widget**: master volume slider, output picker and per-app mixer. Moving the
  volume or muting raises every app stream (browser, YouTube, players) that sits below
  100% back to 100%, and a stream that shows up later is synced shortly after it appears.
  What it leaves alone on purpose: a stream you boosted above 100%, every stream's mute
  state (a muted tab stays muted) and the speaker-tuning stream. This is the "master"
  part: a stream you turn down in the per-app mixer goes back to 100% at the next volume
  change. Set `masterSync` to `false` (see Settings) to keep the mixer's levels.
- **Volume keys, with nothing to set up**: the widget syncs the apps whenever the output volume
  changes, whoever changed it: the volume keys, this panel's slider, another app, pavucontrol.
  No key bindings and no script are needed.
- **Bluetooth fix (optional)**: some headsets ignore the hardware (AVRCP) volume PipeWire sends,
  so only mute works. `python3 -I ~/.config/omarchy/plugins/blackcode.omavolume/omavolume bluetooth on`
  makes PipeWire apply the volume itself. It applies to **every** Bluetooth device, not just the broken
  one (a headset whose own buttons used to track the system volume will stop doing that), which is
  why it is not switched on for you. `bluetooth off` undoes it.

**Compatibility:** works with Omarchy 4.5 (checked on 4.5.0-3: manifest validation, the plugin's own tests, and every Omarchy component, command and bar interface it uses).

## What's new in 1.2.1

- **A failed WirePlumber restart is no longer reported as done.** `omavolume bluetooth on|off --restart` now checks
  that `systemctl --user restart wireplumber` really worked; if not, it says so and exits with an error. Running the
  same command again retries the restart even when the setting is already in place (before, it stopped at "already
  on" and the running audio kept the old setting).
- `install.sh` does the same: a failed restart makes it fail, and the next run retries it (a small marker in
  `~/.local/state/omavolume` remembers the restart is still owed).
- The installer's WirePlumber file is now identical to the one `omavolume bluetooth on` writes, so
  `omavolume bluetooth off` also removes a setting that `install.sh` put there.

## What's new in 1.2.0

- **Zero setup.** `omarchy plugin add ... --enable` is the whole install. The volume keys now sync the apps with no key
  bindings and no `master-volume` script: the widget reacts to any change of the output volume. Tested on a real bar
  with a playing stream: an app turned down to 30% or 25% went back to 100% on a volume change, through
  `pactl` and through Omarchy's own volume command (what the default keys run); a muted app stayed muted; an app boosted
  to 120% was left alone.
- **Bluetooth fix is one command** (`omavolume bluetooth on|off|status`) instead of a git clone and an installer. It stays
  opt-in because it changes every Bluetooth device.
- `install.sh`, the `master-volume` script and the key bindings still work, and are now optional extras (see Install).

## What's new in 1.1.1

- Housekeeping: 1.1.0 accidentally included two Python bytecode files (`__pycache__`); they are removed and ignored.
  No behaviour change. The install commands in this README now use the repository's current GitHub address.

## What's new in 1.1.0

- **One audio icon, not two.** Enabling OmaVolume (`omarchy plugin add ... --enable`) used to add its icon next to
  Omarchy's own audio icon, so the bar showed two. Now, the first time it runs, OmaVolume takes the place of Omarchy's
  audio icon, in the same spot (any bar section), and moves that icon's settings to the `plugins` list. It runs once:
  if you later put Omarchy's icon back, nothing swaps it again. Undo it any time with
  `python3 -I ~/.config/omarchy/plugins/blackcode.omavolume/omavolume unswap`; run
  `omavolume setup --force` to do it again.
- It changes `shell.json` safely: atomic, locked, re-checked just before the write, symlinks kept, and the first file it
  changed is kept as `shell.json.omavolume-original` (plus the last 3 earlier versions).

## What's new in 1.0.1

- The sync no longer unmutes streams, no longer pulls down a stream you boosted above 100%,
  and skips the speaker-tuning stream. A muted tab stays muted.
- `master-volume` reads the stream list once per key press (was two `pactl` calls per stream)
  and passes on the exit status of Omarchy's volume command.
- The widget syncs a new stream shortly after it appears, in case its audio was not ready.
- `install.sh`: refuses to replace a plugin folder installed another way, backs up a different
  WirePlumber file, `--no-restart` skips restarting WirePlumber, and commented-out binding
  lines no longer count as installed.
- LICENSE now credits Omarchy; README lists the full uninstall and the Bluetooth setting's
  side effect on all Bluetooth devices. Tests: `bash tests/test-omavolume.sh`.

## Install

```bash
omarchy plugin add https://github.com/blackcodesh/omavolume --enable
```

That is all. The first time it runs, OmaVolume replaces Omarchy's own audio icon on the bar, so
there is a single audio icon (see "What's new in 1.1.0"), and the volume keys sync the apps by
themselves (see "What's new in 1.2.0"). Nothing else to install, bind or configure.

### Optional extras

- **Bluetooth headsets that ignore the volume**: `omavolume bluetooth on` (see above), then
  `systemctl --user restart wireplumber` or reconnect the headset once (`bluetooth on --restart`
  restarts WirePlumber for you, which briefly drops audio and Bluetooth).
- **`SUPER + CTRL + A` opening this panel**: Omarchy's own binding opens its own audio panel. To open this
  one instead, clone the repo and run `./install.sh`. It links the plugin and the `master-volume` script into
  place, adds the panel binding, and (for people who want it) the key bindings that run `master-volume`, which
  are no longer needed for the sync. It also installs the Bluetooth setting. It is safe to run again and
  refuses to run if the plugin folder or script already exists as a real folder or file (for example from
  `omarchy plugin add`): remove that first. `./install.sh --no-restart` skips restarting WirePlumber.

Also listed in the Omarchy plugin marketplace (https://plugins.omarchy.org): search for **OmaVolume**.

## Files

| Path | What it is |
|------|------------|
| `manifest.json`, `Panel.qml`, `Model.js` | The bar widget, plugin id `blackcode.omavolume` |
| `Service.qml`, `omavolume` | First-run setup: swaps Omarchy's audio icon for this one (`setup`, `unswap`); the optional `bluetooth` command |
| `scripts/master-volume` | Optional: what the key bindings from `install.sh` run (no longer needed for the sync) |
| `config/bindings.lua.snippet` | Optional key and panel bindings appended to `bindings.lua` by `install.sh` |
| `config/51-bluez-software-volume.conf` | WirePlumber fix for headsets that ignore hardware volume |
| `install.sh` | Optional: links everything into place and adds the bindings |

## Settings

Set `property bool masterSync: false` in `Panel.qml` to stop the widget syncing
app streams (an edit to an installed copy is overwritten by `omarchy plugin update`).

## Uninstall

Put Omarchy's own audio icon back first, while the plugin is still installed:

```bash
python3 -I ~/.config/omarchy/plugins/blackcode.omavolume/omavolume unswap
omarchy plugin remove blackcode.omavolume
```

If you switched on the Bluetooth option, run `omavolume bluetooth off` before removing the plugin (then
restart WirePlumber). If you used the optional `install.sh`, also remove the "Master volume" block and the
`SUPER + CTRL + A` (OmaVolume panel) line from `~/.config/hypr/bindings.lua` (Omarchy's own binding comes back),
`rm ~/.local/bin/master-volume`, and delete the link `~/.config/omarchy/plugins/blackcode.omavolume` (only the
link: `omarchy plugin remove` on a linked plugin has not been tested here).

## Credits and tests

`Panel.qml` and `Model.js` are derived from Omarchy's built-in audio plugin (`omarchy.audio`,
MIT, copyright David Heinemeier Hansson); the added code is MIT, copyright BlackCode. Tests (all in
throwaway folders): `bash tests/test-omavolume.sh` for the key script and the installer, and
`python3 -I -m unittest discover -s tests -p "test_*.py"` for the setup tool.

## License

MIT, see [LICENSE](LICENSE). `Panel.qml` and `Model.js` are derived from Omarchy's built-in audio plugin (MIT, copyright David Heinemeier Hansson); the added code is copyright BlackCode.
