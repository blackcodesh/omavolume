import QtQuick
import Quickshell
import Quickshell.Io

// Omarchy starts a plugin's service when the shell starts. First run: OmaVolume takes the place of
// Omarchy's own audio icon on the bar (`omavolume setup`), so there is one audio icon, not two. It
// changes nothing once it has run (a marker in ~/.local/state/omavolume), so it is safe on every start.
QtObject {
  id: service

  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property var shell: null
  property var manifest: ({})
  property string omarchyPath: ""

  property Process setup: Process {
    command: ["python3", "-I", decodeURIComponent(String(Qt.resolvedUrl("omavolume")).replace(/^file:\/\//, "")), "setup"]
    stdout: StdioCollector { onStreamFinished: if (text.trim() !== "already set up") console.info("OmaVolume: " + text.trim()) }
    stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.warn("OmaVolume: " + text.trim()) }
  }

  Component.onCompleted: setup.running = true
}
