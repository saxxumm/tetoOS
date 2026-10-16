pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth, reduced the same way: on or off, and what is connected.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: Demo.on || root.adapter !== null
    readonly property bool enabled: Demo.on || (root.available && root.adapter.enabled)
    readonly property bool discovering: !Demo.on && root.available && root.adapter.discovering

    readonly property var devices: Demo.on ? Demo.bluetooth : Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var connectedDevices: root.devices.filter(d => d.connected)
    readonly property var knownDevices: root.devices.filter(d => d.paired || d.bonded || d.connected)

    // A device that advertises no name arrives with `deviceName` empty and
    // `name` holding its address in dashed form, so a list that falls back to
    // either shows "77-AD-D4-1D-25-A8" instead of a device. Phones, watches and
    // earbuds nearby rotate random addresses every few minutes, so those rows
    // are unusable and endless — they crowded out the real devices. Keep only
    // what announced a name of its own.
    readonly property var discoveredDevices: root.devices.filter(d => {
        if (d.paired || d.bonded || d.connected) return false;
        const named = (d.deviceName || "").trim();
        if (named.length === 0) return false;
        const dashed = (d.address || "").replace(/:/g, "-").toUpperCase();
        return named.toUpperCase() !== dashed;
    });

    readonly property string label: {
        if (!root.available) return "no adapter";
        if (!root.enabled) return "off";
        if (root.connectedDevices.length === 1) return root.connectedDevices[0].deviceName || root.connectedDevices[0].name;
        if (root.connectedDevices.length > 1) return root.connectedDevices.length + " devices";
        return "on";
    }

    readonly property string icon: !root.enabled ? "󰂯"
        : (root.connectedDevices.length > 0 ? "󰂱" : "󰂯")

    function toggle() {
        if (root.available) root.adapter.enabled = !root.adapter.enabled;
    }

    function toggleDiscovery() {
        if (root.available) root.adapter.discovering = !root.adapter.discovering;
    }
}
