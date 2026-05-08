#!/bin/bash
set -euo pipefail
 
# ─────────────────────────────────────────────────────────────────
#  Docker + ROS 2 Jazzy — установка на Debian Trixie (RPi 4/5)
#  Запуск: bash install_docker_ros2.sh
# ─────────────────────────────────────────────────────────────────
 
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
 
log()  { echo -e "${CYAN}[DOCKER]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail() { echo -e "${RED}[ERR]${NC}   $*"; exit 1; }
 
if [[ $EUID -eq 0 ]]; then
    fail "Не запускайте через sudo. Запустите как обычный пользователь: bash install_docker_ros2.sh"
fi
 
echo -e "\n${CYAN}╔════════════════════════════════════════════════════════╗"
echo -e "║   Docker + ROS 2 Jazzy  |  Debian Trixie  |  RPi 4/5   ║"
echo -e "╚════════════════════════════════════════════════════════╝${NC}\n"
 
# ── Один запрос sudo + keepalive ──────────────────────────────────────────────
log "Запрашиваю sudo..."
sudo -v || fail "Не удалось получить права sudo"
( while true; do sudo -n true; sleep 50; done ) 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill $SUDO_KEEPALIVE 2>/dev/null' EXIT INT TERM
 
# ── Проверка архитектуры ──────────────────────────────────────────────────────
ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" != "arm64" ]]; then
    warn "Ожидалась arm64 (RPi 4/5), обнаружена: $ARCH — продолжаю, но образ может не подойти"
fi
ok "Архитектура: $ARCH"
 
# ── 1. Зависимости ────────────────────────────────────────────────────────────
log "Устанавливаю зависимости..."
sudo apt-get update -qq
sudo apt-get install -y \
    ca-certificates curl gnupg lsb-release \
    apt-transport-https software-properties-common
ok "Зависимости установлены"
 
# ── 2. GPG-ключ Docker ────────────────────────────────────────────────────────
log "Добавляю GPG-ключ Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
ok "GPG-ключ добавлен"
 
# ── 3. Репозиторий Docker ─────────────────────────────────────────────────────
log "Добавляю репозиторий Docker..."
# Debian Trixie = codename "trixie"
DEBIAN_CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-trixie}")
echo \
    "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian ${DEBIAN_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
ok "Репозиторий: debian/${DEBIAN_CODENAME}"
 
# ── 4. Установка Docker ───────────────────────────────────────────────────────
log "Устанавливаю Docker Engine..."
sudo apt-get update -qq
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
ok "Docker установлен: $(docker --version)"
 
# ── 5. Текущий пользователь в группу docker ───────────────────────────────────
log "Добавляю пользователя '${USER}' в группу docker..."
if groups "$USER" | grep -q '\bdocker\b'; then
    warn "Пользователь уже в группе docker"
else
    sudo usermod -aG docker "$USER"
    ok "Добавлен. После установки выполните: newgrp docker  (или перелогиньтесь)"
fi
 
# ── 6. Запуск и автозапуск Docker ────────────────────────────────────────────
log "Запускаю Docker daemon..."
sudo systemctl enable --now docker
sudo systemctl enable --now containerd
ok "Docker запущен: $(sudo systemctl is-active docker)"
 
# ── 7. Pull образа ROS 2 Jazzy ────────────────────────────────────────────────
# Официальный образ osrf/ros:jazzy-ros-base-noble (~400 МБ, arm64)
ROS_IMAGE="osrf/ros:jazzy-ros-base-noble"
log "Скачиваю образ ${ROS_IMAGE} (может занять несколько минут)..."
sudo docker pull "${ROS_IMAGE}"
ok "Образ загружен: $(sudo docker images "${ROS_IMAGE}" --format '{{.Repository}}:{{.Tag}} | {{.Size}}')"
 
# ── 8. Сохранение имени образа для Dockerfile и скриптов запуска ──────────────
echo "${ROS_IMAGE}" > ~/.ros2_docker_image
ok "Имя образа сохранено в ~/.ros2_docker_image"
 
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗"
echo -e "║  ✓  Docker + ROS 2 Jazzy образ готовы!                  ║"
echo -e "║                                                          ║"
echo -e "║  Следующие шаги:                                         ║"
echo -e "║    1. newgrp docker          — применить группу          ║"
echo -e "║    2. bash run_ros2.sh       — интерактивный запуск      ║"
echo -e "║    3. sudo systemctl start ros2-jazzy  — как сервис      ║"
echo -e "║    4. Отредактируйте Dockerfile под свои нужды           ║"
echo -e "╚══════════════════════════════════════════════════════════╝${NC}\n"
