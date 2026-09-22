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
        return value === undefined || value === null ? false : Boolean(value);
    }

    readonly property real audioVolume: {
        const value = Number(root.configuration.AudioVolume);
        const percent = Number.isFinite(value) ? Math.max(0, Math.min(100, value)) : 100;
        return percent / 100.0;
    }

    readonly property bool pauseOnMaximized: {
        const value = root.configuration.PauseOnMaximized;
        return value === undefined || value === null ? true : Boolean(value);
    }

    readonly property bool debugEnabled: {
        const value = root.configuration.DebugEnabled;
        return value === undefined || value === null ? false : Boolean(value);
    }

    readonly property int playbackMode: {
        const value = Number(root.configuration.PlaybackMode);
        return Number.isFinite(value) && value >= 0 && value <= 1 ? value : 0;
    }

    readonly property var configuredPlaylist: {
        const value = root.configuration.Playlist;
        return value === undefined || value === null ? [] : value;
    }

    readonly property color backgroundColor: {
        const value = root.configuration.BackgroundColor;
        return value === undefined || value === null ? "#000000" : value;
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

    readonly property url simpleVideoUrl: root.normalizeVideoUrl(root.configuration.Video)
    property url currentVideoUrl: ""
    property var playbackQueue: []
    property int currentVideoIndex: -1
    // Keep the standby player unloaded until the active video is near its end.
    // Then decode only the next video's first frame so EndOfMedia can swap
    // outputs quickly without retaining decoder resources for the whole video.
    readonly property int preloadLeadTimeMs: 3000
    property int activePlayerSlot: 0
    property url preparedVideoUrl: ""
    property int preparedVideoIndex: -1
    property bool preparedFrameReady: false
    property bool transitionPending: false
    property double transitionRequestedAt: 0
    property bool resettingPlayers: false
    property var unavailableVideoSources: []

    readonly property var activePlayer: root.activePlayerSlot === 0 ? playerA : playerB
    readonly property var standbyPlayer: root.activePlayerSlot === 0 ? playerB : playerA
    readonly property var activeVideoOutput: root.activePlayerSlot === 0 ? wallpaperVideoOutputA : wallpaperVideoOutputB
    readonly property var standbyVideoOutput: root.activePlayerSlot === 0 ? wallpaperVideoOutputB : wallpaperVideoOutputA

    readonly property int configuredFillMode: {
        const value = Number(root.configuration.FillMode);
        return Number.isFinite(value) ? value : 1;
    }

    function normalizeVideoUrl(configured) {
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

        if (value.startsWith("/")) {
            return "file://" + value;
        }

        return value;
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
        const active = root.activePlayer;
        root.debugLog(
            "snapshot context=" + context
            + " app=" + Qt.application.name
            + " screenLocker=" + root.isScreenLocker
            + " screenGeometry=" + root.wallpaperScreenGeometry.x + "," + root.wallpaperScreenGeometry.y + "," + root.wallpaperScreenGeometry.width + "x" + root.wallpaperScreenGeometry.height
            + " playbackMode=" + root.playbackMode
            + " source=" + active.source.toString()
            + " queueIndex=" + root.currentVideoIndex
            + " queueCount=" + root.playbackQueue.length
            + " playbackState=" + root.playbackStateName(active.playbackState)
            + " mediaStatus=" + root.mediaStatusName(active.mediaStatus)
            + " positionMs=" + active.position
            + " durationMs=" + active.duration
            + " audioEnabled=" + root.audioEnabled
            + " audioVolume=" + root.audioVolume
            + " activeAudioTrack=" + active.activeAudioTrack
            + " pauseOnMaximized=" + root.pauseOnMaximized
            + " hasMaximizedWindow=" + root.hasMaximizedWindow
            + " screenPoweredOff=" + root.screenPoweredOff
            + " preparedSource=" + root.preparedVideoUrl.toString()
            + " preparedFrameReady=" + root.preparedFrameReady
            + " transitionPending=" + root.transitionPending
        );
    }

    function playlistVideos() {
        const videos = [];
        for (let i = 0; i < root.configuredPlaylist.length; ++i) {
            const source = root.normalizeVideoUrl(root.configuredPlaylist[i]);
            if (source.toString().length > 0) {
                videos.push({ source: source.toString(), name: source.toString(), modified: 0 });
            }
        }
        return videos;
    }

    function sourceUnavailable(source) {
        return root.unavailableVideoSources.indexOf(source.toString()) >= 0;
    }

    function markSourceUnavailable(source) {
        const value = source.toString();
        if (value.length === 0 || root.sourceUnavailable(value)) {
            return;
        }

        root.unavailableVideoSources = root.unavailableVideoSources.concat([value]);
    }

    function clearPreparedState(stopStandby) {
        root.transitionPending = false;
        root.transitionRequestedAt = 0;
        root.preparedVideoUrl = "";
        root.preparedVideoIndex = -1;
        root.preparedFrameReady = false;

        if (stopStandby) {
            const standby = root.standbyPlayer;
            standby.stop();
            standby.source = "";
        }
    }

    function nextVideoSelection() {
        if (root.playbackQueue.length === 0 || root.currentVideoIndex < 0) {
            return null;
        }

        const startIndex = (root.currentVideoIndex + 1) % root.playbackQueue.length;

        for (let offset = 0; offset < root.playbackQueue.length; ++offset) {
            const index = (startIndex + offset) % root.playbackQueue.length;
            const source = root.playbackQueue[index].source.toString();
            if (root.sourceUnavailable(source)) {
                continue;
            }

            if (root.playbackQueue.length > 1 && source === root.currentVideoUrl.toString()) {
                continue;
            }

            return {
                source: source,
                index: index
            };
        }

        return null;
    }

    function prepareNextVideo() {
        if (root.playbackMode === 0 || root.playbackQueue.length <= 1 || root.currentVideoIndex < 0 || root.preparedVideoUrl.toString().length > 0) {
            return;
        }

        const selection = root.nextVideoSelection();
        if (selection === null) {
            return;
        }

        root.preparedVideoUrl = root.normalizeVideoUrl(selection.source);
        root.preparedVideoIndex = selection.index;
        root.preparedFrameReady = false;

        const standby = root.standbyPlayer;
        standby.stop();
        standby.source = root.preparedVideoUrl;
        root.debugLog("preload action=load source=" + root.preparedVideoUrl.toString() + " index=" + root.preparedVideoIndex);
    }

    function warmPreparedVideo() {
        if (root.preparedVideoUrl.toString().length === 0 || root.preparedFrameReady) {
            return;
        }

        if (root.shouldPauseForMaximizedWindow || root.shouldPauseForScreenPower) {
            return;
        }

        if (!root.transitionPending && root.activePlayer.playbackState !== MediaPlayer.PlayingState) {
            return;
        }

        const standby = root.standbyPlayer;
        if (standby.source.toString() !== root.preparedVideoUrl.toString()) {
            return;
        }

        if (standby.mediaStatus === MediaPlayer.LoadedMedia || standby.mediaStatus === MediaPlayer.BufferedMedia || standby.mediaStatus === MediaPlayer.BufferingMedia) {
            if (standby.playbackState !== MediaPlayer.PlayingState) {
                root.debugLog("preload action=warm source=" + standby.source.toString());
                standby.play();
            }
        }
    }

    function handleStandbyFrame() {
        const standby = root.standbyPlayer;
        if (root.preparedVideoUrl.toString().length === 0
                || standby.source.toString() !== root.preparedVideoUrl.toString()
                || standby.playbackState !== MediaPlayer.PlayingState
                || root.preparedFrameReady) {
            return;
        }

        root.preparedFrameReady = true;
        root.debugLog("preload action=first-frame-ready source=" + standby.source.toString() + " positionMs=" + standby.position);

        if (root.transitionPending && !root.shouldPauseForMaximizedWindow && !root.shouldPauseForScreenPower) {
            root.commitPreparedTransition("first-frame-ready");
            return;
        }

        // Retain the decoded first frame without continuously decoding the
        // standby video until it is actually time to display it.
        standby.pause();
    }

    function requestVideoTransition(trigger) {
        if (root.playbackMode === 0 || root.playbackQueue.length <= 1) {
            return;
        }

        if (root.transitionPending) {
            if (root.preparedFrameReady && !root.shouldPauseForMaximizedWindow && !root.shouldPauseForScreenPower) {
                root.commitPreparedTransition(trigger);
            } else {
                root.warmPreparedVideo();
            }
            return;
        }

        if (root.preparedVideoUrl.toString().length === 0) {
            root.prepareNextVideo();
        }

        if (root.preparedVideoUrl.toString().length === 0) {
            root.debugError("transition action=unavailable trigger=" + trigger);
            return;
        }

        root.transitionPending = true;
        root.transitionRequestedAt = Date.now();
        root.debugLog("transition action=request trigger=" + trigger + " prepared=" + root.preparedVideoUrl.toString());

        if (root.shouldPauseForMaximizedWindow || root.shouldPauseForScreenPower) {
            return;
        }

        if (root.preparedFrameReady) {
            root.commitPreparedTransition(trigger);
        } else {
            root.warmPreparedVideo();
        }
    }

    function commitPreparedTransition(trigger) {
        if (!root.transitionPending || root.preparedVideoUrl.toString().length === 0) {
            return;
        }

        if (root.shouldPauseForMaximizedWindow || root.shouldPauseForScreenPower) {
            return;
        }

        const oldPlayer = root.activePlayer;
        const newPlayer = root.standbyPlayer;
        const nextSlot = root.activePlayerSlot === 0 ? 1 : 0;
        const nextSource = root.preparedVideoUrl;
        const nextIndex = root.preparedVideoIndex;
        const requestedAt = root.transitionRequestedAt;

        root.transitionPending = false;
        root.transitionRequestedAt = 0;
        root.preparedVideoUrl = "";
        root.preparedVideoIndex = -1;
        root.preparedFrameReady = false;

        root.currentVideoIndex = nextIndex;
        root.currentVideoUrl = nextSource;

        // The standby output already contains a decoded first frame. Make it
        // visible first, then release the now-hidden old player and resume.
        root.activePlayerSlot = nextSlot;
        oldPlayer.stop();
        oldPlayer.source = "";

        if (newPlayer.playbackState !== MediaPlayer.PlayingState) {
            newPlayer.play();
        }

        const transitionDelay = requestedAt > 0 ? Math.max(0, Date.now() - requestedAt) : 0;
        root.debugLog("transition action=commit trigger=" + trigger + " source=" + nextSource.toString() + " index=" + nextIndex + " delayMs=" + transitionDelay);
    }

    function handlePreparedVideoFailure(failedSource) {
        const source = failedSource.toString();
        const retryTransition = root.transitionPending;
        root.markSourceUnavailable(source);
        root.debugError("preload action=skip-invalid source=" + source);
        root.clearPreparedState(true);
        root.prepareNextVideo();

        if (retryTransition && root.preparedVideoUrl.toString().length > 0) {
            root.requestVideoTransition("skip-invalid-preload");
        }
    }

    function setCurrentVideo(source, trigger) {
        root.transitionPending = false;
        root.transitionRequestedAt = 0;
        root.preparedVideoUrl = "";
        root.preparedVideoIndex = -1;
        root.preparedFrameReady = false;

        root.resettingPlayers = true;
        playerA.stop();
        playerB.stop();
        playerA.source = "";
        playerB.source = "";
        root.activePlayerSlot = 0;

        root.currentVideoUrl = root.normalizeVideoUrl(source);
        if (root.currentVideoUrl.toString().length > 0) {
            playerA.source = root.currentVideoUrl;
        }
        root.resettingPlayers = false;

        root.debugLog("queue source=" + root.currentVideoUrl.toString() + " index=" + root.currentVideoIndex + " trigger=" + trigger);
    }

    function rebuildPlayback(trigger) {
        root.playbackQueue = [];
        root.currentVideoIndex = -1;
        root.unavailableVideoSources = [];

        if (root.playbackMode === 1) {
            root.playbackQueue = root.playlistVideos();
            if (root.playbackQueue.length > 0) {
                root.currentVideoIndex = 0;
                root.setCurrentVideo(root.playbackQueue[0].source, trigger);
            } else {
                root.setCurrentVideo("", trigger);
            }
            return;
        }

        root.setCurrentVideo(root.simpleVideoUrl, trigger);
    }

    function syncPlayback(trigger) {
        const syncTrigger = trigger || "unspecified";
        const active = root.activePlayer;
        const standby = root.standbyPlayer;

        if (active.source.toString().length === 0) {
            if (active.playbackState !== MediaPlayer.StoppedState) {
                root.debugLog("playback action=stop reason=no-source trigger=" + syncTrigger);
                active.stop();
            }
            return;
        }

        if (root.shouldPauseForMaximizedWindow || root.shouldPauseForScreenPower) {
            if (active.playbackState === MediaPlayer.PlayingState) {
                const pauseReason = root.shouldPauseForScreenPower ? "screen-powered-off" : "maximized-window";
                root.debugLog("playback action=pause reason=" + pauseReason + " trigger=" + syncTrigger + " positionMs=" + active.position);
                active.pause();
            }
            if (standby.playbackState === MediaPlayer.PlayingState) {
                standby.pause();
            }
            return;
        }

        if ((active.mediaStatus === MediaPlayer.LoadedMedia || active.mediaStatus === MediaPlayer.BufferedMedia || active.mediaStatus === MediaPlayer.BufferingMedia) && active.playbackState !== MediaPlayer.PlayingState) {
            root.debugLog("playback action=play trigger=" + syncTrigger + " positionMs=" + active.position);
            active.play();
        }

        if (root.transitionPending) {
            if (root.preparedFrameReady) {
                root.commitPreparedTransition(syncTrigger);
            } else {
                root.warmPreparedVideo();
            }
            return;
        }

        if (active.playbackState === MediaPlayer.PlayingState) {
            root.maybePrepareNextVideo(active);
        }
    }

    function maybePrepareNextVideo(mediaPlayer) {
        if (root.playbackMode === 0 || root.playbackQueue.length <= 1 || root.currentVideoIndex < 0) {
            return;
        }

        if (mediaPlayer.playbackState !== MediaPlayer.PlayingState || mediaPlayer.duration <= 0) {
            return;
        }

        const remainingMs = mediaPlayer.duration - mediaPlayer.position;
        if (remainingMs > root.preloadLeadTimeMs) {
            return;
        }

        if (root.preparedVideoUrl.toString().length === 0) {
            root.prepareNextVideo();
            if (root.preparedVideoUrl.toString().length > 0) {
                root.debugLog("preload action=trigger remainingMs=" + Math.max(0, remainingMs));
            }
        }

        if (root.preparedVideoUrl.toString().length > 0 && !root.preparedFrameReady) {
            root.warmPreparedVideo();
        }
    }

    function handlePlayerPositionChanged(slot, mediaPlayer) {
        if (root.resettingPlayers || slot !== root.activePlayerSlot) {
            return;
        }

        root.maybePrepareNextVideo(mediaPlayer);
    }

    function handlePlayerMediaStatusChanged(slot, mediaPlayer) {
        root.debugLog("media slot=" + slot + " status=" + root.mediaStatusName(mediaPlayer.mediaStatus) + " positionMs=" + mediaPlayer.position + " durationMs=" + mediaPlayer.duration);

        if (root.resettingPlayers) {
            return;
        }

        if (slot === root.activePlayerSlot) {
            if (mediaPlayer.mediaStatus === MediaPlayer.EndOfMedia && root.playbackMode !== 0 && root.playbackQueue.length > 1) {
                root.requestVideoTransition("playlist-end-of-media");
                return;
            }

            if (mediaPlayer.mediaStatus === MediaPlayer.InvalidMedia && root.playbackMode !== 0 && root.playbackQueue.length > 1) {
                root.markSourceUnavailable(mediaPlayer.source);
                root.requestVideoTransition("skip-invalid-active");
                return;
            }

            root.syncPlayback("media-status");
            return;
        }

        if (mediaPlayer.source.toString() !== root.preparedVideoUrl.toString()) {
            return;
        }

        if (mediaPlayer.mediaStatus === MediaPlayer.InvalidMedia) {
            root.handlePreparedVideoFailure(mediaPlayer.source);
            return;
        }

        root.warmPreparedVideo();
    }

    function handlePlayerPlaybackStateChanged(slot, mediaPlayer) {
        root.debugLog("playback slot=" + slot + " state=" + root.playbackStateName(mediaPlayer.playbackState) + " positionMs=" + mediaPlayer.position);

        if (root.resettingPlayers) {
            return;
        }

        if (slot !== root.activePlayerSlot) {
            return;
        }

        if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
            root.maybePrepareNextVideo(mediaPlayer);
            return;
        }

        if (mediaPlayer.playbackState === MediaPlayer.StoppedState
                && mediaPlayer.mediaStatus === MediaPlayer.EndOfMedia
                && root.playbackMode !== 0
                && root.playbackQueue.length > 1) {
            root.requestVideoTransition("playlist-stopped-at-end");
            return;
        }

        root.syncPlayback("playback-state");
    }

    function handlePlayerError(slot, mediaPlayer, error, errorString) {
        root.debugError(
            "media slot=" + slot
            + " error=" + root.mediaErrorName(error)
            + " code=" + error
            + " message=" + errorString
            + " status=" + root.mediaStatusName(mediaPlayer.mediaStatus)
            + " state=" + root.playbackStateName(mediaPlayer.playbackState)
            + " positionMs=" + mediaPlayer.position
            + " source=" + mediaPlayer.source.toString()
        );

        if (slot !== root.activePlayerSlot && mediaPlayer.source.toString() === root.preparedVideoUrl.toString()) {
            root.handlePreparedVideoFailure(mediaPlayer.source);
        }
    }

    onAudioEnabledChanged: root.debugLog("configuration audioEnabled=" + root.audioEnabled)
    onAudioVolumeChanged: root.debugLog("configuration audioVolume=" + root.audioVolume)
    onPauseOnMaximizedChanged: root.debugLog("configuration pauseOnMaximized=" + root.pauseOnMaximized)
    onConfiguredFillModeChanged: root.debugLog("configuration fillMode=" + root.configuredFillMode)
    onWallpaperScreenGeometryChanged: root.debugLog("screen geometry=" + root.wallpaperScreenGeometry.x + "," + root.wallpaperScreenGeometry.y + "," + root.wallpaperScreenGeometry.width + "x" + root.wallpaperScreenGeometry.height)
    onPlaybackModeChanged: {
        if (root.componentReady) {
            root.rebuildPlayback("playback-mode-changed");
        }
    }
    onSimpleVideoUrlChanged: {
        if (root.componentReady && root.playbackMode === 0) {
            root.rebuildPlayback("simple-video-changed");
        }
    }
    onConfiguredPlaylistChanged: {
        if (root.componentReady && root.playbackMode === 1) {
            root.rebuildPlayback("playlist-changed");
        }
    }
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

    Connections {
        target: root.standbyVideoOutput !== null ? root.standbyVideoOutput.videoSink : null

        function onVideoFrameChanged(frame) {
            root.handleStandbyFrame();
        }
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

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            anchors.fill: parent
            color: root.backgroundColor
        }

        VideoOutput {
            id: wallpaperVideoOutputA

            anchors.centerIn: parent
            width: root.configuredFillMode === 3 ? Math.max(0, sourceRect.width) : parent.width
            height: root.configuredFillMode === 3 ? Math.max(0, sourceRect.height) : parent.height
            opacity: root.activePlayerSlot === 0 ? 1 : 0

            fillMode: {
                switch (root.configuredFillMode) {
                case 0:
                    return VideoOutput.PreserveAspectFit;
                case 2:
                    return VideoOutput.Stretch;
                case 3:
                    return VideoOutput.PreserveAspectFit;
                default:
                    return VideoOutput.PreserveAspectCrop;
                }
            }
        }

        VideoOutput {
            id: wallpaperVideoOutputB

            anchors.centerIn: parent
            width: root.configuredFillMode === 3 ? Math.max(0, sourceRect.width) : parent.width
            height: root.configuredFillMode === 3 ? Math.max(0, sourceRect.height) : parent.height
            opacity: root.activePlayerSlot === 1 ? 1 : 0

            fillMode: {
                switch (root.configuredFillMode) {
                case 0:
                    return VideoOutput.PreserveAspectFit;
                case 2:
                    return VideoOutput.Stretch;
                case 3:
                    return VideoOutput.PreserveAspectFit;
                default:
                    return VideoOutput.PreserveAspectCrop;
                }
            }
        }
    }

    AudioOutput {
        id: wallpaperAudioOutputA
        muted: !root.audioEnabled || root.activePlayerSlot !== 0
        volume: root.audioVolume
    }

    AudioOutput {
        id: wallpaperAudioOutputB
        muted: !root.audioEnabled || root.activePlayerSlot !== 1
        volume: root.audioVolume
    }

    MediaPlayer {
        id: playerA

        videoOutput: wallpaperVideoOutputA
        audioOutput: root.audioEnabled ? wallpaperAudioOutputA : null
        activeAudioTrack: root.audioEnabled ? 0 : -1
        activeSubtitleTrack: -1
        loops: root.playbackMode === 0 || root.playbackQueue.length <= 1 ? MediaPlayer.Infinite : MediaPlayer.Once

        onSourceChanged: root.debugLog("media slot=0 source=" + source.toString())
        onMediaStatusChanged: root.handlePlayerMediaStatusChanged(0, playerA)
        onPlaybackStateChanged: root.handlePlayerPlaybackStateChanged(0, playerA)
        onPositionChanged: root.handlePlayerPositionChanged(0, playerA)
        onErrorOccurred: (error, errorString) => root.handlePlayerError(0, playerA, error, errorString)
    }

    MediaPlayer {
        id: playerB

        videoOutput: wallpaperVideoOutputB
        audioOutput: root.audioEnabled ? wallpaperAudioOutputB : null
        activeAudioTrack: root.audioEnabled ? 0 : -1
        activeSubtitleTrack: -1
        loops: root.playbackMode === 0 || root.playbackQueue.length <= 1 ? MediaPlayer.Infinite : MediaPlayer.Once

        onSourceChanged: root.debugLog("media slot=1 source=" + source.toString())
        onMediaStatusChanged: root.handlePlayerMediaStatusChanged(1, playerB)
        onPlaybackStateChanged: root.handlePlayerPlaybackStateChanged(1, playerB)
        onPositionChanged: root.handlePlayerPositionChanged(1, playerB)
        onErrorOccurred: (error, errorString) => root.handlePlayerError(1, playerB, error, errorString)
    }

    Text {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 640)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: "white"
        text: root.activePlayer.errorString
        visible: root.activePlayer.error !== MediaPlayer.NoError && text.length > 0
    }

    Component.onCompleted: {
        root.componentReady = true;
        root.debugLog("component completed");
        root.rebuildPlayback("component-completed");
        root.logRuntimeSnapshot("component-completed");
        root.syncPlayback("component-completed");
    }
}
