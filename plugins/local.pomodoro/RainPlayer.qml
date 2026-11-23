import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  required property bool play
  required property int volume
  property bool failed: false

  readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") +
    "/omarchy-pomodoro-" + Qt.md5(Quickshell.env("WAYLAND_DISPLAY")).slice(0, 10) + ".sock"

  function applyVolume() {
    if (!control.connected) return
    control.write(JSON.stringify({command: ["set_property", "volume", volume]}) + "\n")
    control.flush()
  }

  onVolumeChanged: applyVolume()
  onPlayChanged: {
    failed = false
    if (!play) control.connected = false
  }

  Process {
    id: player
    running: root.play
    command: [
      "mpv", "--no-config", "--no-video", "--no-terminal",
      "--audio-client-name=Pomodoro rain", "--loop-file=inf", "--ytdl=no",
      "--input-ipc-server=" + root.socketPath, "--volume=" + root.volume,
      "--", Qt.resolvedUrl("rain.ogg").toString()
    ]
    onExited: exitCode => {
      if (root.play && exitCode !== 0)
        root.failed = true
    }
  }

  Socket {
    id: control
    path: root.socketPath
    onConnectedChanged: if (connected) root.applyVolume()
  }

  Timer {
    interval: 250
    repeat: true
    running: root.play && player.running && !control.connected
    onTriggered: control.connected = true
  }
}
