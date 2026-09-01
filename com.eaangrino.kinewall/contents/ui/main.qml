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
            return root.parent.screenGeometry
        }

        return Qt.rect(0, 0, 0, 0)
    }

    readonly property bool pauseOnMaximized: {
        const value = root.configuration.PauseOnMaximized

        if (value === undefined || value === null) {
            return true
        }

        return Boolean(value)
    }

    // The model is already filtered to contain only windows:
    // - on the current virtual desktop
    // - in the current activity
    // - on the same monitor
    // - not minimized
    // - maximized
    readonly property bool hasMaximizedWindow: maximizedTasks.count > 0
    readonly property bool shouldPauseForMaximizedWindow:
        root.pauseOnMaximized && root.hasMaximizedWindow

    readonly property url videoUrl: {
        const configured = root.configuration.Video

        if (configured === undefined || configured === null) {
            return ""
        }

        const value = configured.toString().trim()

        if (value.length === 0) {
            return ""
        }

        if (value.startsWith("file:")) {
            return value
        }

        return "file://" + value
    }

    readonly property int configuredFillMode: {
        const value = Number(root.configuration.FillMode)
        return Number.isFinite(value) ? value : 1
    }

    function syncPlayback() {
        if (player.source.toString().length === 0) {
            if (player.playbackState !== MediaPlayer.StoppedState) {
                player.stop()
            }
            return
        }

        if (root.shouldPauseForMaximizedWindow) {
            // pause() preserves the current video position.
            if (player.playbackState === MediaPlayer.PlayingState) {
                player.pause()
            }
            return
        }

        // Only play when the media is ready.
        if ((player.mediaStatus === MediaPlayer.LoadedMedia
             || player.mediaStatus === MediaPlayer.BufferedMedia
             || player.mediaStatus === MediaPlayer.BufferingMedia)
                && player.playbackState !== MediaPlayer.PlayingState) {
            player.play()
        }
    }

    onShouldPauseForMaximizedWindowChanged: syncPlayback()

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.ActivityInfo {
        id: activityInfo
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

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent

        fillMode: {
            switch (root.configuredFillMode) {
            case 0:
                return VideoOutput.PreserveAspectFit
            case 2:
                return VideoOutput.Stretch
            default:
                return VideoOutput.PreserveAspectCrop
            }
        }
    }

    MediaPlayer {
        id: player

        source: root.videoUrl
        videoOutput: videoOutput

        // Audio is disabled, not merely set to zero volume.
        activeAudioTrack: -1
        activeSubtitleTrack: -1

        loops: MediaPlayer.Infinite

        onSourceChanged: {
            if (source.toString().length === 0) {
                stop()
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
