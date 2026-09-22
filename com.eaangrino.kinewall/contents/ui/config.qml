import QtQuick // qmllint disable import
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQml.Models
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var configDialog
    property var parentLayout

    property string cfg_Video: ""
    property int cfg_PlaybackMode: 0
    property list<string> cfg_Playlist: []
    property int cfg_FillMode: 1
    property color cfg_BackgroundColor: "#000000"
    property bool cfg_AudioEnabled: false
    property int cfg_AudioVolume: 100
    property bool cfg_PauseOnMaximized: true
    property bool cfg_DebugEnabled: false

    property bool componentReady: false
    property bool syncingPlaylistConfig: false

    readonly property var fillModes: [
        { label: "Scaled and Cropped", value: 1 },
        { label: "Scaled", value: 2 },
        { label: "Scaled, keep proportions", value: 0 },
        { label: "Centered", value: 3 }
    ]

    spacing: 0

    function displayPath(value) {
        const text = value.toString();
        return text.startsWith("file://") ? text.substring(7) : text;
    }

    function rebuildPlaylistModel() {
        playlistModel.clear();
        for (let i = 0; i < root.cfg_Playlist.length; ++i) {
            playlistModel.append({ videoSource: root.cfg_Playlist[i].toString() });
        }
    }

    function commitPlaylistModel() {
        const videos = [];
        for (let i = 0; i < playlistModel.count; ++i) {
            videos.push(playlistModel.get(i).videoSource);
        }

        root.syncingPlaylistConfig = true;
        root.cfg_Playlist = videos;
        root.syncingPlaylistConfig = false;
    }

    function playlistContains(source) {
        for (let i = 0; i < playlistModel.count; ++i) {
            if (playlistModel.get(i).videoSource === source) {
                return true;
            }
        }
        return false;
    }

    function indexForValue(model, value) {
        for (let i = 0; i < model.length; ++i) {
            if (model[i].value === value) {
                return i;
            }
        }
        return 0;
    }

    onCfg_PlaylistChanged: {
        if (root.componentReady && !root.syncingPlaylistConfig) {
            root.rebuildPlaylistModel();
        }
    }

    ListModel {
        id: playlistModel
    }

    Kirigami.FormLayout {
        id: settingsForm

        Layout.fillWidth: true
        Layout.bottomMargin: Kirigami.Units.largeSpacing
        twinFormLayouts: root.parentLayout

        Controls.ComboBox {
            id: playbackMode
            Kirigami.FormData.label: "Mode:"
            Layout.fillWidth: true

            model: ["Simple", "Playlist"]
            currentIndex: root.cfg_PlaybackMode
            onActivated: root.cfg_PlaybackMode = currentIndex
        }

        RowLayout {
            Kirigami.FormData.label: "Video:"
            Layout.fillWidth: true
            visible: root.cfg_PlaybackMode === 0

            Controls.TextField {
                Layout.fillWidth: true
                text: root.cfg_Video
                placeholderText: "Select a video file"
                readOnly: true
            }

            Controls.Button {
                text: "Browse…"
                icon.name: "document-open"
                onClicked: simpleVideoDialog.open()
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

            model: root.fillModes
            textRole: "label"
            currentIndex: root.indexForValue(root.fillModes, root.cfg_FillMode)
            onActivated: root.cfg_FillMode = root.fillModes[currentIndex].value
        }

        RowLayout {
            Kirigami.FormData.label: "Solid color:"
            visible: root.cfg_FillMode === 0 || root.cfg_FillMode === 3

            Rectangle {
                width: Kirigami.Units.gridUnit * 2
                height: Kirigami.Units.gridUnit
                radius: 3
                color: root.cfg_BackgroundColor
                border.color: Kirigami.Theme.textColor
                border.width: 1
            }

            Controls.Button {
                text: "Choose…"
                onClicked: {
                    colorDialog.selectedColor = root.cfg_BackgroundColor;
                    colorDialog.open();
                }
            }
        }

        Controls.ComboBox {
            Kirigami.FormData.label: "Audio:"
            Layout.fillWidth: true

            model: ["Disabled", "Enabled"]
            currentIndex: root.cfg_AudioEnabled ? 1 : 0
            onActivated: root.cfg_AudioEnabled = currentIndex === 1
        }

        RowLayout {
            Kirigami.FormData.label: "Volume:"
            Layout.fillWidth: true
            visible: root.cfg_AudioEnabled

            Controls.Slider {
                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: 1
                value: root.cfg_AudioVolume
                onMoved: root.cfg_AudioVolume = Math.round(value)
            }

            Controls.Label {
                text: root.cfg_AudioVolume + "%"
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
            }
        }

        Controls.ComboBox {
            Kirigami.FormData.label: "Pause on maximized windows:"
            Layout.fillWidth: true

            model: ["Disabled", "Enabled"]
            currentIndex: root.cfg_PauseOnMaximized ? 1 : 0
            onActivated: root.cfg_PauseOnMaximized = currentIndex === 1
        }

        Controls.CheckBox {
            Kirigami.FormData.label: "Debug:"
            text: "Enable debug logging"
            checked: root.cfg_DebugEnabled
            onToggled: root.cfg_DebugEnabled = checked
        }

    }

    Item {
        id: simpleBottomSpacer
        Layout.fillHeight: true
        visible: root.cfg_PlaybackMode === 0
    }

    ColumnLayout {
        id: playlistPane

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Kirigami.Units.gridUnit * 10
        Layout.preferredHeight: Kirigami.Units.gridUnit * 18
        visible: root.cfg_PlaybackMode === 1
        spacing: 0

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.InlineViewHeader {
            Layout.fillWidth: true
            text: "Playlist"
            actions: [
                Kirigami.Action {
                    icon.name: "list-add-symbolic"
                    text: "Add videos…"
                    onTriggered: playlistDialog.open()
                }
            ]
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Kirigami.Theme.inherit: false
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            color: Kirigami.Theme.backgroundColor

            ListView {
                id: playlistView
                anchors.fill: parent
                clip: true
                model: playlistModel

                moveDisplaced: Transition {
                    YAnimator {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.InOutQuad
                    }
                }

                delegate: Item {
                    id: playlistDelegate

                    required property int index
                    required property string videoSource

                    width: playlistView.width
                    height: listItem.implicitHeight

                    Controls.ItemDelegate {
                        id: listItem

                        width: parent.width
                        contentItem: RowLayout {
                            Kirigami.ListItemDragHandle {
                                listItem: listItem
                                listView: playlistView
                                incrementalMoves: true
                                onMoveRequested: (oldIndex, newIndex) => {
                                    playlistModel.move(oldIndex, newIndex, 1);
                                }
                                onDropped: root.commitPlaylistModel()
                            }

                            Controls.Label {
                                text: (playlistDelegate.index + 1) + "."
                            }

                            Kirigami.Icon {
                                source: "video-x-generic"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            }

                            Controls.Label {
                                Layout.fillWidth: true
                                text: root.displayPath(playlistDelegate.videoSource)
                                elide: Text.ElideMiddle
                            }

                            Controls.ToolButton {
                                icon.name: "edit-delete-remove-symbolic"
                                text: "Remove video"
                                display: Controls.AbstractButton.IconOnly
                                onClicked: {
                                    playlistModel.remove(playlistDelegate.index, 1);
                                    root.commitPlaylistModel();
                                }
                                Controls.ToolTip.visible: hovered
                                Controls.ToolTip.text: text
                            }
                        }
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - Kirigami.Units.largeSpacing * 4)
                    visible: playlistView.count === 0
                    text: "Add videos to build the playlist"
                }
            }
        }
    }

    FileDialog {
        id: simpleVideoDialog
        title: "Select video"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Videos (*.mp4 *.mkv *.webm *.mov *.avi *.m4v)", "All files (*)"]
        onAccepted: root.cfg_Video = selectedFile.toString()
    }

    FileDialog {
        id: playlistDialog
        title: "Add videos"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Videos (*.mp4 *.mkv *.webm *.mov *.avi *.m4v)", "All files (*)"]
        onAccepted: {
            for (let i = 0; i < selectedFiles.length; ++i) {
                const video = selectedFiles[i].toString();
                if (!root.playlistContains(video)) {
                    playlistModel.append({ videoSource: video });
                }
            }
            root.commitPlaylistModel();
        }
    }

    ColorDialog {
        id: colorDialog
        title: "Select background color"
        onAccepted: root.cfg_BackgroundColor = selectedColor
    }

    Component.onCompleted: {
        root.componentReady = true;
        root.rebuildPlaylistModel();
    }

}
