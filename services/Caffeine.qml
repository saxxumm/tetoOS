pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Keep the screen awake: an idle inhibitor held by systemd for as long as the
// process lives, so it goes away with the shell instead of outliving it.
Singleton {
    id: root

    property bool on: false
    function toggle() { root.on = !root.on; }

    Process {
        running: root.on
        command: ["systemd-inhibit", "--what=idle", "--who=tetoos", "--why=Caffeine", "--mode=block", "sleep", "infinity"]
    }
}
