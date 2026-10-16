pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Everything the shell knows about the compositor, whichever one it is.
//
// sxmwm: `sxmwm msg subscribe` pushes a whole state snapshot on every change —
// the canvas being viewed, the window inventory, the keyboard layout, the
// zoom — and the same binary acts on a click.
//
// Hyprland: Quickshell's own Hyprland module, which keeps workspaces and
// windows current from the event socket. Commands go out as Lua dispatchers on
// Hyprland 0.55+ (hyprland.lua) and as the old dispatcher strings before it.
//
// The rest of the shell reads the properties below and never asks which.
Singleton {
    id: root

    readonly property string backend: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "hyprland" : "sxmwm"
    readonly property bool hypr: root.backend === "hyprland"
    readonly property string name: root.hypr ? "Hyprland" : "sxmwm"
    // sxmwm can pull the camera back over the whole canvas; Hyprland has no overview
    readonly property bool hasOverview: !root.hypr

    // --- state ---------------------------------------------------------------------
    property int sxWorkspace: 1
    property int sxWorkspaceCount: 4
    property var sxWindows: []
    property var sxFullscreen: []
    property var outputs: []
    property string sxLayout: "us"
    property string hyLayout: "us"
    property real zoom: 1
    property bool connected: false

    readonly property int workspace: root.hypr
        ? (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
        : root.sxWorkspace
    readonly property int workspaceCount: {
        if (!root.hypr) return root.sxWorkspaceCount;
        let top = 5;
        for (const w of Hyprland.workspaces.values) if (w.id > top && w.id < 100) top = w.id;
        return Math.min(10, top);
    }
    readonly property string layout: root.hypr ? root.hyLayout : root.sxLayout

    // One shape for both: { id, app_id, title, is_focused, workspace }
    readonly property var windows: root.hypr ? root.hyWindows : root.sxWindows
    readonly property var hyWindows: {
        if (!root.hypr) return [];
        const list = [];
        for (const t of Hyprland.toplevels.values) {
            const ipc = t.lastIpcObject || {};
            list.push({
                id: t.address,
                app_id: (t.wayland && t.wayland.appId) || ipc["class"] || "",
                title: t.title || ipc.title || "",
                is_focused: t.activated,
                workspace: t.workspace ? t.workspace.id : 0
            });
        }
        return list;
    }
    readonly property var fullscreen: root.hypr
        ? (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.hasFullscreen ? [Hyprland.focusedWorkspace.id] : [])
        : root.sxFullscreen

    readonly property var focused: {
        for (const w of root.windows) if (w.is_focused) return w;
        return null;
    }
    readonly property string focusedTitle: root.focused ? (root.focused.title || "") : ""
    readonly property string focusedApp: root.focused ? (root.focused.app_id || "") : ""

    readonly property var numbers: {
        const list = [];
        for (let i = 1; i <= root.workspaceCount; i++) list.push(i);
        return list;
    }

    // Windows on the canvas being viewed (sxmwm), or every window (Hyprland,
    // where clicking one in the dock takes you to its workspace). `is_widget`
    // entries are sxmwm layer surfaces — this shell's own panels.
    readonly property var canvasWindows: root.windows.filter(w => !w.is_widget)

    // --- acting ------------------------------------------------------------------------
    function addr(id) {
        const s = String(id);
        return s.startsWith("0x") ? s : "0x" + s;
    }
    function hyprDispatch(lua, legacy) {
        Hyprland.dispatch(Hyprland.usingLua ? lua : legacy);
    }

    function go(n) {
        if (n === root.workspace) return;
        if (root.hypr) root.hyprDispatch('hl.dsp.focus({ workspace = "' + n + '" })', "workspace " + n);
        else call(["sxmwm", "msg", "workspace", String(n)]);
    }

    function moveTo(n) {
        if (root.hypr) root.hyprDispatch('hl.dsp.window.move({ workspace = "' + n + '" })', "movetoworkspace " + n);
        else call(["sxmwm", "msg", "action", "move-to-workspace", String(n)]);
    }

    function focusWindow(id) {
        if (root.hypr) root.hyprDispatch('hl.dsp.focus({ window = "address:' + root.addr(id) + '" })', "focuswindow address:" + root.addr(id));
        else call(["sxmwm", "msg", "focus", "--id", String(id)]);
    }

    function closeWindow(id) {
        if (root.hypr) root.hyprDispatch('hl.dsp.window.close({ window = "address:' + root.addr(id) + '" })', "closewindow address:" + root.addr(id));
        else call(["sxmwm", "msg", "close", "--id", String(id)]);
    }

    // sxmwm's named actions; on Hyprland the ones with a meaning there.
    function action(name) {
        if (!root.hypr) { call(["sxmwm", "msg", "action", name]); return; }
        if (name === "fit-window")
            root.hyprDispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })', "fullscreen 1");
    }

    function nextLayout() {
        if (root.hypr) Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
        else call(["sxmwm", "msg", "layout", "next"]);
    }

    function call(argv) {
        actor.command = argv;
        actor.running = true;
    }

    Process {
        id: actor
    }

    // --- sxmwm -------------------------------------------------------------------------
    Process {
        id: feed
        command: ["sxmwm", "msg", "--json", "subscribe"]
        running: !root.hypr
        stdout: SplitParser {
            onRead: line => {
                if (!line) return;
                try {
                    const state = JSON.parse(line).State;
                    if (!state) return;
                    root.connected = true;
                    if (state.workspace) root.sxWorkspace = state.workspace;
                    if (state.workspace_count) root.sxWorkspaceCount = state.workspace_count;
                    if (state.windows) root.sxWindows = state.windows;
                    if (state.fullscreen) root.sxFullscreen = state.fullscreen;
                    if (state.outputs) root.outputs = state.outputs;
                    if (state.layout_short) root.sxLayout = state.layout_short;
                    if (state.zoom) root.zoom = state.zoom;
                } catch (e) {
                    // A truncated line on shutdown is not worth a log line.
                }
            }
        }
        onExited: {
            root.connected = false;
            if (!root.hypr) retry.start();
        }
    }

    // Unhurried: the compositor going away usually means the shell is going
    // away with it.
    Timer {
        id: retry
        interval: 2000
        onTriggered: feed.running = true
    }

    // --- Hyprland ----------------------------------------------------------------------
    // Window classes and titles arrive with a refresh, not with the event that
    // announced the window, so ask again whenever the window set changes.
    Connections {
        target: root.hypr ? Hyprland : null
        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2" || n === "windowtitle" || n === "windowtitlev2")
                Hyprland.refreshToplevels();
            if (n === "activelayout") {
                const parts = event.data.split(",");
                const full = parts.slice(1).join(",");
                root.hyLayout = full.slice(0, 2).toLowerCase() || root.hyLayout;
            }
        }
    }
    Component.onCompleted: {
        if (root.hypr) {
            root.connected = true;
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
        }
    }
}
