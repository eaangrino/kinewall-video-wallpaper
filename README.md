# KineWall — Video Wallpaper for Linux

[Español](README.es.md)

**KineWall** is a QML wallpaper plugin for KDE Plasma 6 that plays a local video in a continuous loop. Audio is disabled by default and can be enabled from the KineWall configuration panel.

KineWall can be used both as the **Plasma Desktop wallpaper** and as the **KDE Plasma lock screen (KScreenLocker) wallpaper**.

It can also pause video playback automatically while a maximized window covers the desktop, avoiding unnecessary playback when the wallpaper is not visible. This performance pause applies only to the desktop.

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
4. Click **Browse…** and select a video file.
5. Choose the desired positioning mode.
6. Choose whether audio should be **Disabled** or **Enabled**.
7. Optionally enable or disable **Pause when a window is maximized**.
8. Apply the changes.

### Lock screen (KScreenLocker)

1. Open **System Settings**.
2. Go to **Security & Privacy → Screen Locking**.
3. Open **Configure Appearance…**.
4. Under **Wallpaper Type**, select **KineWall**.
5. Click **Browse…** and select a video file.
6. Choose the desired positioning mode and audio mode.
7. Apply the changes.
8. Press **Meta + L** to test the lock screen.

The desktop and lock screen keep their own wallpaper configuration, so they can use the same video or different videos and configure audio independently.

The **Pause when a window is maximized** option only affects the desktop. KScreenLocker ignores maximized windows, but it pauses the video while the display is powered off and resumes from the same position when the display turns back on.

## Reload Plasma if necessary

If KineWall does not appear immediately after installation or an update:

```bash
systemctl --user restart plasma-plasmashell.service
```

If your session does not provide this systemd user unit, log out and log back in.

## Audio

Audio is **disabled by default** and can be changed from the KineWall configuration panel using the **Audio** selector:

- **Disabled**: KineWall does not connect an `AudioOutput` to the player and sets `activeAudioTrack: -1`, keeping the audio track disabled.
- **Enabled**: KineWall connects an `AudioOutput` and activates the first audio track with `activeAudioTrack: 0`.

The audio setting is stored independently for each wallpaper configuration, including the desktop and KScreenLocker.

KineWall currently provides an enable/disable audio selector; it does not provide a separate volume control.

## Pause when a window is maximized

KineWall can optionally pause playback when a maximized, non-minimized window is present on the same monitor while running as the desktop wallpaper.

Window detection uses Plasma's `org.kde.taskmanager` and filters by:

- the current virtual desktop;
- the current activity;
- the monitor running the current KineWall instance;
- non-minimized windows;
- maximized windows.

When such a window is detected, KineWall calls `MediaPlayer.pause()`, preserving the playback position.

When no matching maximized window remains, KineWall calls `MediaPlayer.play()` and playback resumes from the same position.

This behavior is disabled inside KScreenLocker so maximized windows do not pause the lock screen video.

The option is enabled by default and can be disabled from the KineWall configuration panel.

## Pause while the lock-screen display is powered off

When KineWall is running inside KScreenLocker, it pauses `MediaPlayer` if the containing Qt Quick window stops presenting frames after the display powers off. `MediaPlayer.pause()` preserves the current position.

KineWall keeps a lightweight presentation probe active while paused. When the display powers back on and the lock-screen window presents a frame again, playback resumes from the preserved position.

This behavior is limited to KScreenLocker. The desktop wallpaper is not paused merely because a display-power probe changes state.

## License

MIT
