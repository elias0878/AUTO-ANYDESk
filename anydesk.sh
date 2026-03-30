#!/bin/bash
# Unified AnyDesk Setup - Complete Desktop with Auto-Approval
# Password: LOve0878

set +e

# Configuration
PASSWORD="LOve0878"
LOG_FILE="/var/log/anydesk_setup.log"
SETTINGS_DIR="/root/.anydesk"
SETTINGS_FILE="$SETTINGS_DIR/system.conf"
DISPLAY_NUM=":0"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "This script must be run as root. Attempting to elevate..."
        if command -v sudo >/dev/null 2>&1; then
            exec sudo "$0" "$@"
        else
            log "ERROR: This script requires root privileges"
            exit 1
        fi
    fi
}

# Kill existing processes
kill_existing() {
    log "Stopping existing processes..."
    pkill -f "/usr/bin/anydesk" 2>/dev/null || true
    pkill -f "/usr/local/bin/anydesk" 2>/dev/null || true
    pkill -x "anydesk" 2>/dev/null || true
    pkill -f "Xvfb.*:0" 2>/dev/null || true
    pkill -f "Xvfb.*:99" 2>/dev/null || true
    pkill -x "fluxbox" 2>/dev/null || true
    pkill -x "xterm" 2>/dev/null || true
    systemctl stop anydesk 2>/dev/null || true
    sleep 2
    log "Processes stopped"
}

# Detect package manager
detect_package_manager() {
    if command -v apt >/dev/null 2>&1; then
        PKG_MGR="apt"
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt-get"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MGR="yum"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    else
        PKG_MGR="none"
    fi
    log "Detected package manager: $PKG_MGR"
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    if command -v Xvfb >/dev/null 2>&1 && command -v fluxbox >/dev/null 2>&1; then
        log "Dependencies already installed."
        return 0
    fi
    case $PKG_MGR in
        apt|apt-get)
            apt update 2>/dev/null || true
            apt install -y wget curl xvfb x11-xserver-utils fluxbox xterm 2>/dev/null || true
            ;;
        yum)
            yum install -y wget curl xorg-x11-server-Xvfb 2>/dev/null || true
            ;;
        dnf)
            dnf install -y wget curl xorg-x11-server-Xvfb 2>/dev/null || true
            ;;
    esac
}

# Install AnyDesk
install_anydesk() {
    log "Installing AnyDesk..."
    if command -v anydesk >/dev/null 2>&1; then
        log "AnyDesk is already installed"
        return 0
    fi
    case $PKG_MGR in
        apt|apt-get)
            if [ ! -f /etc/apt/sources.list.d/anydesk-stable.list ]; then
                wget -qO - https://keys.anydesk.com/repos/DEB-GPG-KEY | apt-key add - 2>/dev/null || {
                    mkdir -p /etc/apt/keyrings 2>/dev/null || true
                    wget -qO - https://keys.anydesk.com/repos/DEB-GPG-KEY | gpg --dearmor -o /etc/apt/keyrings/anydesk.gpg 2>/dev/null || true
                }
                if [ -f /etc/apt/keyrings/anydesk.gpg ]; then
                    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/anydesk.gpg] http://deb.anydesk.com/ all main" > /etc/apt/sources.list.d/anydesk-stable.list
                else
                    echo "deb http://deb.anydesk.com/ all main" > /etc/apt/sources.list.d/anydesk-stable.list
                fi
            fi
            apt update 2>/dev/null || true
            apt install -y anydesk 2>/dev/null || {
                mkdir -p /tmp/anydesk_install && cd /tmp/anydesk_install
                wget -O anydesk.deb "https://download.anydesk.com/linux/anydesk_6.3.2-1_amd64.deb" 2>/dev/null && {
                    dpkg -i anydesk.deb 2>/dev/null || apt-get install -f -y 2>/dev/null
                }
                cd / && rm -rf /tmp/anydesk_install
            }
            ;;
        yum|dnf)
            rpm --import https://keys.anydesk.com/repos/RPM-GPG-KEY 2>/dev/null || true
            $PKG_MGR install -y https://download.anydesk.com/linux/anydesk.repo 2>/dev/null || true
            $PKG_MGR install -y anydesk 2>/dev/null || {
                mkdir -p /tmp/anydesk_install && cd /tmp/anydesk_install
                wget -O anydesk.rpm "https://download.anydesk.com/linux/anydesk-6.3.2-1.el8.x86_64.rpm" 2>/dev/null && {
                    rpm -ivh anydesk.rpm 2>/dev/null || $PKG_MGR install -y anydesk.rpm 2>/dev/null
                }
                cd / && rm -rf /tmp/anydesk_install
            }
            ;;
    esac
    if ! command -v anydesk >/dev/null 2>&1; then
        log "ERROR: AnyDesk installation failed"
        exit 1
    fi
    log "AnyDesk installed successfully"
}

