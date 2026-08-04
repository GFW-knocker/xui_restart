#!/usr/bin/env bash
#
# xui_restart — one-line installer for Ubuntu/Debian VPS
# Repo: https://github.com/GFW-knocker/xui_restart
#
# Installs a boot-persistent systemd service that runs the RAM/CPU watchdog,
# plus a "xui-restart" management command (status + log + menu).
#
#   Install / update:
#     bash <(curl -fsSL https://raw.githubusercontent.com/GFW-knocker/xui_restart/main/install.sh)
#
set -euo pipefail

# ---------------------------------------------------------------- config -----
SERVICE="xui-restart"
APPDIR="/opt/xui-restart"
PYFILE="$APPDIR/xui_restart.py"
BIN="/usr/local/bin/xui-restart"
UNIT="/etc/systemd/system/${SERVICE}.service"

REPO_RAW="https://raw.githubusercontent.com/GFW-knocker/xui_restart/main"
RAW_PY="${REPO_RAW}/xui_restart.py"
RAW_INSTALL="${REPO_RAW}/install.sh"

# ------------------------------------------------------------- pretty io -----
if [ -t 1 ]; then
    G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'
else
    G=; Y=; R=; C=; B=; N=;
fi
say()  { echo -e "${C}::${N} $*"; }
ok()   { echo -e "${G}==>${N} $*"; }
warn() { echo -e "${Y}!!${N} $*"; }
die()  { echo -e "${R}xx${N} $*" >&2; exit 1; }

# --------------------------------------------------------------- prereqs -----
# Must be root. When piped (curl | bash) we cannot re-exec $0, so re-fetch under sudo.
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        warn "Not root — re-running with sudo..."
        exec sudo -E bash -c "$(curl -fsSL "$RAW_INSTALL")"
    fi
    die "Please run as root:  sudo bash -c \"\$(curl -fsSL $RAW_INSTALL)\""
fi

command -v apt-get >/dev/null 2>&1 || die "This installer targets Ubuntu/Debian (apt not found)."

echo -e "${B}"
echo "  ┌──────────────────────────────────────────────┐"
echo "  │   xui_restart  ·  installer                    │"
echo "  │   RAM/CPU watchdog for x-ui / xray VPS         │"
echo "  └──────────────────────────────────────────────┘"
echo -e "${N}"

# ------------------------------------------- python + dependency checks ------
# Policy: only CHECK Python — never modify or upgrade an existing interpreter.
# Install python3 / psutil / pytz ONLY when they are missing. If everything is
# already present, apt is never invoked at all.
export DEBIAN_FRONTEND=noninteractive
APT_UPDATED=0
apt_update_once() {
    if [ "$APT_UPDATED" -eq 0 ]; then
        apt-get update -y -qq
        APT_UPDATED=1
    fi
    return 0
}

# --- Python: check only; install just python3 if it does not exist. ---
if command -v python3 >/dev/null 2>&1; then
    PYBIN="$(command -v python3)"
    ok "Python found: ${PYBIN} (v$("$PYBIN" -c 'import platform;print(platform.python_version())')) — leaving it untouched."
else
    warn "Python 3 not found — installing python3..."
    apt_update_once
    apt-get install -y -qq python3
    PYBIN="$(command -v python3)" || die "python3 installation failed."
    ok "Installed ${PYBIN}"
fi

# --- curl: needed to fetch the watchdog / run updates; install only if absent. ---
if ! command -v curl >/dev/null 2>&1; then
    warn "curl not found — installing curl..."
    apt_update_once
    apt-get install -y -qq curl
fi

# --- Requirements: install ONLY the package(s) that are actually missing. ---
MISSING=()
"$PYBIN" -c 'import psutil' >/dev/null 2>&1 || MISSING+=("psutil")
"$PYBIN" -c 'import pytz'   >/dev/null 2>&1 || MISSING+=("pytz")

if [ "${#MISSING[@]}" -eq 0 ]; then
    ok "Requirements already present (psutil + pytz) — leaving them untouched."
