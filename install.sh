#!/usr/bin/env bash
# Hevox Agent installer/updater.
#
#   curl -sSL https://raw.githubusercontent.com/bretazaaa/hevoxagent-releases/main/install.sh | sudo bash
#
# Options (curl | sudo bash can't take flags directly — pass them after
# "-s --"):
#
#   curl -sSL .../install.sh | sudo bash -s -- --verbose
#   curl -sSL .../install.sh | sudo bash -s -- --panel http://your-panel:8080
#
#   --panel <url>   Pair with this panel and start the service once
#                    installed (first install only).
#   --verbose        Show full apt/dpkg/curl/systemctl output as it runs,
#                    in addition to logging it (see LOG_FILE below). The
#                    installer's actual behavior is identical either way —
#                    only what's printed to the terminal changes.
#   -h, --help       Show this help.
set -euo pipefail

REPO="bretazaaa/hevoxagent-releases"
PKG="hevoxagent"
SERVICE="hevoxagent.service"
LOG_DIR="/var/log/hevoxagent"
LOG_FILE="$LOG_DIR/install.log"
BOX_WIDTH=48

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
PANEL_URL=""
VERBOSE=0

# A plain string, not a read of $0: when this script runs via
# `curl | bash`, $0 is the shell interpreter, not a file on disk with
# this script's own source in it — reading "$0" for --help text would
# silently fail (or print the wrong thing) in exactly the documented,
# primary way of invoking this installer.
print_help() {
    cat <<'EOF'
Hevox Agent installer/updater.

  curl -sSL https://raw.githubusercontent.com/bretazaaa/hevoxagent-releases/main/install.sh | sudo bash

Options (curl | sudo bash can't take flags directly — pass them after
"-s --"):

  curl -sSL .../install.sh | sudo bash -s -- --verbose
  curl -sSL .../install.sh | sudo bash -s -- --panel http://your-panel:8080

  --panel <url>   Pair with this panel and start the service once
                  installed (first install only).
  --verbose       Show full apt/dpkg/curl/systemctl output as it runs,
                  in addition to logging it. The installer's actual
                  behavior is identical either way — only what's
                  printed to the terminal changes.
  -h, --help      Show this help.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --panel)
            PANEL_URL="${2:-}"
            [ -n "$PANEL_URL" ] || { echo "hevoxagent installer: --panel requires a URL" >&2; exit 2; }
            shift 2
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "hevoxagent installer: unknown argument $1 (see --help)" >&2
            exit 2
            ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ---------------------------------------------------------------------------
# Colors — only on an interactive TTY, and never if NO_COLOR is set
# (https://no-color.org/). Kept sober: identity color for headers, plain
# semantic colors for status, no animation.
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_VIOLET=$'\033[38;5;135m'
    C_GREEN=$'\033[0;32m'
    C_RED=$'\033[0;31m'
    C_YELLOW=$'\033[0;33m'
    C_GRAY=$'\033[0;90m'
    C_BOLD=$'\033[1m'
    C_RESET=$'\033[0m'
else
    C_VIOLET=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_GRAY=""; C_BOLD=""; C_RESET=""
fi

# ---------------------------------------------------------------------------
# Logging — always on, even in non-verbose mode (section 7): every
# captured command's output lands in LOG_FILE regardless of what's shown
# on screen, so a failure can always be diagnosed after the fact. The one
# deliberate exception is the pairing step: it prints straight to the
# terminal and is never captured here, since it displays a short-lived
# pairing code (never write secrets/tokens to the log).
# ---------------------------------------------------------------------------
$SUDO mkdir -p "$LOG_DIR" 2>/dev/null || true
$SUDO touch "$LOG_FILE" 2>/dev/null || true

log_note() {
    printf -- '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG_FILE" 2>/dev/null || true
}

