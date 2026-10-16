import QtQuick
import Quickshell
import Quickshell.Networking
import "root:/theme"
import "root:/ui"
import "root:/services"

// Wi-Fi or Bluetooth, held upright: the radio switch and what is in range.
// A known network or a paired device connects with a click; a new network
// opens nmtui in a terminal for its password; right-click forgets.
Item {
    id: root

    readonly property bool bt: Ui.phone === "bluetooth"

    Row {
        x: 18; y: 4
        spacing: 8
        Tap { width: 34; height: 34; icon: "arrow_back"; onClicked: Ui.openPhone("control") }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -4
            Label { text: root.bt ? "Bluetooth" : "Wi-Fi"; size: 18; weight: 700 }
            Label { text: root.bt ? Bt.label : Net.label; size: 10; weight: 500; color: Theme.textSoft }
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 22
        y: 8
        spacing: 8
        Tap {
            width: 32; height: 32
            icon: root.bt ? (Bt.discovering ? "bluetooth_searching" : "search") : "refresh"
            active: root.bt && Bt.discovering
            onClicked: root.bt ? Bt.toggleDiscovery() : Net.rescan()
        }
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.bt ? Bt.enabled : Net.wifiEnabled
            onToggled: root.bt ? Bt.toggle() : Net.toggleWifi()
        }
    }

    Scroll {
        id: list
        anchors.top: parent.top
        anchors.topMargin: 56
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        contentHeight: col.height + 10
        Column {
            id: col
            x: 16
            width: list.width - 32
            spacing: 8

            Repeater {
                model: root.bt ? [] : Net.visibleWifi
                Tap {
                    id: ap
                    required property var modelData
                    readonly property real s: modelData.signalStrength > 1 ? modelData.signalStrength / 100 : modelData.signalStrength
                    width: col.width
                    height: 46
                    radius: 16
                    icon: s > 0.66 ? "wifi" : s > 0.33 ? "wifi_2_bar" : "wifi_1_bar"
                    iconSize: 18
                    text: modelData.name
                    sub: modelData.connected ? "connected" : modelData.known ? "saved" : (modelData.security !== WifiSecurityType.Open ? "secured" : "open")
                    maxText: col.width - 90
                    active: modelData.connected
                    fill: active ? Theme.primary : Theme.paper
                    onClicked: {
                        if (modelData.connected) modelData.disconnect();
                        else if (modelData.known) modelData.connect();
                        else { Ui.closePhone(); Quickshell.execDetached(["sh", "-c", "${TERMINAL:-kitty} -e nmtui-connect \"$1\"", "sh", modelData.name]); }
                    }
                    onRightClicked: if (modelData.known) modelData.forget()
                    Icon {
                        visible: ap.modelData.security !== WifiSecurityType.Open
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "lock"
                        size: 14
                        color: Theme.textSoft
                    }
                }
            }

            Repeater {
                model: root.bt && Bt.enabled ? Bt.knownDevices.concat(Bt.discoveredDevices.slice(0, 8)) : []
                Tap {
                    required property var modelData
                    width: col.width
                    height: 46
                    radius: 16
                    icon: (modelData.icon || "").indexOf("audio") >= 0 || (modelData.icon || "").indexOf("headset") >= 0 ? "headphones"
                        : (modelData.icon || "").indexOf("phone") >= 0 ? "smartphone"
                        : (modelData.icon || "").indexOf("input") >= 0 ? "mouse" : "bluetooth"
                    iconSize: 18
                    text: modelData.deviceName || modelData.name || modelData.address
                    sub: modelData.connected ? (modelData.batteryAvailable ? "connected · " + Math.round(modelData.battery * 100) + "%" : "connected")
                        : modelData.pairing ? "pairing…" : (modelData.paired || modelData.bonded) ? "paired" : "new"
                    maxText: col.width - 80
                    active: modelData.connected
                    fill: active ? Theme.primary : Theme.paper
                    onClicked: {
                        if (modelData.connected) modelData.disconnect();
                        else if (modelData.paired || modelData.bonded) modelData.connect();
                        else modelData.pair();
                    }
                    onRightClicked: if (modelData.paired || modelData.bonded) modelData.forget()
                }
            }

            Label {
                visible: root.bt ? (!Bt.enabled || Bt.knownDevices.length + Bt.discoveredDevices.length === 0) : (!Net.wifiEnabled || Net.visibleWifi.length === 0)
                width: col.width
                topPadding: 30
                horizontalAlignment: Text.AlignHCenter
                text: root.bt ? (Bt.enabled ? "Nothing nearby — press search" : "Bluetooth is off") : (Net.wifiEnabled ? "Looking for networks…" : "Wi-Fi is off")
                size: 13
                color: Theme.textSoft
            }
        }
    }
}