else
    warn "Missing python package(s): ${MISSING[*]} — installing only these..."
    apt_update_once
    for pkg in "${MISSING[@]}"; do
        # distro packages avoid PEP 668 'externally-managed' errors
        apt-get install -y -qq "python3-${pkg}" || true
    done

    # If apt could not provide them, fall back to an isolated virtualenv.
    # (System Python is still NOT modified — the venv only uses it as its base.)
    if ! "$PYBIN" -c 'import psutil, pytz' >/dev/null 2>&1; then
        warn "apt could not provide them — using an isolated virtualenv instead..."
        apt_update_once
        apt-get install -y -qq python3-venv python3-pip
        mkdir -p "$APPDIR"
        "$PYBIN" -m venv "$APPDIR/venv"
        "$APPDIR/venv/bin/pip" install --quiet --upgrade pip
        "$APPDIR/venv/bin/pip" install --quiet psutil pytz
        PYBIN="$APPDIR/venv/bin/python3"
    fi
fi

"$PYBIN" -c 'import psutil, pytz' >/dev/null 2>&1 \
    || die "Could not satisfy requirements (psutil, pytz). Check network/apt."
ok "Requirements OK — service will use interpreter: ${PYBIN}"

# ------------------------------------------------ fetch watchdog script ------
say "Fetching watchdog script..."
mkdir -p "$APPDIR"
curl -fsSL "$RAW_PY" -o "$PYFILE" || die "Failed to download xui_restart.py"
chmod 644 "$PYFILE"
ok "Installed $PYFILE"

# ------------------------------------------------ write systemd service ------
say "Writing systemd service..."
cat > "$UNIT" <<UNIT_EOF
[Unit]
Description=xui_restart — kill xray on high RAM/CPU so x-ui restarts it (free memory before swap)
Documentation=https://github.com/GFW-knocker/xui_restart
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APPDIR}
ExecStart=${PYBIN} -u ${PYFILE}
Restart=always
RestartSec=5
MemoryAccounting=yes
SyslogIdentifier=${SERVICE}

[Install]
WantedBy=multi-user.target
UNIT_EOF
ok "Wrote $UNIT"

# ------------------------------------------------ install manager CLI --------
say "Installing 'xui-restart' command..."
# Write to a temp file and atomically mv into place, so that an in-progress
# `xui-restart` (e.g. the Update action) keeps running from its old inode.
cat > "${BIN}.tmp" <<'CLI_EOF'
#!/usr/bin/env bash
#
# xui-restart — manager for the xui_restart watchdog service
# Repo: https://github.com/GFW-knocker/xui_restart
#
set -uo pipefail

SERVICE="xui-restart"
APPDIR="/opt/xui-restart"
PYFILE="$APPDIR/xui_restart.py"
LOGFILE="$APPDIR/restart_log.txt"
RAW_INSTALL="https://raw.githubusercontent.com/GFW-knocker/xui_restart/main/install.sh"

if [ -t 1 ]; then
    G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'
else
    G=; Y=; R=; C=; B=; N=;
fi

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

is_active()  { systemctl is-active  --quiet "$SERVICE"; }
is_enabled() { systemctl is-enabled --quiet "$SERVICE" 2>/dev/null; }

print_status() {
    local act ena pid mem since
    if is_active;  then act="${G}● active (running)${N}"; else act="${R}○ inactive (stopped)${N}"; fi
    if is_enabled; then ena="${G}enabled${N}";            else ena="${Y}disabled${N}";            fi
    pid=$(systemctl show -p MainPID --value "$SERVICE" 2>/dev/null); [ -z "$pid" ] && pid=0
    mem=$(systemctl show -p MemoryCurrent --value "$SERVICE" 2>/dev/null)
    since=$(systemctl show -p ActiveEnterTimestamp --value "$SERVICE" 2>/dev/null)
    if [ -n "$mem" ] && [ "$mem" != "[not set]" ] && [ "$mem" -gt 0 ] 2>/dev/null; then
        mem="$(awk -v b="$mem" 'BEGIN{printf "%.1f MB", b/1048576}')"
    else
        mem="-"
    fi
    echo -e " Service : $act    start-on-boot: $ena"
    if [ "$pid" != "0" ]; then
        echo -e " PID     : ${C}${pid}${N}    Mem: ${C}${mem}${N}"
        [ -n "${since:-}" ] && echo -e " Since   : ${since}"
    fi
}

print_log() {
    echo -e "${B}Recent restart events${N}  (${LOGFILE}):"
    if [ -s "$LOGFILE" ]; then
        tail -n 10 "$LOGFILE" | sed 's/^/   /'
    else
        echo "   (no restarts logged yet — good, RAM/CPU has stayed under threshold)"
    fi
}

