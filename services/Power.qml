pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery, power profile, and the session actions the power menu offers.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: root.device !== null
        && root.device.isLaptopBattery && root.device.isPresent
    readonly property real level: root.hasBattery ? root.device.percentage : 1
    readonly property bool charging: !UPower.onBattery
    readonly property bool low: root.hasBattery && root.level < 0.15 && !root.charging
    readonly property bool critical: root.hasBattery && root.level < 0.07 && !root.charging

    readonly property string timeLeft: {
        if (!root.hasBattery) return "";
        const s = root.charging ? root.device.timeToFull : root.device.timeToEmpty;
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        return (h > 0 ? h + "h " : "") + m + "m" + (root.charging ? " to full" : " left");
    }

    // A battery glyph that fills in tenths, plus the bolt while charging.
    readonly property string icon: {
        if (!root.hasBattery) return "󰁹";
        if (root.charging) return "󰂄";
        const steps = ["󰂎", "󰁺", "󰁻", "󰁼",
                       "󰁽", "󰁾", "󰁿", "󰂀",
                       "󰂁", "󰂂", "󰁹"];
        return steps[Math.max(0, Math.min(10, Math.round(root.level * 10)))];
    }

    readonly property bool hasProfiles: PowerProfiles.hasPerformanceProfile
    readonly property int profile: PowerProfiles.profile
    function setProfile(p) { PowerProfiles.profile = p; }
    function cycleProfile() {
        const order = [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance];
        const usable = PowerProfiles.hasPerformanceProfile ? order : order.slice(0, 2);
        const at = usable.indexOf(PowerProfiles.profile);
        PowerProfiles.profile = usable[(at + 1) % usable.length];
    }

    // --- session actions ----------------------------------------------------
    // systemctl rather than loginctl for the machine states, because these are
    // the same verbs the rest of the system uses and they respect inhibitors.
    function suspend() { run(["systemctl", "suspend"]); }
    function hibernate() { run(["systemctl", "hibernate"]); }
    function reboot() { run(["systemctl", "reboot"]); }
    function shutdown() { run(["systemctl", "poweroff"]); }

    // Ending the session, not killing the compositor: logind tears down the
    // scope, which stops the shell, the portals and everything else the session
    // started, in that order.
    function logout() {
        const id = Quickshell.env("XDG_SESSION_ID");
        run(id ? ["loginctl", "terminate-session", id] : ["loginctl", "terminate-user", "-i"]);
    }

    function run(argv) {
        runner.command = argv;
        runner.running = true;
    }

    Process { id: runner }
}
