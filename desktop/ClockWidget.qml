import QtQuick
import "root:/theme"
import "root:/ui"
import "root:/services"

// The big bubbly clock: fat ink outline, a paper-to-accent fill, and a tag
// with AM/PM (or the weekday, on a 24-hour clock).
Item {
    id: root

    property real scale_: 1
    implicitWidth: digits.implicitWidth + 8
    implicitHeight: digits.implicitHeight + 16

    StrokeText {
        id: digits
        text: Sys.hours() + ":" + Sys.minutes()
        size: 118 * root.scale_
        weight: 700
        stroke: 6
        drop: 7
        spacing: 2
        fillTop: Theme.dark ? "white" : Theme.paper
        fillBottom: Theme.dark ? Theme.primaryStrong : Theme.primary
    }

    Tag {
        anchors.right: digits.right
        anchors.rightMargin: -6
        anchors.bottom: digits.bottom
        anchors.bottomMargin: -4
        text: Config.ready && Config.options.clock24 ? Qt.formatDate(Sys.now, "ddd").toUpperCase() : Sys.ampm()
        fill: Theme.secondary
        size: 13
    }
}