# run_captured <description> <cmd...>
# Runs cmd with stdout+stderr captured into LOG_FILE. In --verbose mode
# the same output also streams live to the terminal. Returns cmd's exit
# status either way — functional behavior never depends on VERBOSE.
run_captured() {
    local desc="$1"; shift
    log_note "----- $desc -----"
    local tmp_out
    tmp_out="$(mktemp)"
    local ec=0
    if [ "$VERBOSE" -eq 1 ]; then
        "$@" >"$tmp_out" 2>&1 &
        local pid=$!
        # shellcheck disable=SC2094
        tail -f "$tmp_out" --pid="$pid" 2>/dev/null &
        local tail_pid=$!
        wait "$pid" || ec=$?
        kill "$tail_pid" 2>/dev/null || true
        wait "$tail_pid" 2>/dev/null || true
    else
        "$@" >"$tmp_out" 2>&1 || ec=$?
    fi
    cat "$tmp_out" >>"$LOG_FILE" 2>/dev/null || true
    LAST_OUTPUT="$(tail -n 5 "$tmp_out" 2>/dev/null || true)"
    rm -f "$tmp_out"
    return "$ec"
}

# ---------------------------------------------------------------------------
# Rendering helpers
# ---------------------------------------------------------------------------
box() {
    local title="$1" subtitle="${2:-}"
    local border
    border="$(printf '─%.0s' $(seq 1 "$BOX_WIDTH"))"
    printf '%s╭%s╮%s\n' "$C_VIOLET" "$border" "$C_RESET"
    box_line "$title"
    if [ -n "$subtitle" ]; then box_line "$subtitle"; fi
    printf '%s╰%s╯%s\n' "$C_VIOLET" "$border" "$C_RESET"
}

