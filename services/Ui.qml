pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What is open. Every surface reads this and nothing else decides whether it
// is showing, so two panels can never fight over the screen.
Singleton {
    id: root

    // --- the phone: one device that is the launcher, the control centre, the
    // settings and the wallpaper picker, turning on its side for the last two.
    property string phone: ""              // "" | control | launcher | settings | wallpapers | sound | wifi | bluetooth
    property string settingsPage: ""       // "" (home) | quick | general | bar | desktop | canvas | about
    property bool powerRail: false
    property string query: ""
    readonly property bool phoneOpen: root.phone !== ""
    readonly property bool landscape: root.phone === "settings" || root.phone === "wallpapers" || root.phone === "sound"

    function openPhone(which) {
        root.closePopup();
        root.deskMenuOpen = false;
        root.powerRail = false;
        if (which === "launcher") root.query = "";
        if (root.phone === "") Sfx.play("open", 1);
        root.phone = which;
    }
    function togglePhone(which) {
        if (root.phone === which) root.closePhone();
        else root.openPhone(which);
    }
    function closePhone() {
        if (root.phone !== "") Sfx.play("close", 1);
        root.phone = "";
        root.powerRail = false;
        root.settingsPage = "";
    }
    function openSettings(page) {
        root.openPhone("settings");
        root.settingsPage = page || "";
    }

    // --- bar popups: battery, weather, calendar, media
    property string popup: ""
    property real popupX: 0                // centre of the pill that opened it, in screen px
    property var popupScreen: null
    function togglePopup(name, x, screen) {
        if (root.popup === name) { root.closePopup(); return; }
        root.closePhone();
        root.deskMenuOpen = false;
        root.popupX = x;
        root.popupScreen = screen;
        root.popup = name;
        Sfx.play("pop", 1.1);
    }
    function closePopup() { root.popup = ""; }

    // --- the desktop's right-click menu
    property bool deskMenuOpen: false
    property real deskMenuX: 0
    property real deskMenuY: 0
    property bool deskCatch: false         // the desktop takes the pointer for a moment
    function catchDesk() {
        root.deskCatch = true;
        catchEnd.restart();
    }
    function openDeskMenu(x, y) {
        root.closePhone();
        root.closePopup();
        root.deskMenuX = x;
        root.deskMenuY = y;
        root.deskMenuOpen = true;
        root.deskCatch = false;
    }
    Timer {
        id: catchEnd
        interval: 700
        onTriggered: root.deskCatch = false
    }

    // --- whole-screen modes
    property bool editing: false
    property string editTab: "widgets"     // widgets | bar | theme | presets
    property bool lockPreview: false

    function closeAll() {
        root.closePhone();
        root.closePopup();
        root.deskMenuOpen = false;
    }

    // --- the on-screen display
    property string osd: ""                // volume | mic | brightness
    property int osdTick: 0
    function showOsd(kind) {
        root.osd = kind;
        root.osdTick++;
    }

    signal lockRequested()
    signal unlocked()
    signal screenshotRequested(string kind)

    IpcHandler {
        target: "tetoos"

        function launcher(): void { root.togglePhone("launcher"); }
        function control(): void { root.togglePhone("control"); }
        function settings(): void { root.togglePhone("settings"); }
        function settingsPage(page: string): void { root.openSettings(page); }
        function wallpapers(): void { root.togglePhone("wallpapers"); }
        function sound(): void { root.togglePhone("sound"); }
        function wifi(): void { root.togglePhone("wifi"); }
        function bluetooth(): void { root.togglePhone("bluetooth"); }
        function clipboard(): void { root.openPhone("launcher"); root.query = "clip "; }
        function power(): void { root.openPhone("control"); root.powerRail = true; }
        function close(): void { root.closeAll(); }
        function edit(): void { root.closeAll(); root.editing = !root.editing; }
        function editTab(name: string): void { root.closeAll(); root.editing = true; root.editTab = name; }
        function lock(): void { root.lockRequested(); }
        function previewLock(): void { root.closeAll(); root.lockPreview = !root.lockPreview; }
        function deskMenuHere(): void { root.catchDesk(); }
        function deskMenuAt(x: int, y: int): void { root.openDeskMenu(x, y); }
        function popup(name: string): void { root.togglePopup(name, -1, null); }
        function setWallpaper(path: string): void { Wallpaper.set(path); }
        function nextWallpaper(): void { Wallpaper.next(1); }
        function preset(name: string): void { Wallpaper.usePreset(name); }
        function mode(name: string): void { Config.options.mode = name; }
        function toggleMode(): void { Config.options.mode = Config.options.mode === "dark" ? "light" : "dark"; }
        function volumeUp(): void { Audio.step(0.05); }
        function volumeDown(): void { Audio.step(-0.05); }
        function mute(): void { Audio.toggleMute(); }
        function micMute(): void { Audio.toggleMicMute(); }
        function brightnessUp(): void { Brightness.step(0.05); root.showOsd("brightness"); }
        function brightnessDown(): void { Brightness.step(-0.05); root.showOsd("brightness"); }
        function workspace(n: int): void { Compositor.go(n); }
        function tetoSay(text: string): void { Teto.say(text); }
        function tetoSing(): void { Teto.singSong(); }
        function tetoDance(): void { Teto.dance(); }
        function tetoEat(): void { Teto.eatBread(); }
        function tetoMenu(): void { Teto.toggleMenu(); }
        function tetoMood(mood: string): void { Teto.setMood(mood, 6000); }
        function tetoToggle(): void { Config.toggle("teto"); }
        function widget(name: string, on: bool): void { Config.setWidget(name, { on: on }); }
        function record(): void { Rec.toggle(); }
        function karaoke(): void { Config.toggle("tetoKaraoke"); }
        function tetoFling(vx: real, vy: real): void { Teto.fling(vx, vy); }
        function bread(): void { Bread.open(); root.togglePopup("bread", -1, null); }
    }
}
