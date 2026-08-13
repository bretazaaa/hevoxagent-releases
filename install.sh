#!/usr/bin/env bash

set -euo pipefail

REPO="bretazaaa/hevoxagent-releases"
PANEL_URL=""

while [ $# -gt 0 ]; do
    case "$1" in
        --panel)
            PANEL_URL="$2"
            shift 2
            ;;
        *)
            echo "hevoxagent installer: unknown argument $1" >&2
            exit 2
            ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

if ! command -v apt-get >/dev/null 2>&1 || ! command -v dpkg >/dev/null 2>&1; then
    echo "hevoxagent installer: only Debian/Ubuntu (apt) is supported for now." >&2
    exit 1
fi

ARCH="$(dpkg --print-architecture)"

echo "==> Looking up the latest hevoxagent release for $ARCH"
DOWNLOAD_URL="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep -o "\"browser_download_url\": *\"[^\"]*_${ARCH}\.deb\"" \
    | head -n1 \
    | sed -E 's/.*"(https[^"]+)".*/\1/')"

if [ -z "$DOWNLOAD_URL" ]; then
    echo "hevoxagent installer: no .deb release asset found for architecture $ARCH" >&2
    echo "Check https://github.com/${REPO}/releases for available builds." >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "==> Downloading $DOWNLOAD_URL"
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/hevoxagent.deb"

echo "==> Installing"
$SUDO apt-get install -y "$TMP_DIR/hevoxagent.deb"

echo ""
echo "hevoxagent installed."

if [ -n "$PANEL_URL" ]; then
    echo "==> Pairing with $PANEL_URL"
    $SUDO hevoxagent pair --panel "$PANEL_URL"
    echo "==> Starting the service"
    $SUDO systemctl start hevoxagent
else
    echo "Next steps:"
    echo "  1. Edit /etc/hevoxagent/config.yml if needed (agent.server_user, etc.)"
    echo "  2. sudo hevoxagent pair --panel <panel-url>"
    echo "  3. sudo systemctl start hevoxagent"
fi