do_start()   { echo "Starting...";   $SUDO systemctl start   "$SERVICE" && echo -e "${G}Started.${N}"; }
do_stop()    { echo "Stopping...";   $SUDO systemctl stop    "$SERVICE" && echo -e "${Y}Stopped.${N}"; }
do_restart() { echo "Restarting..."; $SUDO systemctl restart "$SERVICE" && echo -e "${G}Restarted.${N}"; }

do_update() {
    echo "Updating from GitHub (watchdog + service + this menu)..."
    if $SUDO bash -c "curl -fsSL '$RAW_INSTALL' | bash"; then
        # This script file was just replaced on disk; exit rather than
        # continue executing the stale in-memory copy.
        echo -e "${G}Update complete.${N} Re-open the menu with:  xui-restart"
        exit 0
    else
        echo -e "${R}Update failed — check network.${N}"
    fi
}

do_servicelog() {
    echo -e "${B}Last 50 service log lines${N} (journalctl -u $SERVICE):"
    echo "-----------------------------------------------------------"
    $SUDO journalctl -u "$SERVICE" -n 50 --no-pager
    echo "-----------------------------------------------------------"
    echo "Tip: follow live with:  journalctl -u $SERVICE -f"
}

do_uninstall() {
    read -rp "Really uninstall xui-restart and delete $APPDIR? [y/N] " a
    case "${a:-}" in
        y|Y)
            $SUDO systemctl disable --now "$SERVICE" 2>/dev/null
            $SUDO rm -f "/etc/systemd/system/${SERVICE}.service"
            $SUDO systemctl daemon-reload
            $SUDO rm -rf "$APPDIR"
            $SUDO rm -f "/usr/local/bin/xui-restart"
            echo -e "${G}Uninstalled.${N} Goodbye."
            exit 0 ;;
        *) echo "Cancelled." ;;
    esac
}

banner() {
    echo -e "${B}"
    echo "==============================================="
    echo "        xui-restart   ·   manager"
    echo "==============================================="
    echo -e "${N}"
}

menu() {
    while true; do
        clear 2>/dev/null || true
        banner
        print_status
        echo "-----------------------------------------------"
        print_log
        echo "==============================================="
        echo "  1) Start                4) Update (GitHub)"
        echo "  2) Stop                 5) View service log"
        echo "  3) Restart              6) Uninstall"
        echo "  0) Exit"
        echo "==============================================="
        read -rp " Select an option: " ch
        echo
        case "${ch:-}" in
            1) do_start ;;
            2) do_stop ;;
            3) do_restart ;;
            4) do_update ;;
            5) do_servicelog ;;
            6) do_uninstall ;;
            0|q|Q) exit 0 ;;
            *) echo "Invalid choice." ;;
        esac
        echo
        read -rp " Press Enter to continue..." _ || exit 0
    done
}

usage() {
    cat <<USAGE
xui-restart — manage the xui_restart watchdog service

Usage:
  xui-restart               open the interactive menu (status + log)
  xui-restart status        show status and recent restart events
  xui-restart start         start the service
  xui-restart stop          stop the service
  xui-restart restart       restart the service
  xui-restart update        pull the latest version from GitHub
  xui-restart log           show the last 50 service log lines
  xui-restart uninstall     remove the service and all files
USAGE
}

case "${1:-menu}" in
    ""|menu)     menu ;;
    status|st)   print_status; echo; print_log ;;
    start)       do_start ;;
    stop)        do_stop ;;
    restart)     do_restart ;;
    update|up)   do_update ;;
    log|logs)    do_servicelog ;;
    uninstall|remove) do_uninstall ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
esac
CLI_EOF
chmod +x "${BIN}.tmp"
mv -f "${BIN}.tmp" "$BIN"
ok "Installed $BIN"

# ------------------------------------------------------- enable + start ------
say "Enabling service (start on boot) and launching..."
systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null 2>&1 || true
systemctl restart "$SERVICE"

sleep 1
echo
if systemctl is-active --quiet "$SERVICE"; then
    ok "${G}xui_restart is running and will start automatically on boot.${N}"
else
    warn "Service installed but not active yet — check:  journalctl -u $SERVICE -n 30"
fi

echo
echo -e "${B}Done.${N} Manage it anytime with:  ${C}xui-restart${N}"
echo "  (opens status + last-10 log + menu: start / stop / restart / update / uninstall)"
echo
