#!/bin/bash
# ============================================================
#  install_rmw_zenoh.sh
#  Sets up rmw_zenoh_cpp for ROS 2 Jazzy (router or sensor)
# ============================================================
 
set -e
 
# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
 
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }
ask()     { echo -e "${BOLD}$*${NC}"; }
 
# ── Banner ───────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}================================================${NC}"
echo -e "${CYAN}${BOLD}   RMW Zenoh installer for ROS 2 Jazzy${NC}"
echo -e "${CYAN}${BOLD}================================================${NC}"
echo ""
 
# ── 1. Sudo ──────────────────────────────────────────────────
ask "Give your sudo password (needed for apt):"
sudo -v || error "Sudo failed"
success "Sudo OK"
echo ""
 
# ── 2. Check ROS 2 ──────────────────────────────────────────
if [ ! -f /opt/ros/jazzy/setup.bash ]; then
    error "ROS 2 Jazzy not found at /opt/ros/jazzy. Please install it first."
fi
source /opt/ros/jazzy/setup.bash
success "ROS 2 Jazzy found"
echo ""
 
# ── 3. Install rmw_zenoh via apt ─────────────────────────────
info "Downloading and installing rmw_zenoh_cpp..."
sudo apt-get update -qq
sudo apt-get install -y ros-jazzy-rmw-zenoh-cpp
success "rmw_zenoh_cpp installed"
echo ""
 
# ── 4. Device role ──────────────────────────────────────────
echo -e "${BOLD}What is the role of this device?${NC}"
echo "  1) router  — runs the Zenoh router (typically your laptop/PC)"
echo "  2) sensor  — connects to the router (typically Rock Pi / robot)"
echo ""
read -rp "Enter 1 or 2: " ROLE_INPUT
 
case "$ROLE_INPUT" in
    1) ROLE="router" ;;
    2) ROLE="sensor" ;;
    *) error "Invalid choice. Enter 1 or 2." ;;
esac
 
success "Role: ${BOLD}${ROLE}${NC}"
echo ""
 
# ── 5. Config directory ──────────────────────────────────────
CONFIG_DIR="$HOME/.config/zenoh"
mkdir -p "$CONFIG_DIR"
info "Config directory: $CONFIG_DIR"
echo ""
 
# ── 6. Role-specific setup ───────────────────────────────────
 
if [ "$ROLE" = "router" ]; then
    # ── ROUTER ───────────────────────────────────────────────
 
    echo -e "${BOLD}Enter the IP address of THIS machine (router):${NC}"
    read -rp "Router IP [e.g. 192.168.1.250]: " ROUTER_IP
    [ -z "$ROUTER_IP" ] && error "IP cannot be empty"
 
    ROUTER_CFG="$CONFIG_DIR/router_config.json5"
 
    info "Writing router config to $ROUTER_CFG ..."
    cat > "$ROUTER_CFG" << EOF
{
  mode: "router",
 
  connect: {
    timeout_ms: { router: -1, peer: -1, client: 0 },
    endpoints: [],
    exit_on_failure: { router: false, peer: false, client: true },
    retry: {
      period_init_ms: 1000,
      period_max_ms:  4000,
      period_increase_factor: 2,
    },
  },
 
  listen: {
    timeout_ms: 0,
    endpoints: [
      "tcp/${ROUTER_IP}:7447"
    ],
    exit_on_failure: true,
    retry: {
      period_init_ms: 1000,
      period_max_ms:  4000,
      period_increase_factor: 2,
    },
  },
 
  scouting: {
    timeout: 3000,
    delay: 500,
    multicast: {
      enabled: false,
      address: "224.0.0.224:7446",
      interface: "auto",
      ttl: 1,
      autoconnect: { router: [], peer: ["router", "peer"], client: ["router"] },
    },
    gossip: {
      enabled: true,
      multihop: false,
    },
  },
 
  transport: {
    unicast: {
      lowlatency: false,
      qos: { enabled: true },
    },
    link: {
      tx: {
        sequence_number_resolution: "32bit",
        lease: 10000,
        keep_alive: 4,
        batch_size: 65535,
        queue: {
          size: {
            control: 2, real_time: 2,
            interactive_high: 2, interactive_low: 2,
            data_high: 2, data: 2, data_low: 2, background: 2,
          },
          congestion_control: {
            drop:  { wait_before_drop: 1000, max_wait_before_drop_fragments: 50000 },
            block: { wait_before_close: 5000000 },
          },
          batching: { enabled: true, time_limit: 1 },
        },
      },
      rx: {
        buffer_size: 65535,
        max_message_size: 1073741824,
      },
    },
    shared_memory: { enabled: false },
  },
 
  adminspace: {
    enabled: true,
    permissions: { read: true, write: false },
  },
}
EOF
    success "Router config written"
    echo ""
 
    # ── env vars for router ───────────────────────────────────
    ENV_BLOCK=$(cat << EOF
 
# --- rmw_zenoh (router) ---
export RMW_IMPLEMENTATION=rmw_zenoh_cpp
export ZENOH_ROUTER_CONFIG_URI=${ROUTER_CFG}
EOF
)
 
