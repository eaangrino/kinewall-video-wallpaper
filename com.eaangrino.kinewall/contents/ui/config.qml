import QtQuick // qmllint disable import
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root

    property var configDialog
    property var parentLayout

    property string cfg_Video: ""
    property int cfg_FillMode: 1
    property bool cfg_AudioEnabled: false
    property bool cfg_PauseOnMaximized: true

    twinFormLayouts: parentLayout

    RowLayout {
        Kirigami.FormData.label: "Video:"
        Layout.fillWidth: true

        Controls.TextField {
            id: videoPath
            Layout.fillWidth: true
            text: root.cfg_Video
            placeholderText: "Select a video file"
            readOnly: true
        }

        Controls.Button {
            text: "Browse…"
            icon.name: "document-open"
            onClicked: fileDialog.open()
        }

        Controls.Button {
            text: "Clear"
            enabled: root.cfg_Video.length > 0
            onClicked: root.cfg_Video = ""
        }
    }

    Controls.ComboBox {
        id: fillMode
        Kirigami.FormData.label: "Positioning:"
        Layout.fillWidth: true

        model: ["Fit entire video (no cropping)", "Fill screen (crop edges)", "Stretch"]

        currentIndex: root.cfg_FillMode
        onActivated: root.cfg_FillMode = currentIndex
    }

    Controls.ComboBox {
        id: audioMode
        Kirigami.FormData.label: "Audio:"
        Layout.fillWidth: true

        model: ["Disabled", "Enabled"]

        currentIndex: root.cfg_AudioEnabled ? 1 : 0
        onActivated: root.cfg_AudioEnabled = currentIndex === 1
    }

    Controls.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: 520
        wrapMode: Text.WordWrap
        opacity: 0.75
        text: "Audio is disabled by default. When disabled, KineWall does not activate an audio track."
    }

    Controls.CheckBox {
        Kirigami.FormData.label: "Performance:"
        text: "Pause when a window is maximized"
        checked: root.cfg_PauseOnMaximized
        onToggled: root.cfg_PauseOnMaximized = checked
    }

    Controls.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: 520
        wrapMode: Text.WordWrap
        opacity: 0.75
        text: "When enabled, KineWall pauses the video when it detects a maximized, non-minimized window on this monitor. When no maximized window remains, playback resumes from the same position."
    }


    FileDialog {
        id: fileDialog
        title: "Select video"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Videos (*.mp4 *.mkv *.webm *.mov *.avi *.m4v)", "All files (*)"]

        onAccepted: root.cfg_Video = selectedFile.toString()
    }
}
