#!/bin/bash
# master-volume and install.sh, with stand-in commands in a throwaway HOME. Nothing real is touched.
# Run: bash tests/test-omavolume.sh
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok() { pass=$((pass+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# ---- master-volume ----
mkdir -p "$T/bin"
cat >"$T/bin/omarchy-audio-output-volume" <<'S'
#!/bin/bash
echo "output $*" >>"$LOG"; exit "${FAKE_STATUS:-0}"
S
cat >"$T/bin/pactl" <<'S'
#!/bin/bash
if [[ $1 == -f && $2 == json ]]; then cat "$STREAMS"; exit 0; fi
echo "pactl $*" >>"$LOG"
S
chmod +x "$T/bin/"*
export PATH="$T/bin:$PATH" LOG="$T/log" STREAMS="$T/streams.json"
cat >"$STREAMS" <<'J'
[
 {"index": 10, "mute": false, "volume": {"front-left": {"value": 20000}, "front-right": {"value": 20000}}, "properties": {"node.name": "Chromium"}},
 {"index": 11, "mute": true,  "volume": {"front-left": {"value": 30000}, "front-right": {"value": 30000}}, "properties": {"node.name": "MutedTab"}},
 {"index": 12, "mute": false, "volume": {"front-left": {"value": 65536}, "front-right": {"value": 65536}}, "properties": {"node.name": "Full"}},
 {"index": 13, "mute": false, "volume": {"front-left": {"value": 90000}, "front-right": {"value": 90000}}, "properties": {"node.name": "Boosted"}},
 {"index": 14, "mute": false, "volume": {"front-left": {"value": 30000}, "front-right": {"value": 30000}}, "properties": {"node.name": "omarchy_speaker_tuning.out"}},
 {"index": 15, "mute": false, "volume": {"front-left": {"value": 65536}, "front-right": {"value": 40000}}, "properties": {"node.name": "OneChannelLow"}}
]
J
: >"$LOG"; "$here/scripts/master-volume" raise; rc=$?
check "runs Omarchy's own volume command with its arguments" 'grep -qx "output raise" "$LOG"'
check "raises a stream below 100%" 'grep -qx "pactl set-sink-input-volume 10 100%" "$LOG"'
check "raises a muted stream's volume but never touches mute" '! grep -q "set-sink-input-mute" "$LOG" && grep -qx "pactl set-sink-input-volume 11 100%" "$LOG"'
check "leaves a stream already at 100% alone" '! grep -q "volume 12 " "$LOG"'
check "leaves a boosted stream (above 100%) alone" '! grep -q "volume 13 " "$LOG"'
check "skips the speaker-tuning stream" '! grep -q "volume 14 " "$LOG"'
check "raises a stream when only one channel is low" 'grep -qx "pactl set-sink-input-volume 15 100%" "$LOG"'
check "exits 0 when everything worked" '[[ $rc == 0 ]]'
: >"$LOG"; FAKE_STATUS=3 "$here/scripts/master-volume" lower; rc=$?
check "passes on the exit status of Omarchy's command" '[[ $rc == 3 ]]'
echo "[]" >"$STREAMS"; : >"$LOG"; "$here/scripts/master-volume" mute-toggle
check "no streams: only the output command runs" '[[ $(wc -l <"$LOG") == 1 ]]'
echo "not json" >"$STREAMS"; : >"$LOG"; "$here/scripts/master-volume" raise; rc=$?
check "an unreadable stream list does not break the key" '[[ $rc == 0 ]]'

# ---- install.sh ----
export HOME="$T/home"; mkdir -p "$HOME/.config/hypr" "$HOME/.config/omarchy/plugins"
printf -- '-- my bindings\n' >"$HOME/.config/hypr/bindings.lua"
out=$("$here/install.sh" --no-restart 2>&1); rc=$?
check "install succeeds" '[[ $rc == 0 ]]'
check "links the plugin and the script" '[[ -L $HOME/.config/omarchy/plugins/blackcode.omavolume && -L $HOME/.local/bin/master-volume ]]'
check "adds the key bindings once" '[[ $(grep -c "master-volume raise" "$HOME/.config/hypr/bindings.lua") == 1 ]]'
check "adds the panel binding once" '[[ $(grep -c "panel = \"blackcode.omavolume\"" "$HOME/.config/hypr/bindings.lua") == 1 ]]'
check "installs the WirePlumber setting" '[[ -f $HOME/.config/wireplumber/wireplumber.conf.d/51-bluez-software-volume.conf ]]'
check "--no-restart says how to apply the setting" 'grep -q "systemctl --user restart wireplumber" <<<"$out"'
"$here/install.sh" --no-restart >/dev/null 2>&1
check "running it again changes nothing" '[[ $(grep -c "master-volume raise" "$HOME/.config/hypr/bindings.lua") == 1 && $(grep -c "panel = \"blackcode.omavolume\"" "$HOME/.config/hypr/bindings.lua") == 1 ]]'
# a commented-out copy must not count as installed
printf -- '-- o.rebind("XF86AudioRaiseVolume", "x", "master-volume raise")\n' >"$HOME/.config/hypr/bindings.lua"
"$here/install.sh" --no-restart >/dev/null 2>&1
check "a commented-out line does not block the real bindings" '[[ $(grep -vc "^--" "$HOME/.config/hypr/bindings.lua") -ge 5 ]]'
# an existing different WirePlumber file is kept as a backup
echo "# mine" >"$HOME/.config/wireplumber/wireplumber.conf.d/51-bluez-software-volume.conf"
"$here/install.sh" --no-restart >/dev/null 2>&1
check "a different WirePlumber file is backed up first" 'grep -q "# mine" "$HOME"/.config/wireplumber/wireplumber.conf.d/51-bluez-software-volume.conf.bak-*'
# a failed restart is reported and retried by the next run; a good one clears the retry
unset XDG_STATE_HOME
cat >"$T/bin/systemctl" <<'S'
#!/bin/bash
echo "systemctl $*" >>"$LOG"; exit "${FAKE_SYSTEMCTL:-0}"
S
chmod +x "$T/bin/systemctl"
rm -f "$HOME"/.config/wireplumber/wireplumber.conf.d/51-bluez-software-volume.conf*
rm -f "$HOME/.local/state/omavolume/wireplumber-restart-pending"
: >"$LOG"; out=$(FAKE_SYSTEMCTL=1 "$here/install.sh" 2>&1); rc=$?
check "a failed WirePlumber restart makes the installer fail and say so" '[[ $rc != 0 ]] && grep -q "failed" <<<"$out"'
: >"$LOG"; out=$("$here/install.sh" 2>&1); rc=$?
check "running it again retries the restart that failed" '[[ $rc == 0 ]] && grep -q "restart wireplumber" "$LOG"'
: >"$LOG"; "$here/install.sh" >/dev/null 2>&1
check "once restarted, a further run does not restart again" '! grep -q "restart wireplumber" "$LOG"'
check "installer config is byte-identical to the CLI copy" 'python3 -I -c "
import importlib.machinery as m,importlib.util as u,sys
l=m.SourceFileLoader(\"o\",sys.argv[1]);s=u.spec_from_loader(\"o\",l);x=u.module_from_spec(s);l.exec_module(x)
sys.exit(open(sys.argv[2]).read()!=x.WIREPLUMBER_CONF)" "$here/omavolume" "$here/config/51-bluez-software-volume.conf"'
# a real folder (omarchy plugin add) must not be replaced or linked into
rm "$HOME/.config/omarchy/plugins/blackcode.omavolume"; mkdir "$HOME/.config/omarchy/plugins/blackcode.omavolume"
out=$("$here/install.sh" --no-restart 2>&1); rc=$?
check "refuses to replace a plugin folder installed another way" '[[ $rc != 0 ]] && grep -q "not a link" <<<"$out" && [[ ! -e $HOME/.config/omarchy/plugins/blackcode.omavolume/omavolume ]]'
check "bad option is refused" '! "$here/install.sh" --nope >/dev/null 2>&1'

echo; echo "$pass passed, $fail failed"; [[ $fail == 0 ]]
