# KineWall — Video Wallpaper for Linux

[Español](README.es.md)

**KineWall** is a QML wallpaper plugin for KDE Plasma 6 that plays a local video in a continuous loop while explicitly disabling the audio track (`activeAudioTrack: -1`).

It can also pause video playback automatically while a maximized window covers the desktop, avoiding unnecessary playback when the wallpaper is not visible.

## Target compatibility

- Debian 13 (Trixie)
- KDE Plasma 6.3.x
- Qt 6.8.x
- Qt Multimedia QML

## Install with `install.sh` — recommended

Clone or extract the project, open a terminal in the project root, and run:

```bash
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

1. Right-click the desktop.
2. Select **Configure Desktop and Wallpaper**.
3. Under **Wallpaper Type**, select **KineWall**.
4. Click **Browse…** and select a video file.
5. Choose the desired positioning mode.
6. Optionally enable or disable **Pause when a window is maximized**.
7. Apply the changes.

## Reload Plasma if necessary

If KineWall does not appear immediately after installation or an update:

```bash
systemctl --user restart plasma-plasmashell.service
```

If your session does not provide this systemd user unit, log out and log back in.

## Audio

KineWall does not create an `AudioOutput` and explicitly configures:

```qml
activeAudioTrack: -1
```

The audio track is therefore disabled rather than merely played at zero volume.

## Pause when a window is maximized

KineWall can optionally pause playback when a maximized, non-minimized window is present on the same monitor.

Window detection uses Plasma's `org.kde.taskmanager` and filters by:

- the current virtual desktop;
- the current activity;
- the monitor running the current KineWall instance;
- non-minimized windows;
- maximized windows.

When such a window is detected, KineWall calls `MediaPlayer.pause()`, preserving the playback position.

When no matching maximized window remains, KineWall calls `MediaPlayer.play()` and playback resumes from the same position.

The option is enabled by default and can be disabled from the KineWall configuration panel.

## License

MIT