# Setup main desktop display
setup_desktop() {
    log "Setting up main desktop on display $DISPLAY_NUM..."

    XAUTH_FILE=$(mktemp)
    export XAUTHORITY="$XAUTH_FILE"

    mcookie | xargs -I {} xauth add "$DISPLAY_NUM" . {} 2>/dev/null || true

    Xvfb "$DISPLAY_NUM" -screen 0 1920x1080x24 -ac +extension GLX +render -noreset -auth "$XAUTH_FILE" >/dev/null 2>&1 &
    sleep 3

    export DISPLAY="$DISPLAY_NUM"
    echo "$XAUTH_FILE" > /tmp/anydesk_xauth_file 2>/dev/null || true

    # Set desktop background
    xsetroot -solid "#2c3e50" 2>/dev/null || true

    # Start XFCE desktop (most reliable for headless)
    if command -v xfce4-session >/dev/null 2>&1; then
        log "Starting XFCE desktop (Kali default)..."
        DISPLAY="$DISPLAY_NUM" xfce4-session >/dev/null 2>&1 &
        sleep 5
    # Fallback to GNOME
    elif command -v gnome-session >/dev/null 2>&1; then
        log "Starting GNOME desktop..."
        DISPLAY="$DISPLAY_NUM" gnome-session --systemd-disable --disable-acceleration-check >/dev/null 2>&1 &
        sleep 5
    # Fallback to fluxbox
    elif command -v fluxbox >/dev/null 2>&1; then
        log "Starting Fluxbox desktop..."
        DISPLAY="$DISPLAY_NUM" fluxbox >/dev/null 2>&1 &
        sleep 1
    fi

    # Create main system terminal
    if command -v xfce4-terminal >/dev/null 2>&1; then
        DISPLAY="$DISPLAY_NUM" xfce4-terminal --geometry=100x30+50+50 --command="bash -c '
            echo \"========================================\"
            echo \"  KALI LINUX - MAIN DESKTOP\"
            echo \"========================================\"
            echo \"\"
            echo \"Hostname: \$(hostname)\"
            echo \"Kernel: \$(uname -r)\"
            echo \"Uptime: \$(uptime -p 2>/dev/null || uptime)\"
            echo \"\"
            echo \"Network:\"
            ip -br addr 2>/dev/null || ifconfig 2>/dev/null || echo \"  No network info\"
            echo \"\"
            echo \"Security Tools:\"
            dpkg -l | grep -E \"^ii.*(kali|metasploit|wireshark|nmap|aircrack|john|hydra|burp|sqlmap|nikto)\" | head -15
            echo \"\"
            echo \"========================================\"
            echo \"Type commands or press Ctrl+D for bash\"
            echo \"========================================\"
            echo \"\"
            exec bash
        '" &
    elif command -v gnome-terminal >/dev/null 2>&1; then
        DISPLAY="$DISPLAY_NUM" gnome-terminal --geometry=100x30+50+50 -- /bin/bash -c '
            echo "========================================"
            echo "  KALI LINUX - MAIN DESKTOP"
            echo "========================================"
            echo ""
            echo "Hostname: $(hostname)"
            echo "Kernel: $(uname -r)"
            echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
            echo ""
            echo "Network:"
            ip -br addr 2>/dev/null || ifconfig 2>/dev/null || echo "  No network info"
            echo ""
            echo "Security Tools:"
            dpkg -l | grep -E "^ii.*(kali|metasploit|wireshark|nmap|aircrack|john|hydra|burp|sqlmap|nikto)" | head -15
            echo ""
            echo "========================================"
            echo "Type commands or press Ctrl+D for bash"
            echo "========================================"
            echo ""
            exec bash
        ' &
    elif command -v xterm >/dev/null 2>&1; then
        DISPLAY="$DISPLAY_NUM" xterm -geometry 100x30+50+50 -bg "#1a1a2e" -fg "#00ff00" -fa "Monospace" -fs 12 \
            -e "bash -c '
            echo \"========================================\"
            echo \"  KALI LINUX - MAIN DESKTOP\"
            echo \"========================================\"
            echo \"\"
            echo \"Hostname: \$(hostname)\"
            echo \"Kernel: \$(uname -r)\"
            echo \"Uptime: \$(uptime -p 2>/dev/null || uptime)\"
            echo \"\"
            echo \"Network:\"
            ip -br addr 2>/dev/null || ifconfig 2>/dev/null || echo \"  No network info\"
            echo \"\"
            echo \"Security Tools:\"
            dpkg -l | grep -E \"^ii.*(kali|metasploit|wireshark|nmap|aircrack|john|hydra|burp|sqlmap|nikto)\" | head -15
            echo \"\"
            echo \"========================================\"
            echo \"Type commands or press Ctrl+D for bash\"
            echo \"========================================\"
            echo \"\"
            exec bash
            ' " &
    fi

    # Start file manager daemon if available
    if command -v thunar >/dev/null 2>&1; then
        DISPLAY="$DISPLAY_NUM" thunar --daemon &
    elif command -v nautilus >/dev/null 2>&1; then
        DISPLAY="$DISPLAY_NUM" nautilus --daemon &
    fi

    sleep 3
    log "Main desktop ready on $DISPLAY_NUM (1920x1080)"
}

