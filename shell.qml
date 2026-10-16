//@ pragma UseQApplication
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
import QtQuick
import Quickshell
import "root:/theme"
import "root:/services"
import "root:/bar"
import "root:/desktop"
import "root:/dock"
import "root:/phone"
import "root:/popups"
import "root:/notifications"
import "root:/osd"
import "root:/lock"
import "root:/edit"
import "root:/teto"

// tetoOS — a sticker-sheet shell for sxmwm.
//
// theme/ holds the colours (read off the wallpaper by scripts/palette.py),
// ui/ the handful of primitives everything is built from, services/ what the
// shell knows, and the other directories what it draws.
ShellRoot {
    Variants {
        model: Quickshell.screens
        Background {}
    }

    Variants {
        model: Quickshell.screens
        Desktop {}
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Variants {
        model: Quickshell.screens
        Dock {}
    }

    Phone {}
    Popups {}
    Toasts {}
    Osd {}
    Lock {}
    EditDesktop {}
    MiniTeto {}

    Item {
        Component.onCompleted: {
            void Ui.phone;
            void Notifs.count;
            void Todo.count;
            void Night.enabled;
            void Wallpaper.current;
            void Teto.mood;
            void Lyrics.line;
            void DesktopEntries.applications;
        }
    }
}