else
    # ── SENSOR ───────────────────────────────────────────────
 
    echo -e "${BOLD}Enter the IP address of THIS device (sensor):${NC}"
    read -rp "Sensor IP [e.g. 192.168.1.156]: " SENSOR_IP
    [ -z "$SENSOR_IP" ] && error "IP cannot be empty"
 
    echo -e "${BOLD}Enter the IP address of the ROUTER (laptop):${NC}"
    read -rp "Router IP [e.g. 192.168.1.250]: " ROUTER_IP
    [ -z "$ROUTER_IP" ] && error "Router IP cannot be empty"
 
    SESSION_CFG="$CONFIG_DIR/session_config.json5"
 
    info "Writing session config to $SESSION_CFG ..."
    cat > "$SESSION_CFG" << EOF
{
  mode: "client",
 
  connect: {
    timeout_ms: { router: -1, peer: -1, client: 0 },
    endpoints: [
      "tcp/${ROUTER_IP}:7447"
    ],
    exit_on_failure: { router: false, peer: false, client: true },
    retry: {
      period_init_ms: 1000,
      period_max_ms:  4000,
      period_increase_factor: 2,
    },
  },
 
  listen: {
    timeout_ms: 0,
    endpoints: [
      "tcp/${SENSOR_IP}:0"
    ],
    exit_on_failure: false,
    retry: {
      period_init_ms: 1000,
      period_max_ms:  4000,
      period_increase_factor: 2,
    },
  },
 
  scouting: {
    timeout: 3000,
    delay: 500,
    multicast: {
      enabled: false,
      address: "224.0.0.224:7446",
      interface: "auto",
      ttl: 1,
      autoconnect: { router: [], peer: ["router", "peer"], client: ["router"] },
    },
    gossip: {
      enabled: true,
      multihop: false,
    },
  },
 
  transport: {
    unicast: {
      lowlatency: false,
      qos: { enabled: true },
    },
    link: {
      tx: {
        sequence_number_resolution: "32bit",
        lease: 10000,
        keep_alive: 4,
        batch_size: 65535,
        queue: {
          size: {
            control: 2, real_time: 2,
            interactive_high: 2, interactive_low: 2,
            data_high: 2, data: 2, data_low: 2, background: 2,
          },
          congestion_control: {
            drop:  { wait_before_drop: 1000, max_wait_before_drop_fragments: 50000 },
            block: { wait_before_close: 60000000 },
          },
          batching: { enabled: true, time_limit: 1 },
        },
      },
      rx: {
        buffer_size: 65535,
        max_message_size: 1073741824,
      },
    },
    shared_memory: { enabled: false },
  },
 
  adminspace: {
    enabled: true,
    permissions: { read: true, write: false },
  },
}
EOF
    success "Session config written"
    echo ""
 
    # ── env vars for sensor ───────────────────────────────────
    ENV_BLOCK=$(cat << EOF
 
# --- rmw_zenoh (sensor/client) ---
export RMW_IMPLEMENTATION=rmw_zenoh_cpp
export ZENOH_SESSION_CONFIG_URI=${SESSION_CFG}
EOF
)
 
fi
 
# ── 7. Write env vars to ~/.bashrc ───────────────────────────
info "Writing environment variables to ~/.bashrc ..."
 
# Remove old zenoh block if exists
sed -i '/# --- rmw_zenoh/,/^$/d' ~/.bashrc 2>/dev/null || true
 
echo "$ENV_BLOCK" >> ~/.bashrc
success "Environment variables added to ~/.bashrc"
echo ""
 
# ── 8. Source ROS in ~/.bashrc if not already there ──────────
if ! grep -q "source /opt/ros/jazzy/setup.bash" ~/.bashrc; then
    echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
    info "Added 'source /opt/ros/jazzy/setup.bash' to ~/.bashrc"
fi
 
# ── 9. Apply to current shell ────────────────────────────────
eval "$ENV_BLOCK"
source /opt/ros/jazzy/setup.bash
 
# ── 10. Summary ──────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}================================================${NC}"
echo -e "${GREEN}${BOLD}  Installation complete!${NC}"
echo -e "${CYAN}${BOLD}================================================${NC}"
echo ""
echo -e "  Role:   ${BOLD}${ROLE}${NC}"
 
if [ "$ROLE" = "router" ]; then
    echo -e "  Config: ${BOLD}${ROUTER_CFG}${NC}"
    echo -e "  Listen: ${BOLD}tcp://${ROUTER_IP}:7447${NC}"
    echo ""
    echo -e "${BOLD}To start the Zenoh router:${NC}"
    echo -e "  ${CYAN}source ~/.bashrc${NC}"
    echo -e "  ${CYAN}ros2 run rmw_zenoh_cpp rmw_zenohd${NC}"
else
    echo -e "  Config: ${BOLD}${SESSION_CFG}${NC}"
    echo -e "  Router: ${BOLD}tcp://${ROUTER_IP}:7447${NC}"
    echo ""
    echo -e "${BOLD}Run your nodes normally:${NC}"
    echo -e "  ${CYAN}source ~/.bashrc${NC}"
    echo -e "  ${CYAN}ros2 run <package> <node>${NC}"
fi
 
echo ""
warn "Don't forget to 'source ~/.bashrc' in every new terminal!"
echo ""