# Configure AnyDesk
configure_anydesk() {
    log "Configuring AnyDesk for full privileges and auto-approval..."

    mkdir -p "$SETTINGS_DIR"
    CONFIG_FILE="$SETTINGS_DIR/system.conf"
    TEMP_CONFIG=$(mktemp)

    # Preserve existing ID if present
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%s)" 2>/dev/null || true
        grep -E "^ad\.anynet\.(id|alias|network_id)" "$CONFIG_FILE" > "$TEMP_CONFIG" 2>/dev/null || true
    fi

    # Create configuration
    {
        cat "$TEMP_CONFIG" 2>/dev/null || true
        echo "ad.anynet.security.confirm_connections=0"
        echo "ad.anynet.security.interactive_access=1"
        echo "ad.anynet.security.unattended_access.enabled=1"
        echo "ad.anynet.security.allow_clients=1"
        echo "ad.anynet.security.auto_trust_clients=1"
        echo "ad.anynet.security.auto_trust_new_clients=1"
        echo "ad.anynet.security.incoming_requires_password=1"
        echo "ad.anynet.security.trusted_clients.enabled=1"
        echo "ad.anynet.security.trusted_clients.auto_trust_new_clients=1"
        echo "ad.anynet.security.trusted_clients.auto_trust_clients=1"
        echo "ad.anynet.security.accept_incoming=1"
        echo "ad.anynet.permissions=1"
        echo "ad.anynet.ui.enable_tray_icon=1"
        echo "ad.anynet.ui.show_notifications=1"
        echo "ad.anynet.network.upnp=1"
    } > "$CONFIG_FILE"

    rm -f "$TEMP_CONFIG"
    log "Configuration file created"

    # Start AnyDesk
    log "Starting AnyDesk service..."
    export QT_QPA_PLATFORM=offscreen
    DISPLAY="$DISPLAY_NUM" QT_QPA_PLATFORM=offscreen nohup anydesk --service --silent >/dev/null 2>&1 &
    sleep 5

    # Wait for service
    COUNT=0
    while [ $COUNT -lt 30 ]; do
        if DISPLAY="$DISPLAY_NUM" anydesk --get-id >/dev/null 2>&1; then
            break
        fi
        sleep 1
        COUNT=$((COUNT + 1))
    done

    if [ $COUNT -eq 30 ]; then
        log "ERROR: AnyDesk failed to start"
        exit 1
    fi

    # Set password
    log "Setting password..."
    if echo "$PASSWORD" | DISPLAY="$DISPLAY_NUM" QT_QPA_PLATFORM=offscreen anydesk --set-password >/dev/null 2>&1; then
        log "Password set successfully"
    elif echo "$PASSWORD" | DISPLAY="$DISPLAY_NUM" QT_QPA_PLATFORM=offscreen anydesk --set-password - >/dev/null 2>&1; then
        log "Password set successfully (with stdin flag)"
    else
        log "WARNING: Failed to set password. May need manual setup."
    fi
    sleep 2

    # Restart to apply settings
    log "Restarting to apply all settings..."
    pkill -f "/usr/bin/anydesk" 2>/dev/null || true
    pkill -x "anydesk" 2>/dev/null || true
    sleep 2
    DISPLAY="$DISPLAY_NUM" QT_QPA_PLATFORM=offscreen nohup anydesk --service --silent >/dev/null 2>&1 &
    sleep 5

    # Verify
    COUNT=0
    while [ $COUNT -lt 30 ]; do
        if DISPLAY="$DISPLAY_NUM" anydesk --get-id >/dev/null 2>&1; then
            ID=$(DISPLAY="$DISPLAY_NUM" anydesk --get-id)
            log "AnyDesk configured successfully with ID: $ID"
            return 0
        fi
        sleep 1
        COUNT=$((COUNT + 1))
    done

    log "ERROR: AnyDesk configuration failed"
    exit 1
}

