pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// One player at a time, chosen the way a person would: whatever is actually
// playing, and failing that whatever was playing last. Cycling between them is
// possible but deliberate — the bar should not swap what it is showing because
// a browser tab woke up.
Singleton {
    id: root

    property int preferred: 0

    readonly property var players: Mpris.players ? Mpris.players.values : []

    readonly property var active: {
        if (root.players.length === 0) return null;
        if (root.preferred > 0) {
            const pinned = root.players.find(p => p.uniqueId === root.preferred);
            if (pinned) return pinned;
        }
        const playing = root.players.find(p => p.playbackState === MprisPlaybackState.Playing);
        return playing || root.players[0];
    }

    readonly property bool has: Demo.on || root.active !== null
    readonly property bool playing: Demo.on || root.has && root.active.playbackState === MprisPlaybackState.Playing
    readonly property string title: Demo.on ? Demo.title : root.has ? (root.active.trackTitle || "") : ""
    readonly property string artist: Demo.on ? Demo.artist : root.has ? (root.active.trackArtist || "") : ""
    readonly property string album: Demo.on ? "" : root.has ? (root.active.trackAlbum || "") : ""
    readonly property string art: Demo.on ? "" : root.has ? (root.active.trackArtUrl || "") : ""
    readonly property string identity: Demo.on ? "Music Player" : root.has ? (root.active.identity || "") : ""
    readonly property real length: Demo.on ? Demo.length : root.has && root.active.lengthSupported ? root.active.length : 0
    readonly property real position: Demo.on ? Demo.position : root.has && root.active.positionSupported ? root.active.position : 0
    readonly property real progress: root.length > 0 ? Math.max(0, Math.min(1, root.position / root.length)) : 0

    function toggle() { if (!Demo.on && root.has && root.active.canTogglePlaying) root.active.togglePlaying(); }
    function next() { if (!Demo.on && root.has && root.active.canGoNext) root.active.next(); }
    function previous() { if (!Demo.on && root.has && root.active.canGoPrevious) root.active.previous(); }
    function seek(fraction) {
        if (!Demo.on && root.has && root.active.canSeek && root.length > 0) root.active.position = fraction * root.length;
    }

    function cycle() {
        if (root.players.length < 2) return;
        const index = root.players.findIndex(p => p === root.active);
        root.preferred = root.players[(index + 1) % root.players.length].uniqueId;
    }

    // Shuffle and repeat are optional in the MPRIS spec and plenty of players
    // leave them out, so both are reported as "can this player do it at all"
    // rather than assumed — the menu hides the buttons instead of showing two
    // that do nothing.
    readonly property bool canShuffle: !Demo.on && root.has && root.active.shuffleSupported
    readonly property bool shuffle: root.canShuffle && root.active.shuffle
    function toggleShuffle() { if (root.canShuffle) root.active.shuffle = !root.active.shuffle; }

    readonly property bool canLoop: !Demo.on && root.has && root.active.loopSupported
    readonly property int loop: root.canLoop ? root.active.loopState : MprisLoopState.None
    readonly property bool looping: root.loop !== MprisLoopState.None

    // Off, the whole playlist, then the one track — the order every player's own
    // repeat button walks.
    function cycleLoop() {
        if (!root.canLoop) return;
        if (root.loop === MprisLoopState.None) root.active.loopState = MprisLoopState.Playlist;
        else if (root.loop === MprisLoopState.Playlist) root.active.loopState = MprisLoopState.Track;
        else root.active.loopState = MprisLoopState.None;
    }

    // MPRIS position is a snapshot, not a stream: without asking again the
    // progress bar would sit still through the whole track.
    Timer {
        running: !Demo.on && root.playing && root.has && root.active.positionSupported
        repeat: true
        interval: 1000
        onTriggered: if (root.has) root.active.positionChanged()
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0) return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
