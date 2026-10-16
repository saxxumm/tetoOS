pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

// Networking, flattened to the handful of facts the bar and the control centre
// actually show: are we on, over what, called what, and how strong.
Singleton {
    id: root

    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wifiDevice: root.devices.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wiredDevice: root.devices.find(d => d.type === DeviceType.Wired) || null

    readonly property bool wifiEnabled: Demo.on || Networking.wifiEnabled
    readonly property bool wiredUp: !Demo.on && root.wiredDevice !== null && root.wiredDevice.connected
    readonly property bool wifiUp: Demo.on || (root.wifiDevice !== null && root.wifiDevice.connected)

    readonly property var activeWifi: {
        if (!root.wifiDevice || !root.wifiDevice.networks) return null;
        for (const n of root.wifiDevice.networks.values) if (n.connected) return n;
        return null;
    }

    readonly property string ssid: Demo.on ? Demo.wifi[0].name : root.activeWifi ? root.activeWifi.name : ""
    readonly property real strength: Demo.on ? 0.92 : root.activeWifi ? (root.activeWifi.signalStrength > 1 ? root.activeWifi.signalStrength / 100 : root.activeWifi.signalStrength) : 0
    readonly property bool online: Networking.connectivity === NetworkConnectivity.Full
    readonly property bool limited: Networking.connectivity === NetworkConnectivity.Portal
        || Networking.connectivity === NetworkConnectivity.Limited

    // Visible access points, strongest first and one row per name — NetworkManager
    // reports a separate network per band and per access point, and a list that
    // shows the same café's wifi five times is a list nobody reads.
    readonly property var visibleWifi: Demo.on ? Demo.wifi : root.realWifi
    readonly property var realWifi: {
        if (!root.wifiDevice || !root.wifiDevice.networks) return [];
        const best = {};
        for (const n of root.wifiDevice.networks.values) {
            if (!n.name) continue;
            if (!best[n.name] || n.signalStrength > best[n.name].signalStrength) best[n.name] = n;
        }
        return Object.values(best).sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
    }

    // Four bars, as a Nerd Font glyph.
    readonly property string icon: {
        if (root.wiredUp) return "󰈀";
        if (!root.wifiEnabled) return "󰤭";
        if (!root.wifiUp) return "󰤯";
        const s = root.strength;
        if (s > 0.75) return "󰤨";
        if (s > 0.5) return "󰤥";
        if (s > 0.25) return "󰤢";
        return "󰤟";
    }

    // The same, as a Material Symbols name.
    readonly property string symbol: {
        if (root.wiredUp) return "lan";
        if (!root.wifiEnabled) return "wifi_off";
        if (!root.wifiUp) return "wifi_find";
        const s = root.strength;
        if (s > 0.66) return "wifi";
        if (s > 0.33) return "wifi_2_bar";
        return "wifi_1_bar";
    }

    readonly property string label: {
        if (root.wiredUp) return "wired";
        if (!root.wifiEnabled) return "wifi off";
        if (root.ssid !== "") return root.ssid;
        return "offline";
    }

    function toggleWifi() { Networking.wifiEnabled = !Networking.wifiEnabled; }
    function rescan() { if (root.wifiDevice) root.wifiDevice.scannerEnabled = true; }
}
