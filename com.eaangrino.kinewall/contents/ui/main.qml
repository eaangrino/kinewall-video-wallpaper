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

    readonly property bool audioEnabled: {
        const value = root.configuration.AudioEnabled;

        if (value === undefined || value === null) {
            return false;
        }

        return Boolean(value);
    }

    readonly property bool pauseOnMaximized: {
        const value = root.configuration.PauseOnMaximized;

        if (value === undefined || value === null) {
            return true;
        }

        return Boolean(value);
    }

    readonly property bool debugEnabled: {
        const value = root.configuration.DebugEnabled;

        if (value === undefined || value === null) {
            return false;
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
    property bool componentReady: false
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

    function debugLog(message) {
        if (root.debugEnabled) {
            console.log("[KineWall] " + message);
        }
    }

    function debugError(message) {
        if (root.debugEnabled) {
            console.error("[KineWall] " + message);
        }
    }

    function playbackStateName(state) {
        switch (state) {
        case MediaPlayer.PlayingState:
            return "PlayingState";
        case MediaPlayer.PausedState:
            return "PausedState";
        case MediaPlayer.StoppedState:
            return "StoppedState";
        default:
            return "Unknown(" + state + ")";
        }
    }

    function mediaStatusName(status) {
        switch (status) {
        case MediaPlayer.NoMedia:
            return "NoMedia";
        case MediaPlayer.LoadingMedia:
            return "LoadingMedia";
        case MediaPlayer.LoadedMedia:
            return "LoadedMedia";
        case MediaPlayer.StalledMedia:
            return "StalledMedia";
        case MediaPlayer.BufferingMedia:
            return "BufferingMedia";
        case MediaPlayer.BufferedMedia:
            return "BufferedMedia";
        case MediaPlayer.EndOfMedia:
            return "EndOfMedia";
        case MediaPlayer.InvalidMedia:
            return "InvalidMedia";
        default:
            return "Unknown(" + status + ")";
        }
    }

    function mediaErrorName(error) {
        switch (error) {
        case MediaPlayer.NoError:
            return "NoError";
        case MediaPlayer.ResourceError:
            return "ResourceError";
        case MediaPlayer.FormatError:
            return "FormatError";
        case MediaPlayer.NetworkError:
            return "NetworkError";
        case MediaPlayer.AccessDeniedError:
            return "AccessDeniedError";
        default:
            return "Unknown(" + error + ")";
        }
    }

    function logRuntimeSnapshot(context) {
        root.debugLog(
            "snapshot context=" + context
            + " app=" + Qt.application.name
            + " screenLocker=" + root.isScreenLocker
            + " screenGeometry=" + root.wallpaperScreenGeometry.x + "," + root.wallpaperScreenGeometry.y + "," + root.wallpaperScreenGeometry.width + "x" + root.wallpaperScreenGeometry.height
            + " source=" + player.source.toString()
            + " playbackState=" + root.playbackStateName(player.playbackState)
            + " mediaStatus=" + root.mediaStatusName(player.mediaStatus)
            + " positionMs=" + player.position
            + " durationMs=" + player.duration
            + " audioEnabled=" + root.audioEnabled
            + " activeAudioTrack=" + player.activeAudioTrack
            + " pauseOnMaximized=" + root.pauseOnMaximized
            + " hasMaximizedWindow=" + root.hasMaximizedWindow
            + " screenPoweredOff=" + root.screenPoweredOff
        );
    }

    function syncPlayback(trigger) {
        const syncTrigger = trigger || "unspecified";
        if (player.source.toString().length === 0) {
            if (player.playbackState !== MediaPlayer.StoppedState) {
                root.debugLog("playback action=stop reason=no-source trigger=" + syncTrigger);
                player.stop();
            }
            return;
        }

        if (root.shouldPauseForMaximizedWindow || root.shouldPauseForScreenPower) {
            // pause() preserves the current video position.
            if (player.playbackState === MediaPlayer.PlayingState) {
                const pauseReason = root.shouldPauseForScreenPower ? "screen-powered-off" : "maximized-window";
                root.debugLog("playback action=pause reason=" + pauseReason + " trigger=" + syncTrigger + " positionMs=" + player.position);
                player.pause();
            }
            return;
        }

        // Only play when the media is ready.
        if ((player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.BufferingMedia) && player.playbackState !== MediaPlayer.PlayingState) {
            root.debugLog("playback action=play trigger=" + syncTrigger + " positionMs=" + player.position);
            player.play();
        }
    }

    onAudioEnabledChanged: root.debugLog("configuration audioEnabled=" + root.audioEnabled)
    onPauseOnMaximizedChanged: root.debugLog("configuration pauseOnMaximized=" + root.pauseOnMaximized)
    onConfiguredFillModeChanged: root.debugLog("configuration fillMode=" + root.configuredFillMode)
    onVideoUrlChanged: root.debugLog("configuration videoUrl=" + root.videoUrl.toString())
    onWallpaperScreenGeometryChanged: root.debugLog("screen geometry=" + root.wallpaperScreenGeometry.x + "," + root.wallpaperScreenGeometry.y + "," + root.wallpaperScreenGeometry.width + "x" + root.wallpaperScreenGeometry.height)
    onDebugEnabledChanged: {
        if (root.debugEnabled) {
            root.debugLog("debug logging enabled");

            if (root.componentReady) {
                root.logRuntimeSnapshot("debug-enabled");
            }
        }
    }
    onShouldPauseForMaximizedWindowChanged: {
        root.debugLog("pause condition=maximized-window active=" + root.shouldPauseForMaximizedWindow + " matchingWindows=" + maximizedTasks.count);
        root.syncPlayback("maximized-window-condition");
    }
    onShouldPauseForScreenPowerChanged: {
        root.debugLog("pause condition=screen-power active=" + root.shouldPauseForScreenPower + " missedProbes=" + root.missedScreenProbeCount);
        root.syncPlayback("screen-power-condition");
    }

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

    AudioOutput {
        id: wallpaperAudioOutput
        muted: !root.audioEnabled
    }

    MediaPlayer {
        id: player

        source: root.videoUrl
        videoOutput: wallpaperVideoOutput
        audioOutput: root.audioEnabled ? wallpaperAudioOutput : null

        // Keep the audio track fully disabled unless the user explicitly enables it.
        activeAudioTrack: root.audioEnabled ? 0 : -1
        activeSubtitleTrack: -1

        loops: MediaPlayer.Infinite

        onSourceChanged: {
            root.debugLog("media source=" + source.toString());

            if (source.toString().length === 0) {
                root.debugLog("playback action=stop reason=source-cleared");
                stop();
            }
        }

        onMediaStatusChanged: {
            root.debugLog("media status=" + root.mediaStatusName(mediaStatus) + " positionMs=" + position + " durationMs=" + duration);
            root.syncPlayback("media-status");
        }

        onPlaybackStateChanged: root.debugLog("playback state=" + root.playbackStateName(playbackState) + " positionMs=" + position)

        onErrorOccurred: (error, errorString) => {
            root.debugError(
                "media error=" + root.mediaErrorName(error)
                + " code=" + error
                + " message=" + errorString
                + " status=" + root.mediaStatusName(mediaStatus)
                + " state=" + root.playbackStateName(playbackState)
                + " positionMs=" + position
                + " source=" + source.toString()
            );
        }
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

    Component.onCompleted: {
        root.componentReady = true;
        root.debugLog("component completed");
        root.logRuntimeSnapshot("component-completed");
        root.syncPlayback("component-completed");
    }
}
