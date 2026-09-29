# KineWall — Video Wallpaper for Linux

[Español](README.es.md)

**KineWall** is a QML wallpaper plugin for KDE Plasma 6 that plays local videos as the wallpaper. It supports a single looping video or an explicit playlist. Audio is disabled by default and can be enabled from the KineWall configuration panel.

KineWall can be used both as the **Plasma Desktop wallpaper** and as the **KDE Plasma lock screen (KScreenLocker) wallpaper**.

It can also pause video playback automatically when a maximized window is present or when visible, non-minimized windows cover a configurable percentage of the desktop. The coverage threshold defaults to 85%, avoiding unnecessary playback when most of the wallpaper is hidden. This performance pause applies only to the desktop.

When KineWall is used by KScreenLocker, playback is also paused while the display is powered off and resumes from the same position when the display turns back on. This display-power pause applies only to KScreenLocker and does not change desktop playback behavior.

## Target compatibility

- Debian 13 (Trixie)
- KDE Plasma 6.3.x
- Qt 6.8.x
- Qt Multimedia QML
- Plasma Desktop wallpaper
- Plasma lock screen (KScreenLocker) wallpaper

## Install with `install.sh` — recommended

Clone the repository, enter the project directory, make the installer executable, and run it:

```bash
git clone https://github.com/eaangrino/kinewall-video-wallpaper.git
cd kinewall-video-wallpaper
chmod +x install.sh
./install.sh
```

The installer:

1. verifies that `com.eaangrino.kinewall/` and its `metadata.json` are present;
2. checks the required Debian QML packages;
3. installs missing dependencies with APT only when necessary;
4. installs KineWall with `kpackagetool6`, or upgrades it when it is already installed;
5. verifies that Plasma detects `com.eaangrino.kinewall`.

The plugin itself is installed only for the current user. `sudo` is used only if Debian dependencies are missing.

The resulting user installation is located at:

```text
~/.local/share/plasma/wallpapers/com.eaangrino.kinewall/
```

## Dependencies

On Debian 13, the required packages are:

```bash
sudo apt update
sudo apt install qml6-module-qtmultimedia qml6-module-qtquick-dialogs
```

The installation script installs them automatically if they are missing.

## Manual installation

Install the package with KDE's KPackage tool:

```bash
kpackagetool6 --type=Plasma/Wallpaper --install ./com.eaangrino.kinewall
```

If KineWall is already installed and you are updating it:

```bash
kpackagetool6 --type=Plasma/Wallpaper --upgrade ./com.eaangrino.kinewall
```

Verify that Plasma detects it:

```bash
kpackagetool6 --type=Plasma/Wallpaper --list | grep -F 'com.eaangrino.kinewall'
```

You can also verify the installed package directly:

```bash
test -f ~/.local/share/plasma/wallpapers/com.eaangrino.kinewall/metadata.json && echo OK
```

## Usage

### Desktop

1. Right-click the desktop.
2. Select **Configure Desktop and Wallpaper**.
3. Under **Wallpaper Type**, select **KineWall**.
4. Choose a playback mode: **Simple** or **Playlist**.
5. Configure the selected mode and choose the desired positioning mode.
6. Choose whether audio should be **Disabled** or **Enabled** and, when enabled, adjust its volume.
7. Optionally enable or disable **Performance pause** and adjust the desktop coverage threshold (85% by default).
8. Apply the changes.

### Lock screen (KScreenLocker)

1. Open **System Settings**.
2. Go to **Security & Privacy → Screen Locking**.
3. Open **Configure Appearance…**.
4. Under **Wallpaper Type**, select **KineWall**.
5. Choose **Simple** or **Playlist** and configure its videos.
6. Choose the desired positioning mode and audio mode; when audio is enabled, adjust its volume if needed.
7. Apply the changes.
8. Press **Meta + L** to test the lock screen.

The desktop and lock screen keep their own wallpaper configuration, so they can use the same video or different videos and configure audio independently.

The **Performance pause** option only affects the desktop. KScreenLocker ignores both maximized windows and desktop coverage, but it pauses the video while the display is powered off and resumes from the same position when the display turns back on.

## Playback modes

KineWall provides two playback modes:

- **Simple** plays one selected video in a continuous loop.
- **Playlist** plays explicitly selected files in the order shown. Drag a video's reorder handle to place it anywhere in the list. Each video plays completely before KineWall advances to the next item, and the list loops after the last video.

## Positioning

The available positioning modes are:

- **Scaled and Cropped**: scales proportionally to fill the screen and crops overflow.
- **Scaled**: stretches the video to the wallpaper area.
- **Scaled, keep proportions**: fits the complete video while preserving its aspect ratio.
- **Centered**: displays the video at its native source size and centers it.

**Scaled, keep proportions** and **Centered** expose a **Solid color** setting for the uncovered background area.

## Reload Plasma if necessary

If KineWall does not appear immediately after installation or an update:

```bash
systemctl --user restart plasma-plasmashell.service
```

If your session does not provide this systemd user unit, log out and log back in.

## Audio

Audio is **disabled by default** and can be changed from the KineWall configuration panel using the **Audio** selector:

- **Disabled**: KineWall does not connect an `AudioOutput` to the player and sets `activeAudioTrack: -1`, keeping the audio track disabled.
- **Enabled**: KineWall connects an `AudioOutput` and activates the first audio track with `activeAudioTrack: 0`. A **Volume** slider appears below the audio selector and can be adjusted from 0% to 100%.

The audio enabled state and volume are stored independently for each wallpaper configuration, including the desktop and KScreenLocker. The volume defaults to 100%, preserving the previous full-volume behavior when audio is enabled.

## Performance pause

KineWall can optionally pause desktop playback when either of these conditions is met:

- a maximized, non-minimized window is present on the same monitor; or
- the combined area of visible, non-minimized windows reaches the configured coverage threshold, which defaults to 85%.

Coverage is calculated from the geometric union of the windows inside the current monitor. Areas where windows overlap are counted only once, and each window is clipped to the monitor bounds before the percentage is calculated.

Window detection uses Plasma's `org.kde.taskmanager` and filters by:

- the current virtual desktop;
- the current activity;
- the monitor running the current KineWall instance;
- visible windows;
- non-minimized windows.

Window geometry, open, close, minimize and restore changes update the percentage using event-driven model updates. Repeated changes in the same event-loop cycle are coalesced before coverage is recalculated.

When a pause condition is met, KineWall calls `MediaPlayer.pause()`, preserving the playback position. When neither condition remains, KineWall calls `MediaPlayer.play()` and playback resumes from the same position.

Maximized windows continue to pause regardless of the coverage threshold, preserving the existing behavior. The threshold controls the additional pause caused by one or more non-maximized windows.

This behavior is disabled inside KScreenLocker. The option is enabled by default, the default threshold is 85%, and both can be configured from the KineWall configuration panel.

## Pause while the lock-screen display is powered off

When KineWall is running inside KScreenLocker, it pauses `MediaPlayer` if the containing Qt Quick window stops presenting frames after the display powers off. `MediaPlayer.pause()` preserves the current position.

KineWall keeps a lightweight presentation probe active while paused. When the display powers back on and the lock-screen window presents a frame again, playback resumes from the preserved position.

This behavior is limited to KScreenLocker. The desktop wallpaper is not paused merely because a display-power probe changes state.

## Debug logging

KineWall provides an optional **Enable debug logging** setting at the bottom of its configuration panel. It is disabled by default.

When enabled, KineWall writes runtime diagnostics with the `[KineWall]` prefix, including media source changes, Qt Multimedia status, playback state and actions, pause/resume reasons, screen state used by the lock-screen probe, and `MediaPlayer` errors. Qt Multimedia or external-library messages emitted outside KineWall may also appear in the same process journal.

To collect logs:

1. Enable **Debug → Enable debug logging** and apply the configuration.
2. Reproduce the problem.
3. Export recent Plasma and KScreenLocker journal output:

```bash
journalctl --user --since "10 minutes ago" | grep -E 'plasmashell|kscreenlocker_greet' > kinewall-debug.log
```

To view only messages emitted directly by KineWall:

```bash
grep -F '[KineWall]' kinewall-debug.log
```

The debug output can include the full local video path. Review the log before sharing it publicly. Disable debug logging after reproducing the problem to avoid unnecessary journal noise.

## License

MIT
