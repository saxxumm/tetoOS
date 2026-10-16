pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, swap, disk and temperature, read from /proc and /sys.
//
// CPU load has to be a difference between two samples — /proc/stat counts
// jiffies since boot, so a single read tells you the average since the machine
// started and nothing about now.
Singleton {
    id: root

    property real cpu: 0
    property real memory: 0
    property real swap: 0
    property real disk: 0
    property real temperature: 0
    property int memUsedMb: 0
    property int memTotalMb: 0
    property string uptime: ""

    property var lastCpu: null

    FileView {
        id: stat
        path: "/proc/stat"
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
    }

    function sample() {
        stat.reload();
        meminfo.reload();
        uptimeFile.reload();
    }

    function parseCpu(text) {
        const line = text.split("\n")[0];
        if (!line.startsWith("cpu ")) return;
        const f = line.trim().split(/\s+/).slice(1).map(Number);
        // user nice system idle iowait irq softirq steal
        const idle = f[3] + f[4];
        const total = f.reduce((a, b) => a + b, 0);
        if (root.lastCpu) {
            const dt = total - root.lastCpu.total;
            const di = idle - root.lastCpu.idle;
            if (dt > 0) root.cpu = Math.max(0, Math.min(1, 1 - di / dt));
        }
        root.lastCpu = { total: total, idle: idle };
    }

    function parseMem(text) {
        const kv = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m) kv[m[1]] = parseInt(m[2]);
        }
        if (!kv.MemTotal) return;
        const used = kv.MemTotal - (kv.MemAvailable !== undefined ? kv.MemAvailable : kv.MemFree);
        root.memory = used / kv.MemTotal;
        root.memUsedMb = Math.round(used / 1024);
        root.memTotalMb = Math.round(kv.MemTotal / 1024);
        root.swap = kv.SwapTotal > 0 ? (kv.SwapTotal - kv.SwapFree) / kv.SwapTotal : 0;
    }

    function parseUptime(text) {
        const seconds = parseFloat(text.split(/\s+/)[0]);
        if (isNaN(seconds)) return;
        const d = Math.floor(seconds / 86400);
        const h = Math.floor((seconds % 86400) / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        root.uptime = d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m");
    }

    Connections {
        target: stat
        function onLoaded() { root.parseCpu(stat.text()); }
    }

    Connections {
        target: meminfo
        function onLoaded() { root.parseMem(meminfo.text()); }
    }

    Connections {
        target: uptimeFile
        function onLoaded() { root.parseUptime(uptimeFile.text()); }
    }

    Timer {
        running: true
        repeat: true
        interval: 2000
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    // Disk and temperature move slowly enough that a shell-out every half
    // minute is cheaper than keeping a parser for either.
    Process {
        id: diskProbe
        command: ["sh", "-c", "df -P / | awk 'NR==2 {gsub(\"%\",\"\",$5); print $5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                if (!isNaN(v)) root.disk = v / 100;
            }
        }
    }

    Process {
        id: tempProbe
        command: ["sh", "-c",
            "for z in /sys/class/thermal/thermal_zone*; do " +
            "  case \"$(cat $z/type 2>/dev/null)\" in x86_pkg_temp|acpitz|coretemp) cat $z/temp; exit;; esac; " +
            "done; cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                if (!isNaN(v)) root.temperature = v / 1000;
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 30000
        triggeredOnStart: true
        onTriggered: {
            diskProbe.running = true;
            tempProbe.running = true;
        }
    }
}
