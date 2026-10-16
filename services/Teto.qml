pragma Singleton
import QtQuick
import Quickshell
import "root:/teto/Lines.js" as Lines

// Mini Teto's head: what she is doing and what she says. MiniTeto.qml draws
// her and handles the pointer; everything she reacts to arrives here.
//
// She knows only what the shell already knows — the time, the music, the
// battery, the wallpaper, which canvas you are on — and never reads windows.
Singleton {
    id: root

    readonly property bool enabled: Config.ready && Config.options.teto
    readonly property bool hidden: Compositor.fullscreen.length > 0

    // --- what she is doing ------------------------------------------------------
    // idle | dance | sleep | eat | sing | held | fly | dizzy | happy | shock
    property string mood: "idle"
    property bool menuOpen: false
    property double lastTouch: Date.now()

    // --- what she is saying: typed out a letter at a time -----------------------
    property string text: ""
    property int shown: 0
    property bool sticky: false            // karaoke lines stay until the next one
    readonly property bool talking: root.text !== "" && root.shown < root.text.length
    readonly property bool bubble: root.text !== ""

    function say(line, opts) {
        if (!root.enabled || root.hidden) return;
        const o = opts || {};
        root.text = Lines.fill(line, Object.assign({ name: Sys.name }, o.vars || {}));
        root.shown = 0;
        root.sticky = !!o.sticky;
        root.voice = o.voice !== false;
        root.menuOpen = false;
        typer.restart();
        hush.stop();
    }
    function sayFrom(list, vars, opts) { root.say(Lines.pick(list), Object.assign({ vars: vars }, opts || {})); }
    function quiet() { root.text = ""; root.shown = 0; typer.stop(); }

    property bool voice: true
    Timer {
        id: typer
        interval: 38
        repeat: true
        onTriggered: {
            if (root.shown >= root.text.length) {
                typer.stop();
                if (!root.sticky) hush.restart();
                return;
            }
            const ch = root.text.charAt(root.shown);
            root.shown++;
            if (root.voice && /[A-Za-z0-9А-Яа-яЁё]/.test(ch) && root.shown % 2 === 1) Sfx.blip(ch);
        }
    }
    // reading time: a second and a bit, plus a beat per word
    Timer {
        id: hush
        interval: 1600 + root.text.split(" ").length * 380
        onTriggered: if (!root.menuOpen) root.quiet()
    }

    // --- moods that pass ---------------------------------------------------------------
    function setMood(m, ms) {
        root.mood = m;
        if (ms) { moodEnd.interval = ms; moodEnd.restart(); }
    }
    Timer {
        id: moodEnd
        onTriggered: root.settle()
    }
    // back to whatever the world says she should be doing
    function settle() {
        if (root.mood === "held" || root.mood === "fly") return;
        root.mood = Media.playing ? "dance" : (root.drowsy ? "sleep" : "idle");
    }

    // --- the pointer ---------------------------------------------------------------------
    property int pokes: 0
    Timer { id: pokeReset; interval: 2500; onTriggered: root.pokes = 0 }

    function touched() {
        root.lastTouch = Date.now();
        if (root.mood === "sleep") { root.setMood("happy", 1500); root.sayFrom(Lines.wake); return true; }
        return false;
    }

    function poke() {
        if (root.touched()) return;
        root.pokes++;
        pokeReset.restart();
        Sfx.play("pop", 1.0 + root.pokes * 0.08);
        if (root.pokes >= 5) {
            root.setMood("shock", 1800);
            root.sayFrom(Lines.poke);
            root.pokes = 0;
        } else {
            root.setMood("happy", 1200);
            if (root.pokes === 1) root.sayFrom(Lines.click);
        }
    }

    function pet() {
        root.touched();
        root.petting = true;
        petEnd.restart();
        if (!root.bubble || root.text.length > 14) root.sayFrom(Lines.pet);
        Config.options.tetoLove = Config.options.tetoLove + 1;
        root.setMood("happy", 1600);
    }
    property bool petting: false
    Timer { id: petEnd; interval: 1400; onTriggered: root.petting = false }

    function grabbed() {
        root.touched();
        root.menuOpen = false;
        root.mood = "held";
        root.sayFrom(Lines.held);
        Sfx.play("open", 1.2);
    }
    // throw her from a script: `tetoos ipc tetoFling -1800 -1400`
    signal fling(real vx, real vy)

    function thrown() { root.mood = "fly"; Sfx.play("boing", 1); }
    function landed(hard) {
        if (hard) {
            root.setMood("dizzy", 3200);
            root.sayFrom(Lines.thrown);
            Sfx.play("boing", 0.7);
        } else {
            root.setMood("happy", 1200);
            root.sayFrom(Lines.dropped);
        }
    }

    // --- things she does on request ------------------------------------------------------
    function eatBread() {
        root.touched();
        root.setMood("eat", 4200);
        root.sayFrom(Lines.eat);
        crunch.count = 0;
        crunch.restart();
    }
    Timer {
        id: crunch
        property int count: 0
        interval: 900
        repeat: true
        onTriggered: { Sfx.play("crunch", 1); if (++count >= 4) stop(); }
    }

    function singSong() {
        root.touched();
        const song = Lines.pick(Lines.songs);
        root.say(song.words, { voice: false });
        Sfx.sing(song.score);
        root.setMood("sing", 4200);
    }

    function dance() {
        root.touched();
        root.setMood("dance", 6000);
        root.sayFrom(Lines.dance, {}, { voice: false });
    }

    function tip() { root.touched(); root.sayFrom(Lines.tips); }
    function chat() { root.touched(); root.sayFrom(Math.random() < 0.6 ? Lines.bored : Lines.click); }

    // hidden for a while, then back on her own
    property bool snoozed: false
    function snooze(minutes) {
        root.quiet();
        root.menuOpen = false;
        root.snoozed = true;
        wakeUp.interval = minutes * 60000;
        wakeUp.restart();
    }
    Timer { id: wakeUp; onTriggered: { root.snoozed = false; root.sayFrom(Lines.wake); } }

    function toggleMenu() {
        root.touched();
        root.menuOpen = !root.menuOpen;
        if (root.menuOpen) { root.quiet(); Sfx.play("tap", 1); }
    }

    // --- sleep ---------------------------------------------------------------------------
    // Twenty quiet minutes with nothing playing and she nods off; at night sooner.
    property bool drowsy: false
    Timer {
        running: root.enabled
        interval: 30000
        repeat: true
        onTriggered: {
            const h = new Date().getHours();
            const idleMin = (Date.now() - root.lastTouch) / 60000;
            root.drowsy = !Media.playing && idleMin > ((h >= 1 && h < 6) ? 6 : 20);
            if (root.drowsy && root.mood === "idle") { root.mood = "sleep"; root.sayFrom(Lines.sleepy, {}, { voice: false }); }
            if (!root.drowsy && root.mood === "sleep") root.settle();
        }
    }

    // --- idle chatter ----------------------------------------------------------------------
    Timer {
        id: chatter
        running: root.enabled && Config.options.tetoChatter !== "quiet"
        repeat: true
        interval: (Config.options.tetoChatter === "chatty" ? 3 : 9) * 60000 + Math.random() * 120000
        onTriggered: {
            if (root.bubble || root.menuOpen || root.mood === "sleep" || Notifs.doNotDisturb) return;
            if (Math.random() < 0.18) { root.eatBread(); return; }
            if (Math.random() < 0.15 && Bread.ready) { root.say("Батон дня готов! ПКМ по мне → «Батон дня» ✦"); return; }
            root.sayFrom(Math.random() < 0.5 ? Lines.bored : Lines.tips);
        }
    }

    // --- the world ---------------------------------------------------------------------------
    property bool booted: false
    Timer {
        running: root.enabled
        interval: 2500
        onTriggered: {
            root.booted = true;
            const h = new Date().getHours();
            const part = h < 5 ? "night" : h < 12 ? "morning" : h < 18 ? "day" : h < 23 ? "evening" : "night";
            root.sayFrom(Lines.greet[part]);
            root.settle();
        }
    }

    property string lastTrack: ""
    property double lastMusicLine: 0
    Connections {
        target: Media
        function onPlayingChanged() { if (root.mood === "dance" || root.mood === "idle" || root.mood === "sleep") root.settle(); }
        function onTitleChanged() {
            if (!root.booted || !Media.playing || Media.title === "" || Media.title === root.lastTrack) return;
            root.lastTrack = Media.title;
            if (Date.now() - root.lastMusicLine < 120000 || root.bubble) return;
            root.lastMusicLine = Date.now();
            const me = /teto|テト|重音|kasane/i.test(Media.artist + " " + Media.title);
            if (me || Math.random() < 0.45)
                root.sayFrom(me ? Lines.musicTeto : Lines.music, { title: Media.title, artist: Media.artist || "кто-то" });
        }
    }

    // karaoke: the line being sung, in her bubble
    Connections {
        target: Lyrics
        function onLineChanged() {
            if (!root.booted || !Config.options.tetoKaraoke || !Media.playing || root.menuOpen) return;
            if (Lyrics.line === "") { if (root.sticky) root.quiet(); return; }
            root.say("♪ " + Lyrics.line, { voice: false, sticky: true });
        }
    }

    Connections {
        target: Wallpaper
        function onCurrentChanged() {
            if (!root.booted) return;
            root.setMood("happy", 1500);
            root.sayFrom(Lines.wallpaper);
            Sfx.play("jingle", 1);
        }
    }

    property bool warnedLow: false
    Connections {
        target: Power
        function onLowChanged() {
            if (Power.low && !root.warnedLow) {
                root.warnedLow = true;
                root.setMood("shock", 2000);
                root.sayFrom(Lines.batteryLow, { n: Math.round(Power.level * 100) });
            }
            if (!Power.low) root.warnedLow = false;
        }
        function onChargingChanged() { if (root.booted && Power.charging && Power.hasBattery) root.sayFrom(Lines.charging); }
    }

    property int hotTicks: 0
    property double lastHot: 0
    Timer {
        running: root.enabled
        interval: 5000
        repeat: true
        onTriggered: {
            root.hotTicks = Resources.cpu > 0.88 ? root.hotTicks + 1 : 0;
            if (root.hotTicks >= 3 && Date.now() - root.lastHot > 600000) {
                root.lastHot = Date.now();
                root.setMood("shock", 1800);
                root.sayFrom(Lines.cpuHot, { n: Math.round(Resources.cpu * 100) });
            }
        }
    }

    property int seenNotes: 0
    property double lastNoteLine: 0
    Connections {
        target: Notifs
        function onCountChanged() {
            const fresh = Notifs.count > root.seenNotes;
            root.seenNotes = Notifs.count;
            if (!fresh || !root.booted || Notifs.doNotDisturb || root.bubble) return;
            if (Date.now() - root.lastNoteLine < 90000 || Math.random() > 0.5) return;
            root.lastNoteLine = Date.now();
            const n = Notifs.history[0];
            if (n && n.appName && n.appName !== "tetoOS") root.sayFrom(Lines.notif, { app: n.appName });
        }
    }

    Connections {
        target: Compositor
        function onWorkspaceChanged() {
            if (root.booted && !root.bubble && Math.random() < 0.25) root.sayFrom(Lines.workspace, { n: Compositor.workspace });
        }
    }

    Connections {
        target: Ui
        function onUnlocked() { root.setMood("happy", 1600); root.sayFrom(Lines.unlock); }
    }
}