# Note on the "cond && x" one-liners below: under `set -e`, a bare
# top-level "cond && assignment" ABORTS THE WHOLE SCRIPT the moment cond
# is false (its exit status becomes the statement's exit status). Every
# such line in this file is deliberately either wrapped in `if`
# (exempt from -e) or suffixed with `|| true` — never left bare.
box_line() {
    local text="$1" left right pad
    pad=$(( BOX_WIDTH - ${#text} ))
    if [ "$pad" -lt 0 ]; then pad=0; fi
    left=$(( pad / 2 ))
    right=$(( pad - left ))
    printf '%s│%s%s%s%s│%s\n' \
        "$C_VIOLET" "$(printf '%*s' "$left" '')" "$text" "$(printf '%*s' "$right" '')" "$C_VIOLET" "$C_RESET"
}

step_header() {
    printf '\n%s[%s/%s]%s %s\n' "$C_BOLD" "$1" "$2" "$C_RESET" "$3"
}

info_line() {
    printf '      %s%-12s%s %s\n' "$C_GRAY" "$1" "$C_RESET" "$2"
}

ok_line() {
    printf '      %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"
}

warn_line() {
    printf '      %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$1"
}

fail() {
    local step="$1" reason="$2"
    printf '\n%s✕ Installation failed%s\n\n' "$C_RED" "$C_RESET"
    printf 'Step: %s\n' "$step"
    printf 'Error: %s\n\n' "$reason"
    printf 'Run with --verbose for detailed logs, or check %s\n' "$LOG_FILE"
    log_note "FAILED at: $step ($reason)"
    exit 1
}

# ---------------------------------------------------------------------------
# Environment detection
# ---------------------------------------------------------------------------
if ! command -v apt-get >/dev/null 2>&1 || ! command -v dpkg >/dev/null 2>&1; then
    printf '%s✕%s Only Debian/Ubuntu (apt) systems are supported today.\n' "$C_RED" "$C_RESET" >&2
    exit 1
fi

ARCH="$(dpkg --print-architecture)"
OS_PRETTY="Linux"
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_PRETTY="${PRETTY_NAME:-Linux}"
fi
CURRENT_USER="$(id -un)"

# Mirrors packaging/debian/postinst's own guard: no systemd (e.g. a
# plain container, WSL without systemd enabled) means service
# management/verification simply can't happen — degrade gracefully
# instead of failing on a systemctl call that can't succeed.
HAS_SYSTEMD=0
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
    HAS_SYSTEMD=1
fi

INSTALLED_VERSION="$(dpkg-query -W -f='${Version}' "$PKG" 2>/dev/null || true)"

# ---------------------------------------------------------------------------
# Latest release lookup — one API call, parsed twice (tag + asset URL).
# No jq dependency, matching the original script's constraints.
# ---------------------------------------------------------------------------
fetch_latest_release() {
    local json
    json="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>>"$LOG_FILE")" || return 1
    LATEST_TAG="$(printf '%s' "$json" | grep -o '"tag_name": *"[^"]*"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
    DOWNLOAD_URL="$(printf '%s' "$json" | grep -o "\"browser_download_url\": *\"[^\"]*_${ARCH}\.deb\"" | head -n1 | sed -E 's/.*"(https[^"]+)".*/\1/')"
    [ -n "$LATEST_TAG" ] || return 1
}

# ---------------------------------------------------------------------------
# Download with a real progress bar when we can measure it (known
# Content-Length, interactive terminal); an honest two-line fallback
# otherwise. Never a simulated/fake bar.
# ---------------------------------------------------------------------------
download_with_progress() {
    local url="$1" dest="$2"
    local content_length=""
    content_length="$(curl -fsSIL "$url" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="content-length:"{v=$2} END{print v}')"

    if [ -t 1 ] && [ -n "$content_length" ] && [ "$content_length" -gt 0 ] 2>/dev/null; then
        curl -fsSL "$url" -o "$dest" 2>>"$LOG_FILE" &
        local pid=$!
        local width=32
        while kill -0 "$pid" 2>/dev/null; do
            render_bar "$dest" "$content_length" "$width"
            sleep 0.2
        done
        local ec=0
        wait "$pid" || ec=$?
        if [ "$ec" -eq 0 ]; then
            render_bar "$dest" "$content_length" "$width"
        fi
        printf '\n'
        return "$ec"
    else
        printf '      Downloading Hevox Agent...\n'
        if curl -fsSL "$url" -o "$dest" 2>>"$LOG_FILE"; then
            printf '      %s✓%s Download complete\n' "$C_GREEN" "$C_RESET"
            return 0
        fi
        return 1
    fi
}

render_bar() {
    local dest="$1" total="$2" width="$3"
    local size=0 pct filled empty bar_filled="" bar_empty=""
    if [ -f "$dest" ]; then size="$(stat -c%s "$dest" 2>/dev/null || echo 0)"; fi
    pct=$(( size * 100 / total ))
    if [ "$pct" -gt 100 ]; then pct=100; fi
    filled=$(( pct * width / 100 ))
    empty=$(( width - filled ))
    if [ "$filled" -gt 0 ]; then bar_filled="$(printf '█%.0s' $(seq 1 "$filled"))"; fi
    if [ "$empty" -gt 0 ]; then bar_empty="$(printf '░%.0s' $(seq 1 "$empty"))"; fi
    printf '\r      %s%s%s%s %3d%%' "$C_VIOLET" "$bar_filled" "$C_RESET" "$bar_empty" "$pct"
}

# ---------------------------------------------------------------------------
# Post-install/update verification — every checkmark below reflects a
# real, just-performed check, never an assumption that a prior command
# "must have" worked.
# ---------------------------------------------------------------------------
verify_binary_installed() { [ -x /usr/bin/hevoxagent ]; }
verify_user_created()     { getent passwd hevoxagent-server >/dev/null 2>&1; }
verify_config_dir()       { [ -d /etc/hevoxagent ] && [ -d /var/lib/hevoxagent ]; }
verify_service_unit()     { [ "$HAS_SYSTEMD" -eq 1 ] && systemctl cat "$SERVICE" >/dev/null 2>&1; }

# Best-effort: was there a "connected to panel" log line in the last few
# seconds? If systemd-journald isn't available or nothing shows up yet,
# this simply reports "unknown" rather than asserting connectivity it
# can't actually confirm.
check_panel_reconnected() {
    [ "$HAS_SYSTEMD" -eq 1 ] || return 2
    command -v journalctl >/dev/null 2>&1 || return 2
    local tries=0
    while [ "$tries" -lt 5 ]; do
        if journalctl -u "$SERVICE" --since "-20s" --no-pager 2>/dev/null | grep -q "connected to panel"; then
            return 0
        fi
        tries=$((tries + 1))
        sleep 1
    done
    return 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log_note "=== install.sh invoked (user=$CURRENT_USER arch=$ARCH installed=${INSTALLED_VERSION:-none}) ==="

if ! fetch_latest_release; then
    fail "Checking latest release" "could not reach GitHub or parse the release list"
fi
LATEST_VERSION="${LATEST_TAG#v}"

if [ -z "$INSTALLED_VERSION" ]; then
    MODE="install"
elif [ "$INSTALLED_VERSION" = "$LATEST_VERSION" ]; then
    MODE="current"
else
    MODE="update"
fi

case "$MODE" in
    current)
        printf 'Hevox Agent v%s\n\n' "$INSTALLED_VERSION"
        printf 'Checking for updates...\n\n'
        printf '%s✓%s You are already running the latest version.\n' "$C_GREEN" "$C_RESET"
        exit 0
        ;;

    install)
        box "HEVOX AGENT" "Game Server Node Agent"

        step_header 1 6 "Checking system"
        info_line "OS" "$OS_PRETTY"
        info_line "Architecture" "$ARCH"
        info_line "User" "$CURRENT_USER"
        info_line "Status" "${C_GREEN}✓ Compatible${C_RESET}"

        step_header 2 6 "Checking latest release"
        info_line "Latest version:" "$LATEST_TAG"
        [ -n "$DOWNLOAD_URL" ] || fail "Checking latest release" "no .deb asset found for architecture $ARCH"

        step_header 3 6 "Downloading Hevox Agent"
        DEB_NAME="hevoxagent_${LATEST_VERSION}_${ARCH}.deb"
        printf '      %s\n' "$DEB_NAME"
        TMP_DIR="$(mktemp -d)"
        trap 'rm -rf "$TMP_DIR"' EXIT
        download_with_progress "$DOWNLOAD_URL" "$TMP_DIR/$DEB_NAME" \
            || fail "Downloading Hevox Agent" "download failed — see $LOG_FILE"

        step_header 4 6 "Installing package"
        run_captured "apt-get install $DEB_NAME" $SUDO apt-get install -y "$TMP_DIR/$DEB_NAME" \
            || fail "Installing package" "${LAST_OUTPUT:-dpkg/apt reported an error}"
        if verify_binary_installed; then ok_line "Binary installed"; else warn_line "Binary not found at /usr/bin/hevoxagent"; fi
        if verify_user_created; then ok_line "System user created"; else warn_line "System user hevoxagent-server not found"; fi
        if verify_config_dir; then ok_line "Configuration directory created"; else warn_line "/etc/hevoxagent or /var/lib/hevoxagent missing"; fi
        if verify_service_unit; then ok_line "systemd service installed"; else warn_line "hevoxagent.service not registered"; fi

        step_header 5 6 "Preparing Hevox Agent"
        info_line "Config" "/etc/hevoxagent/config.yml"
        info_line "State" "/var/lib/hevoxagent"
        info_line "Service" "$SERVICE"

        step_header 6 6 "Installation complete"

        printf '\n%s✓%s Hevox Agent %s installed successfully.\n' "$C_GREEN" "$C_RESET" "$LATEST_TAG"

        if [ -n "$PANEL_URL" ]; then
            printf '\nPairing with %s...\n\n' "$PANEL_URL"
            # Never captured/logged: the pairing command prints a
            # short-lived pairing code that must never land in a log file.
            log_note "pairing step: output intentionally not captured (contains pairing code)"
            $SUDO hevoxagent pair --panel "$PANEL_URL"
            if [ "$HAS_SYSTEMD" -eq 1 ]; then
                printf '\nStarting the service...\n'
                run_captured "systemctl start $SERVICE" $SUDO systemctl start "$SERVICE" \
                    || fail "Starting the service" "${LAST_OUTPUT:-systemctl reported an error}"
                if systemctl is-active --quiet "$SERVICE"; then
                    ok_line "hevoxagent.service is active"
                else
                    warn_line "hevoxagent.service did not report active — check: systemctl status hevoxagent"
                fi
            else
                printf '\n%s(no systemd detected — start hevoxagent yourself)%s\n' "$C_GRAY" "$C_RESET"
            fi
        else
            printf '\nNext step:\n\n'
            printf '  hevoxagent pair --panel http://YOUR-PANEL:8080\n\n'
            printf 'Then:\n\n'
            printf '  systemctl start hevoxagent\n'
        fi
        ;;

    update)
        box "HEVOX AGENT UPDATE"

        printf '\nCurrent version : v%s\n' "$INSTALLED_VERSION"
        printf 'Latest version  : %s\n' "$LATEST_TAG"

        [ -n "$DOWNLOAD_URL" ] || fail "Checking latest release" "no .deb asset found for architecture $ARCH"

        # Snapshot what must survive the upgrade untouched, so "preserved"
        # below is a verified fact, not an assumption.
        CONFIG_SUM=""
        if [ -f /etc/hevoxagent/config.yml ]; then
            CONFIG_SUM="$(md5sum /etc/hevoxagent/config.yml 2>/dev/null | awk '{print $1}')"
        fi
        IDENTITY_SUM=""
        if [ -f /var/lib/hevoxagent/identity.json ]; then
            IDENTITY_SUM="$(md5sum /var/lib/hevoxagent/identity.json 2>/dev/null | awk '{print $1}')"
        fi
        WAS_ACTIVE=0
        if [ "$HAS_SYSTEMD" -eq 1 ] && systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
            WAS_ACTIVE=1
        fi

        step_header 1 4 "Downloading update"
        DEB_NAME="hevoxagent_${LATEST_VERSION}_${ARCH}.deb"
        TMP_DIR="$(mktemp -d)"
        trap 'rm -rf "$TMP_DIR"' EXIT
        download_with_progress "$DOWNLOAD_URL" "$TMP_DIR/$DEB_NAME" \
            || fail "Downloading update" "download failed — see $LOG_FILE"

        step_header 2 4 "Installing $LATEST_TAG"
        run_captured "apt-get install $DEB_NAME" $SUDO apt-get install -y "$TMP_DIR/$DEB_NAME" \
            || fail "Installing $LATEST_TAG" "${LAST_OUTPUT:-dpkg/apt reported an error}"

        if [ -n "$CONFIG_SUM" ] && [ -f /etc/hevoxagent/config.yml ] \
            && [ "$(md5sum /etc/hevoxagent/config.yml | awk '{print $1}')" = "$CONFIG_SUM" ]; then
            ok_line "Existing configuration preserved"
        else
            warn_line "Could not verify config.yml was left untouched — check /etc/hevoxagent/config.yml"
        fi
        if [ -n "$IDENTITY_SUM" ] && [ -f /var/lib/hevoxagent/identity.json ] \
            && [ "$(md5sum /var/lib/hevoxagent/identity.json | awk '{print $1}')" = "$IDENTITY_SUM" ]; then
            ok_line "Agent identity preserved"
        elif [ -z "$IDENTITY_SUM" ]; then
            warn_line "No prior identity.json found — this agent wasn't paired yet"
        else
            fail "Installing $LATEST_TAG" "identity.json changed or disappeared during upgrade — this must never happen, check $LOG_FILE and /var/lib/hevoxagent immediately"
        fi
        NEW_VERSION="$(dpkg-query -W -f='${Version}' "$PKG" 2>/dev/null || true)"
        if [ "$NEW_VERSION" = "$LATEST_VERSION" ]; then
            ok_line "Package upgraded"
        else
            warn_line "Installed version ($NEW_VERSION) doesn't match latest ($LATEST_VERSION)"
        fi

        step_header 3 4 "Restarting service"
        if [ "$WAS_ACTIVE" -eq 1 ]; then
            # packaging/debian/prerm stops the service on every upgrade
            # (not just remove/purge) and postinst only re-enables it, so
            # this restart is what actually brings a previously-running
            # agent back — without it, an update silently leaves it down.
            run_captured "systemctl restart $SERVICE" $SUDO systemctl restart "$SERVICE" \
                || fail "Restarting service" "${LAST_OUTPUT:-systemctl reported an error}"
            ok_line "hevoxagent.service restarted"
        else
            printf '      %s(was not running before the update — left stopped)%s\n' "$C_GRAY" "$C_RESET"
        fi

        step_header 4 4 "Verifying installation"
        info_line "Version" "v$NEW_VERSION"
        if [ "$WAS_ACTIVE" -eq 1 ]; then
            if systemctl is-active --quiet "$SERVICE"; then
                info_line "Service" "active"
            else
                info_line "Service" "${C_RED}not active${C_RESET}"
            fi
            if check_panel_reconnected; then
                info_line "Panel" "connected"
            else
                info_line "Panel" "${C_GRAY}unknown (check: journalctl -u hevoxagent)${C_RESET}"
            fi
        else
            info_line "Service" "stopped (unchanged)"
        fi

        printf '\n%s✓%s Hevox Agent updated successfully.\n' "$C_GREEN" "$C_RESET"
        printf '  v%s → %s\n' "$INSTALLED_VERSION" "$LATEST_TAG"
        ;;
esac

log_note "=== install.sh finished (mode=$MODE) ==="
