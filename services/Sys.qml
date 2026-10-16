pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Who and where: the user card's facts, and the clock everything reads.
Singleton {
    id: root

    readonly property string user: Demo.on ? Demo.user : (Quickshell.env("USER") || "user")
    property string host: ""
    property string realName: ""
    readonly property string name: Demo.on ? Demo.name : Config.ready && Config.options.displayName !== "" ? Config.options.displayName
        : (root.realName !== "" ? root.realName : root.user)
    readonly property string shell: (Quickshell.env("SHELL") || "/bin/sh").split("/").pop()
    readonly property string desktop: Compositor.name
    property real uptimeSeconds: 0

    readonly property string uptime: {
        const s = root.uptimeSeconds;
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? d + "d " + h + "h" : h + "h " + m + "m";
    }

    SystemClock {
        id: clock
        precision: Config.ready && Config.options.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
    readonly property date now: clock.date

    readonly property real dayProgress: (root.now.getHours() * 60 + root.now.getMinutes()) / 1440

    readonly property string greeting: {
        const h = root.now.getHours();
        if (h < 5) return "Good night";
        if (h < 12) return "Good morning";
        if (h < 18) return "Good afternoon";
        return "Good evening";
    }

    function time(d) {
        const t = d || root.now;
        if (Config.ready && Config.options.clock24) return Qt.formatTime(t, "hh:mm");
        return Qt.formatTime(t, "hh:mm AP").replace(/^0/, "0");
    }
    function hours(d) {
        const t = d || root.now;
        const h = t.getHours();
        const shown = Config.ready && Config.options.clock24 ? h : (h % 12 === 0 ? 12 : h % 12);
        return String(shown).padStart(2, "0");
    }
    function minutes(d) { return String((d || root.now).getMinutes()).padStart(2, "0"); }
    function ampm(d) { return (d || root.now).getHours() < 12 ? "AM" : "PM"; }

    FileView {
        path: "/proc/sys/kernel/hostname"
        preload: true
        onLoaded: root.host = Demo.on ? Demo.host : text().trim()
    }

    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: root.realName = text.trim() }
    }

    FileView {
        id: up
        path: "/proc/uptime"
        onLoaded: root.uptimeSeconds = Number(text().split(" ")[0])
    }
    Timer {
        running: true
        repeat: true
        interval: 60000
        triggeredOnStart: true
        onTriggered: up.reload()
    }
}
