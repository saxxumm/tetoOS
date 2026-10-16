import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "root:/theme"
import "root:/services"

// The lock: ext-session-lock, so while it is up nothing else is on screen
// and the compositor keeps it there even if the shell dies. The password goes
// to PAM's "login" stack — the same one the display manager asks.
//
// `Ui.lockPreview` shows the same face in an ordinary overlay that any key
// dismisses, for looking at it without locking anything.
Scope {
    id: root

    property string entry: ""
    property string status: ""
    property int attempts: 0
    property date since: new Date()

    function lock() {
        if (session.locked) return;
        root.entry = "";
        root.status = "";
        root.since = new Date();
        Ui.closeAll();
        Sfx.play("lock", 1);
        session.locked = true;
    }

    function submit() {
        if (pam.active || root.entry === "") return;
        root.pending = root.entry;
        pam.start();
    }
    property string pending: ""

    Connections {
        target: Ui
        function onLockRequested() { root.lock(); }
    }

    PamContext {
        id: pam
        config: "login"
        onResponseRequiredChanged: {
            if (!responseRequired) return;
            respond(root.pending);
            root.pending = "";
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                session.locked = false;
                Sfx.play("unlock", 1);
                Ui.unlocked();
                root.entry = "";
                root.status = "";
                root.attempts = 0;
            } else {
                root.attempts++;
                Sfx.play("error", 1);
                root.status = "wrong";
                root.entry = "";
            }
        }
    }

    WlSessionLock {
        id: session
        WlSessionLockSurface {
            color: Theme.night
            LockFace {
                id: face
                anchors.fill: parent
                entry: root.entry
                busy: pam.active
                status: root.status
                attempts: root.attempts
                since: root.since
                onTyped: text => { root.entry += text; root.status = ""; }
                onBackspaced: root.entry = root.entry.slice(0, -1)
                onCleared: root.entry = ""
                onSubmitted: root.submit()
                Component.onCompleted: { face.forceActiveFocus(); face.playIntro(); }
            }
        }
    }

    // --- preview ------------------------------------------------------------------
    PanelWindow {
        id: preview
        screen: Quickshell.screens[0]
        visible: Ui.lockPreview
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "tetoos-lock-preview"
        WlrLayershell.keyboardFocus: Ui.lockPreview ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: Theme.night

        property string typed: ""
        onVisibleChanged: if (visible) { preview.typed = ""; previewFace.since = new Date(); previewFace.playIntro(); previewFace.forceActiveFocus(); }

        LockFace {
            id: previewFace
            anchors.fill: parent
            entry: preview.typed
            onTyped: text => preview.typed += text
            onBackspaced: preview.typed = preview.typed.slice(0, -1)
            onCleared: Ui.lockPreview = false
            onSubmitted: Ui.lockPreview = false
        }
    }
}
