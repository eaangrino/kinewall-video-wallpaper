// qmllint disable import unresolved-type missing-property

import QtQuick
import QtMultimedia
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

WallpaperItem {
    id: root

    // The WallpaperItem is inserted by Plasma as a child of ContainmentItem.
    // ContainmentItem exposes screenGeometry, which we use to limit window detection
    // to the same monitor where this KineWall instance is running.
    readonly property rect wallpaperScreenGeometry: {
        if (root.parent && root.parent.screenGeometry !== undefined) {
            return root.parent.screenGeometry;
        }

        return Qt.rect(0, 0, 0, 0);
    }

    readonly property bool pauseOnMaximized: {
        const value = root.configuration.PauseOnMaximized;

        if (value === undefined || value === null) {
            return true;
        }

        return Boolean(value);
    }

    // The model is already filtered to contain only windows:
    // - on the current virtual desktop
    // - in the current activity
    // - on the same monitor
    // - not minimized
    // - maximized
    readonly property bool isScreenLocker: Qt.application.name === "kscreenlocker_greet"

    readonly property bool hasMaximizedWindow: !root.isScreenLocker && maximizedTasks.count > 0
    readonly property bool shouldPauseForMaximizedWindow: root.pauseOnMaximized && root.hasMaximizedWindow

    // KScreenLocker-only display power detection. A probe requests a tiny visual
    // update once per second. If two consecutive probes are not presented by the
    // containing QQuickWindow, KWin has stopped presenting this lock-screen surface.
    property bool screenPoweredOff: false
    property bool screenProbePending: false
    property int missedScreenProbeCount: 0
    property bool screenRenderProbeToggle: false
    readonly property bool shouldPauseForScreenPower: root.isScreenLocker && root.screenPoweredOff

    readonly property url videoUrl: {
        const configured = root.configuration.Video;

        if (configured === undefined || configured === null) {
            return "";
        }

        const value = configured.toString().trim();

        if (value.length === 0) {
            return "";
        }

        if (value.startsWith("file:")) {
            return value;
        }

        return "file://" + value;
    }

    readonly property int configuredFillMode: {
        const value = Number(root.configuration.FillMode);
        return Number.isFinite(value) ? value : 1;
    }

    function syncPlayback() {
        if (player.source.toString().length === 0) {
            if (player.playbackState !== MediaPlayer.StoppedState) {
                player.stop();
            }
            return;
        }

        if (root.shouldPauseForMaximizedWindow || root.shouldPauseForScreenPower) {
            // pause() preserves the current video position.
            if (player.playbackState === MediaPlayer.PlayingState) {
                player.pause();
            }
            return;
        }

        // Only play when the media is ready.
        if ((player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.BufferingMedia) && player.playbackState !== MediaPlayer.PlayingState) {
            player.play();
        }
    }

    onShouldPauseForMaximizedWindowChanged: syncPlayback()
    onShouldPauseForScreenPowerChanged: syncPlayback()

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.ActivityInfo {
        id: activityInfo
    }

    Connections {
        target: root.Window.window
        enabled: root.isScreenLocker && target !== null

        function onFrameSwapped() {
            if (!root.screenProbePending) {
                return;
            }

            root.screenProbePending = false;
            root.missedScreenProbeCount = 0;

            if (root.screenPoweredOff) {
                root.screenPoweredOff = false;
            }
        }
    }

    Timer {
        id: screenPowerProbeTimer

        interval: 1000
        repeat: true
        running: root.isScreenLocker && root.Window.window !== null

        onTriggered: {
            if (root.screenProbePending) {
                root.missedScreenProbeCount += 1;

                if (root.missedScreenProbeCount >= 2 && !root.screenPoweredOff) {
                    root.screenPoweredOff = true;
                }
            } else {
                root.missedScreenProbeCount = 0;
            }

            root.screenProbePending = true;
            root.screenRenderProbeToggle = !root.screenRenderProbeToggle;
        }

        onRunningChanged: {
            if (!running) {
                root.screenProbePending = false;
                root.missedScreenProbeCount = 0;
                root.screenPoweredOff = false;
            }
        }
    }

    TaskManager.TasksModel {
        id: maximizedTasks

        groupMode: TaskManager.TasksModel.GroupDisabled

        virtualDesktop: virtualDesktopInfo.currentDesktop
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: true
        filterByActivity: true

        // Plasma only applies this filter when screenGeometry is valid.
        filterByScreen: root.wallpaperScreenGeometry.width > 0
        screenGeometry: root.wallpaperScreenGeometry

        // "filter" means excluding those states:
        // excludes minimized and non-maximized windows.
        filterMinimized: true
        filterNotMaximized: true
        filterHidden: true
    }

    // Toggling this occluded pixel dirties the Qt Quick scene without changing
    // the visible wallpaper, giving the lock screen a lightweight presentation probe.
    Rectangle {
        width: 1
        height: 1
        color: "black"
        visible: root.isScreenLocker && root.screenRenderProbeToggle
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    VideoOutput {
        id: wallpaperVideoOutput
        anchors.fill: parent

        fillMode: {
            switch (root.configuredFillMode) {
            case 0:
                return VideoOutput.PreserveAspectFit;
            case 2:
                return VideoOutput.Stretch;
            default:
                return VideoOutput.PreserveAspectCrop;
            }
        }
    }

    MediaPlayer {
        id: player

        source: root.videoUrl
        videoOutput: wallpaperVideoOutput

        // Audio is disabled, not merely set to zero volume.
        activeAudioTrack: -1
        activeSubtitleTrack: -1

        loops: MediaPlayer.Infinite

        onSourceChanged: {
            if (source.toString().length === 0) {
                stop();
            }
        }

        onMediaStatusChanged: root.syncPlayback()
    }

    Text {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 640)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: "white"
        text: player.errorString
        visible: player.error !== MediaPlayer.NoError && text.length > 0
    }

    Component.onCompleted: root.syncPlayback()
}
