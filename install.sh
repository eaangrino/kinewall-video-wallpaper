#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="com.eaangrino.kinewall"
PACKAGE_TYPE="Plasma/Wallpaper"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/${PLUGIN_ID}"

REQUIRED_DEBIAN_PACKAGES=(
    qml6-module-qtmultimedia
    qml6-module-qtquick-dialogs
)

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

printf 'KineWall installer\n'
printf '==================\n\n'

[[ -d "${PLUGIN_DIR}" ]] || die "Plugin directory not found: ${PLUGIN_DIR}"
[[ -f "${PLUGIN_DIR}/metadata.json" ]] || die "metadata.json not found in ${PLUGIN_DIR}"

command -v kpackagetool6 >/dev/null 2>&1 \
    || die "kpackagetool6 was not found. KDE Plasma 6 / KPackage must be installed."

if command -v dpkg-query >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
    missing_packages=()

    for package in "${REQUIRED_DEBIAN_PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "${package}" 2>/dev/null \
            | grep -q '^install ok installed$'; then
            missing_packages+=("${package}")
        fi
    done

    if ((${#missing_packages[@]} > 0)); then
        command -v sudo >/dev/null 2>&1 \
            || die "sudo is required to install missing Debian packages: ${missing_packages[*]}"

        printf 'Installing missing Debian dependencies: %s\n' "${missing_packages[*]}"
        sudo apt-get update
        sudo apt-get install -y "${missing_packages[@]}"
        printf '\n'
    else
        printf 'Required Debian dependencies are already installed.\n'
    fi
else
    printf 'Automatic dependency check skipped (dpkg/apt not detected).\n'
    printf 'Make sure Qt Multimedia QML and Qt Quick Dialogs for Qt 6 are installed.\n'
fi

if kpackagetool6 --type="${PACKAGE_TYPE}" --list 2>/dev/null \
    | grep -Fxq "${PLUGIN_ID}"; then
    printf 'Updating existing KineWall installation...\n'
    kpackagetool6 --type="${PACKAGE_TYPE}" --upgrade "${PLUGIN_DIR}"
else
    printf 'Installing KineWall for the current user...\n'
    kpackagetool6 --type="${PACKAGE_TYPE}" --install "${PLUGIN_DIR}"
fi

if ! kpackagetool6 --type="${PACKAGE_TYPE}" --list 2>/dev/null \
    | grep -Fxq "${PLUGIN_ID}"; then
    die "KineWall was not found in the installed Plasma wallpaper packages after installation."
fi

printf '\nKineWall was installed successfully.\n'
printf 'Installation location: %s\n' "${XDG_DATA_HOME:-${HOME}/.local/share}/plasma/wallpapers/${PLUGIN_ID}"
printf '\nIf KineWall does not appear immediately, reload Plasma with:\n'
printf '  systemctl --user restart plasma-plasmashell.service\n'
