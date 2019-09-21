#!/usr/bin/env bash

declare -x SCRIPT_DIR=
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

declare -r URL="https://download.mozilla.org/"
declare LANGUAGE="es-ES"
declare OS='linux64'
declare PRODUCT='firefox-devedition'
declare VERSION='latest'
declare DOWNLOADING_FILENAME=
declare DOWNLOADING_URL=
declare DOWNLOADING_VERSION=
declare CURRENT_VERSION=
declare -x TMP_DIR='/tmp/firefox-helper'
declare -x DESKTOP_DIR=

function f_init()
{
    # Crear directorio de trabajo
    mkdir -p "${TMP_DIR}"

    # shellcheck source=${HOME}/.config/user-dirs.dirs
    . "${HOME}/.config/user-dirs.dirs"
    DESKTOP_DIR=$XDG_DESKTOP_DIR
}


## Prepare URL to download and check if it's installed and updated
function f_check_version()
{
    echo;
    echo "===================================================================";
    echo "Checking installed version and latest version...";
    echo "-------------------------------------------------------------------";

    declare -i r=0

    wget -NS --content-disposition "${URL}?product=${PRODUCT}-${VERSION}-ssl&os=${OS}&lang=${LANGUAGE}" \
      --spider -o "${TMP_DIR}/download.log"

    read -r -a grepResult <<< "$(cat "${TMP_DIR}/download.log" | grep "Location:" | tail -1)"
    DOWNLOADING_URL=${grepResult[-1]}

    DOWNLOADING_FILENAME=$(basename "${DOWNLOADING_URL}")

    command -v firefox-dev > /dev/null
    r=$?
    if [[ $r -ne 0 ]]; then # No está instalado
        r=10
    else
        r=20
        CURRENT_VERSION=$(firefox-dev --version)
        CURRENT_VERSION=${CURRENT_VERSION:16}

        DOWNLOADING_VERSION=${DOWNLOADING_FILENAME%.tar.bz2}
        DOWNLOADING_VERSION=${DOWNLOADING_VERSION:8}

        echo " Installed version: ${CURRENT_VERSION}"
        echo "    Latest version: ${DOWNLOADING_VERSION}"

        if [[ "${CURRENT_VERSION}" == "${DOWNLOADING_VERSION}" ]]; then
            r=0
        fi
    fi

    echo; echo "Done!"

    return $r
}


function f_download()
{
    echo;
    echo "===================================================================";
    echo "Downloading from '${DOWNLOADING_URL}'...";
    echo "-------------------------------------------------------------------";

    wget -NS --content-disposition "${DOWNLOADING_URL}" -P "${TMP_DIR}/downloads/"
    return $?
}


function f_extract()
{
    echo;
    echo "-------------------------------------------------------------------";
    echo "Extracting temporal files to '${TMP_DIR}'...";
    echo "-------------------------------------------------------------------";

    mkdir -p "${TMP_DIR}"
    rm -rf "${TMP_DIR}/firefox"
    sudo tar -xvjf "${TMP_DIR}/downloads/${DOWNLOADING_FILENAME}" -C "${TMP_DIR}"
}


function f_install()
{
    declare INSTALL_DIR='/opt/firefox-dev'
    declare SRC_DIR="${TMP_DIR}/firefox"
    declare BIN='/usr/local/bin/firefox-dev'
    declare SHORTCUT="${SCRIPT_DIR}/resources/firefox-devedition.desktop"
    declare SHORTCUTS_DIR='/usr/share/applications'


    # TODO: Detect FF is running

    if [ -d ${INSTALL_DIR} ]; then
        echo;
        echo "===================================================================";
        echo "Uninstalling old version...";
        echo "-------------------------------------------------------------------";

        sudo rm -rf "${BIN}"
        sudo rm -rf "${DESKTOP_DIR}/firefox-devedition.desktop"
        sudo rm -rf "${SHORTCUTS_DIR}/firefox-devedition.desktop"
        sudo mv "${INSTALL_DIR}" "${INSTALL_DIR}-old"

        echo; echo "Done!"
    fi

    echo;
    echo "===================================================================";
    echo "Installing new version...";
    echo "-------------------------------------------------------------------";

    f_extract && sudo mv "${SRC_DIR}" ${INSTALL_DIR}

    if [[ $? -eq 0 ]]; then
        sudo rm -rf "${INSTALL_DIR}-old"
    else
        echo;
        echo "-------------------------------------------------------------------";
        echo "Failed to install. Rolling back old version...";
        echo "-------------------------------------------------------------------";
        sudo mv "${INSTALL_DIR}" "${INSTALL_DIR}"
    fi

    echo "Creating symbolic link to '${BIN}'"
    sudo ln -s "${INSTALL_DIR}/firefox" "${BIN}"

    echo "Creating shortcuts..."
    cp "${SHORTCUT}" "${DESKTOP_DIR}/"
    chmod +x "${DESKTOP_DIR}/firefox-devedition.desktop"

    sudo cp "${SHORTCUT}" "${SHORTCUTS_DIR}/"
    sudo chmod +x "${SHORTCUTS_DIR}/firefox-devedition.desktop"
    sudo chown root:root "${SHORTCUTS_DIR}/firefox-devedition.desktop"

    echo; echo "Done!"
}



declare -i er=0
f_init

f_check_version
er=$?

if [[ $er -eq 0 ]]; then
    echo "You are using the latest updated version of Firefox Developer Edition!"
else
    f_download

    echo;
    echo "###################################################################";
    if [[ $er -eq 10 ]]; then
        echo "Installing Firefox Developer Edition..."
    else
        echo "Updating Firefox Developer Edition..."
    fi
    echo "===================================================================";

    f_install
    er=$?
fi

if [[ $er -eq 0 ]]; then
    echo; echo "Success!"
else
    echo; echo "Failed!"
fi

exit $er
