# Repository Guidelines

## Project Structure & Module Organization

KineWall is a KDE Plasma 6 wallpaper package. The installable package lives in
`com.eaangrino.kinewall/`:

- `contents/ui/main.qml` implements video playback, display modes, and pause-on-maximized-window behavior.
- `contents/ui/config.qml` provides the Plasma configuration interface.
- `contents/config/main.xml` defines persisted wallpaper settings.
- `metadata.json` contains KPackage and Plasma metadata.

`install.sh` installs or upgrades the package for the current user. `README.md`
and `README.es.md` document installation and usage. There is currently no
separate source, test, or generated-assets directory.

## Build, Test, and Development Commands

This repository has no compilation or automated test step. Use the following
commands for development and validation:

```bash
./install.sh
kpackagetool6 --type=Plasma/Wallpaper --upgrade ./com.eaangrino.kinewall
kpackagetool6 --type=Plasma/Wallpaper --list | grep -F 'com.eaangrino.kinewall'
systemctl --user restart plasma-plasmashell.service
```

Make `install.sh` executable with `chmod +x install.sh` when needed. Test
behavior manually in Plasma by selecting KineWall, choosing a local video,
checking each fill mode, confirming audio is disabled, and verifying pause and
resume when a window is maximized.

## Coding Style & Naming Conventions

Use four spaces in Bash and QML, two-space indentation in JSON, and keep files
UTF-8 encoded. Follow existing QML conventions: `camelCase` for properties,
functions, and IDs; descriptive PascalCase for QML types; and explicit
comments for Plasma-specific behavior. Keep the plugin ID
`com.eaangrino.kinewall` unchanged across paths and metadata. In Bash, use
`set -Eeuo pipefail`, quote paths, and report failures through `die()`.

## Testing Guidelines

No automated framework or coverage requirement is configured. Before submitting
changes, run `bash -n install.sh`, perform a package install/upgrade, and
recheck Plasma detection. For QML changes, exercise empty, valid, and invalid
video paths and the relevant configuration states in a live Plasma session.

## Commit & Pull Request Guidelines

Use short, imperative Conventional Commit-style subjects, matching history such
as `feat: ...`, `docs: ...`, and `chore: ...`. Keep commits focused. Pull
requests should explain user-visible behavior, list manual validation commands,
identify Debian/Plasma versions tested, and include screenshots or a short
recording for configuration or visual changes. Update both README files when
installation or usage behavior changes.

## Security & Configuration Tips

The installer may use `sudo apt-get` only to install missing Debian
dependencies; review scripts before running them. KineWall reads local video
paths and intentionally disables audio with `activeAudioTrack: -1`.
