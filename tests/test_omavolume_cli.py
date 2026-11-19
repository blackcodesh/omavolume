"""The omavolume setup tool (OmaVolume replaces Omarchy's own audio icon). Run:
python3 -I -m unittest discover -s tests -p "test_*.py"   (a throwaway directory; the real shell.json is never touched)"""
import glob
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "omavolume")
SECTIONS = ("left", "centerBegin", "center", "centerEnd", "right", "tray")
ME = "blackcode.omavolume"


def run(*args):
    env = dict(os.environ, XDG_RUNTIME_DIR=tempfile.gettempdir())
    return subprocess.run([sys.executable, "-I", SCRIPT, *args], capture_output=True, text=True, env=env)


class Case(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.path = os.path.join(self.dir, "shell.json")
        self.marker = self.path + ".omavolume-setup-done"

    def layout(self, **sections):
        base = {s: [] for s in SECTIONS}
        base.update(sections)
        return {"bar": {"layout": base}}

    def write(self, config):
        with open(self.path, "w") as f:
            json.dump(config, f)

    def read(self):
        with open(self.path) as f:
            return json.load(f)

    def ids(self):
        return [e if isinstance(e, str) else e.get("id") for v in self.read()["bar"]["layout"].values() for e in v]


class Setup(Case):
    def test_the_stock_audio_icon_becomes_omavolume_in_the_same_place(self):
        self.write(self.layout(right=[{"id": "omarchy.network"}, {"id": "omarchy.audio"}, {"id": "omarchy.power"}, {"id": ME}]))
        out = run("setup", self.path)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(self.read()["bar"]["layout"]["right"], [{"id": "omarchy.network"}, {"id": ME}, {"id": "omarchy.power"}])
        self.assertEqual(self.ids().count(ME), 1)
        self.assertNotIn("omarchy.audio", self.ids())

    def test_every_bar_section(self):
        for section in SECTIONS:
            others = {"right": [{"id": ME}]} if section != "right" else {}
            stock = {section: [{"id": "omarchy.network"}, {"id": "omarchy.audio"}]}
            if section == "right":
                stock = {"right": [{"id": "omarchy.network"}, {"id": "omarchy.audio"}, {"id": ME}]}
            self.write(self.layout(**{**others, **stock}))
            if os.path.exists(self.marker):
                os.unlink(self.marker)
            self.assertEqual(run("setup", self.path).returncode, 0, section)
            layout = self.read()["bar"]["layout"]
            self.assertEqual(layout[section][:2], [{"id": "omarchy.network"}, {"id": ME}], section)
            self.assertEqual(self.ids().count(ME), 1, section)
            self.assertNotIn("omarchy.audio", self.ids(), section)

    def test_bare_string_entries(self):
        self.write(self.layout(right=["omarchy.network", "omarchy.audio", ME], left=["omarchy.menu"]))
        run("setup", self.path)
        layout = self.read()["bar"]["layout"]
        self.assertEqual(layout["right"], ["omarchy.network", {"id": ME}])
        self.assertEqual(layout["left"], ["omarchy.menu"])

    def test_the_stock_widgets_settings_move_to_plugins_and_back(self):
        self.write(self.layout(right=[{"id": "omarchy.audio", "showPercent": True}, {"id": ME}]))
        run("setup", self.path)
        self.assertIn({"id": "omarchy.audio", "showPercent": True}, self.read()["plugins"])
        run("unswap", self.path)
        data = self.read()
        self.assertEqual(data["bar"]["layout"]["right"], [{"id": "omarchy.audio", "showPercent": True}])
        self.assertNotIn("plugins", data)

    def test_not_enabled_changes_nothing_and_leaves_no_marker(self):
        self.write(self.layout(right=[{"id": "omarchy.audio"}]))
        before = open(self.path).read()
        out = run("setup", self.path)
        self.assertIn("not on the bar", out.stdout)
        self.assertEqual(open(self.path).read(), before)
        self.assertFalse(os.path.exists(self.marker))

    def test_enabled_without_a_stock_icon_changes_nothing_but_is_done(self):
        self.write(self.layout(right=[{"id": "omarchy.network"}, {"id": ME}]))
        before = open(self.path).read()
        out = run("setup", self.path)
        self.assertIn("nothing to replace", out.stdout)
        self.assertEqual(open(self.path).read(), before)
        self.assertTrue(os.path.exists(self.marker))

    def test_setup_runs_once(self):
        self.write(self.layout(right=[{"id": "omarchy.audio"}, {"id": ME}]))
        run("setup", self.path)
        after_first = open(self.path).read()
        out = run("setup", self.path)
        self.assertIn("already set up", out.stdout)
        self.assertEqual(open(self.path).read(), after_first)

    def test_removing_the_icon_later_is_not_undone_by_a_later_start(self):
        self.write(self.layout(right=[{"id": "omarchy.audio"}, {"id": ME}]))
        run("setup", self.path)
        run("unswap", self.path)                       # the user goes back to Omarchy's own icon
        data = self.read(); data["bar"]["layout"]["right"].append({"id": ME}); self.write(data)   # ...and adds OmaVolume's again, as a second icon
        before = open(self.path).read()
        self.assertIn("already set up", run("setup", self.path).stdout)
        self.assertEqual(open(self.path).read(), before)

    def test_force_runs_it_again_on_purpose(self):
        self.write(self.layout(right=[{"id": "omarchy.audio"}, {"id": ME}]))
        run("setup", self.path)
        run("unswap", self.path)
        data = self.read(); data["bar"]["layout"]["right"].append({"id": ME}); self.write(data)
        self.assertEqual(run("setup", "--force", self.path).returncode, 0)
        self.assertNotIn("omarchy.audio", self.ids())
        self.assertEqual(self.ids().count(ME), 1)

    def test_several_copies_end_up_as_one(self):
        self.write(self.layout(left=[{"id": ME}], right=[{"id": "omarchy.audio"}, {"id": ME}]))
        run("setup", self.path)
        self.assertEqual(self.ids().count(ME), 1)
        self.assertEqual(self.read()["bar"]["layout"]["right"], [{"id": ME}])

    def test_the_bar_layout_is_otherwise_untouched(self):
        config = self.layout(left=[{"id": "omarchy.menu"}, {"id": "omarchy.workspaces"}], center=[{"id": "omarchy.clock"}],
                             right=[{"id": "omarchy.network"}, {"id": "omarchy.audio"}, {"id": ME}])
        config["idle"] = {"lock": 600}
        self.write(config)
        run("setup", self.path)
        data = self.read()
        self.assertEqual(data["idle"], {"lock": 600})
        self.assertEqual(data["bar"]["layout"]["left"], config["bar"]["layout"]["left"])
        self.assertEqual(data["bar"]["layout"]["center"], config["bar"]["layout"]["center"])


class Hardening(Case):
    def test_a_symlinked_shell_json_stays_a_symlink(self):
        target = os.path.join(self.dir, "dotfiles.json")
        with open(target, "w") as f:
            json.dump(self.layout(right=[{"id": "omarchy.audio"}, {"id": ME}]), f)
        os.symlink(target, self.path)
        self.assertEqual(run("setup", self.path).returncode, 0)
        self.assertTrue(os.path.islink(self.path))
        self.assertEqual(json.load(open(target))["bar"]["layout"]["right"], [{"id": ME}])

    def test_the_first_file_is_kept_and_only_a_few_newer_backups(self):
        self.write(self.layout(right=[{"id": "omarchy.audio"}, {"id": ME}]))
        original = open(self.path).read()
        run("setup", self.path)
        for _ in range(4):
            run("unswap", self.path)
            data = self.read(); data["bar"]["layout"]["right"].append({"id": ME}); self.write(data)
            run("setup", "--force", self.path)
        self.assertEqual(open(self.path + ".omavolume-original").read(), original)
        self.assertLessEqual(len(glob.glob(self.path + ".omavolume-2*")), 3)

    def test_comments_in_shell_json_give_a_clear_message_and_change_nothing(self):
        with open(self.path, "w") as f:
            f.write('{ // comment\n "bar": {} }')
        out = run("setup", self.path)
        self.assertNotEqual(out.returncode, 0)
        self.assertIn("comments", out.stderr)
        self.assertFalse(os.path.exists(self.marker))

    def test_non_ascii_is_kept(self):
        config = self.layout(right=[{"id": "omarchy.audio"}, {"id": ME}])
        config["note"] = "مرحبا"
        self.write(config)
        run("setup", self.path)
        self.assertIn("مرحبا", open(self.path, encoding="utf-8").read())


class Bluetooth(unittest.TestCase):
    """`omavolume bluetooth on|off|status`: optional, and never touches the real WirePlumber config."""

    def setUp(self):
        self.home = tempfile.mkdtemp()
        self.file = os.path.join(self.home, ".config", "wireplumber", "wireplumber.conf.d", "51-bluez-software-volume.conf")

    def tool(self, *args):
        env = dict(os.environ, HOME=self.home, XDG_RUNTIME_DIR=tempfile.gettempdir())
        return subprocess.run([sys.executable, "-I", SCRIPT, "bluetooth", *args], capture_output=True, text=True, env=env)

    def test_off_by_default(self):
        self.assertEqual(self.tool("status").stdout.strip(), "off")
        self.assertFalse(os.path.exists(self.file))

    def test_on_writes_the_setting_and_says_how_to_apply_it(self):
        out = self.tool("on")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("bluez5.enable-hw-volume = false", open(self.file).read())
        self.assertIn("restart wireplumber", out.stdout)
        self.assertEqual(self.tool("status").stdout.strip(), "on")

    def test_on_twice_changes_nothing(self):
        self.tool("on")
        before = open(self.file).read()
        self.assertIn("already on", self.tool("on").stdout)
        self.assertEqual(open(self.file).read(), before)

    def test_a_different_file_is_kept_as_a_backup(self):
        os.makedirs(os.path.dirname(self.file))
        with open(self.file, "w") as f:
            f.write("# mine\n")
        self.tool("on")
        backups = glob.glob(self.file + ".bak-*")
        self.assertEqual(len(backups), 1)
        self.assertEqual(open(backups[0]).read(), "# mine\n")

    def test_off_removes_only_its_own_file(self):
        self.tool("on")
        self.assertEqual(self.tool("off").returncode, 0)
        self.assertFalse(os.path.exists(self.file))
        self.assertIn("already off", self.tool("off").stdout)
        os.makedirs(os.path.dirname(self.file), exist_ok=True)
        with open(self.file, "w") as f:
            f.write("# somebody else's file\n")
        out = self.tool("off")
        self.assertNotEqual(out.returncode, 0)
        self.assertTrue(os.path.exists(self.file))

    def test_a_bad_action_is_refused(self):
        self.assertNotEqual(self.tool("sideways").returncode, 0)


class MarkerLocation(unittest.TestCase):
    def test_the_real_shell_json_keeps_its_marker_in_the_state_folder(self):
        loader = importlib.machinery.SourceFileLoader("omavolume_tool", SCRIPT)
        spec = importlib.util.spec_from_loader("omavolume_tool", loader)
        mod = importlib.util.module_from_spec(spec)
        loader.exec_module(mod)
        os.environ["XDG_STATE_HOME"] = "/tmp/xdg-state-test"
        try:
            self.assertEqual(mod.marker_for(mod.DEFAULT), "/tmp/xdg-state-test/omavolume/setup-done")
        finally:
            del os.environ["XDG_STATE_HOME"]


class Assets(unittest.TestCase):
    def test_manifest_has_the_service_and_the_widget(self):
        m = json.load(open(os.path.join(ROOT, "manifest.json")))
        self.assertEqual(sorted(m["kinds"]), ["bar-widget", "service"])
        self.assertEqual(m["entryPoints"], {"service": "Service.qml", "barWidget": "Panel.qml"})
        for f in ("Service.qml", "Panel.qml", "omavolume"):
            self.assertTrue(os.path.exists(os.path.join(ROOT, f)), f)

    def test_helper_version_in_the_manifest_matches_the_readme(self):
        m = json.load(open(os.path.join(ROOT, "manifest.json")))
        self.assertIn("## What's new in " + m["version"], open(os.path.join(ROOT, "README.md")).read())


if __name__ == "__main__":
    unittest.main()