# Fix firewall
fix_firewall() {
    log "Configuring firewall..."
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 7070/tcp 2>/dev/null || true
        ufw allow 7070/udp 2>/dev/null || true
    fi
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=7070/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=7070/udp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
    fi
}

# Display credentials and wait
display_credentials() {
    sleep 2

    if DISPLAY="$DISPLAY_NUM" anydesk --get-id >/dev/null 2>&1; then
        ID=$(DISPLAY="$DISPLAY_NUM" anydesk --get-id)
    else
        log "ERROR: Could not retrieve AnyDesk ID"
        exit 1
    fi

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     ANYDESK MAIN DESKTOP - READY FOR CONNECTIONS             ║"
    echo "║                                                              ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║                                                              ║"
    printf "║  AnyDesk ID:   %-45s ║\n" "$ID"
    printf "║  Password:     %-45s ║\n" "$PASSWORD"
    echo "║  Display:      :0 (Main Desktop - 1920x1080)                 ║"
    echo "║                                                              ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║                                                              ║"
    echo "║  ✓ Full Desktop: Fluxbox Window Manager                      ║"
    echo "║  ✓ System Terminal: Live system information                  ║"
    echo "║  ✓ Full Privileges: ENABLED                                  ║"
    echo "║  ✓ Auto-Approval: ENABLED                                    ║"
    echo "║  ✓ Password Required: YES                                    ║"
    echo "║                                                              ║"
    echo "║  CONNECTION PROCESS:                                         ║"
    echo "║  1. Remote user enters ID: $ID"
    echo "║  2. Enter password: $PASSWORD"
    echo "║  3. Connection AUTOMATICALLY APPROVED                        ║"
    echo "║  4. Full privileges granted                                  ║"
    echo "║                                                              ║"
    echo "║  STATUS: READY - Waiting for incoming connections...         ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    log "=== SESSION READY ==="
    log "ID: $ID | Password: $PASSWORD"
    log "Waiting for connections..."

    # Monitor and keep service running
    while true; do
        sleep 30
        if ! DISPLAY="$DISPLAY_NUM" anydesk --get-id >/dev/null 2>&1; then
            log "Service stopped, restarting..."
            pkill -f "/usr/bin/anydesk" 2>/dev/null || true
            pkill -x "anydesk" 2>/dev/null || true
            sleep 2
            DISPLAY="$DISPLAY_NUM" QT_QPA_PLATFORM=offscreen nohup anydesk --service --silent >/dev/null 2>&1 &
            sleep 5
        fi
    done
}

# Main function
main() {
    log "========================================="
    log "Unified AnyDesk Desktop Setup"
    log "Password: $PASSWORD"
    log "========================================="

    check_root "$@"
    kill_existing
    detect_package_manager
    install_dependencies
    install_anydesk
    setup_desktop
    configure_anydesk
    fix_firewall
    display_credentials
}

# Run main
main "$@"
