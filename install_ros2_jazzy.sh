#!/bin/bash
set -euo pipefail
 
# ─────────────────────────────────────────────
#  ROS 2 Jazzy — автоустановка на Ubuntu 24.04 Noble
#  Raspberry Pi 4B
# ─────────────────────────────────────────────
 
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
 
log()  { echo -e "${CYAN}[ROS2]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }
 
# ── Проверка, что запущен не от root напрямую ──────────────────────────────────
if [[ $EUID -eq 0 ]]; then
    fail "Не запускайте скрипт через 'sudo ./...'. Запустите как обычный пользователь: bash install_ros2_jazzy.sh"
fi
 
echo -e "\n${CYAN}╔══════════════════════════════════════════════╗"
echo -e "║   ROS 2 Jazzy — установка (Ubuntu 24 Noble)  ║"
echo -e "╚══════════════════════════════════════════════╝${NC}\n"
 
# ── Один запрос sudo + keepalive на всё время скрипта ─────────────────────────
log "Запрашиваю sudo один раз..."
sudo -v || fail "Не удалось получить права sudo"
 
# Держим sudo живым в фоне пока скрипт работает
( while true; do sudo -n true; sleep 50; done ) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null; exit' EXIT INT TERM
 
# ── 1. Локаль ─────────────────────────────────────────────────────────────────
log "Настройка локали UTF-8..."
sudo apt-get update -qq
sudo apt-get install -y locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8
ok "Локаль: $(locale | grep LANG)"
 
# ── 2. Universe репозиторий ───────────────────────────────────────────────────
log "Включаю репозиторий universe..."
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y universe
ok "Universe включён"
 
# ── 3. curl ───────────────────────────────────────────────────────────────────
log "Устанавливаю curl..."
sudo apt-get update -qq && sudo apt-get install -y curl
ok "curl готов"
 
# ── 4. ROS apt source ─────────────────────────────────────────────────────────
UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME}}")
DEB_PATH="/tmp/ros2-apt-source.deb"
 
# Вспомогательная функция: скачать с повторами и коротким таймаутом
curl_retry() {
    local url="$1" dest="$2"
    curl -L --retry 3 --retry-delay 5 \
         --connect-timeout 15 --max-time 90 \
         -o "$dest" "$url"
}
 
# ── Попытка 1: скачать .deb с GitHub ──────────────────────────────────────────
log "Пробую получить ros2-apt-source через GitHub..."
ROS_APT_SOURCE_VERSION=$(curl -s --connect-timeout 10 --max-time 20 \
    https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
    | grep -F "tag_name" | awk -F'"' '{print $4}')
 
GITHUB_OK=false
if [[ -n "$ROS_APT_SOURCE_VERSION" ]]; then
    DEB_URL="https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${UBUNTU_CODENAME}_all.deb"
    log "Версия: $ROS_APT_SOURCE_VERSION — скачиваю..."
    if curl_retry "$DEB_URL" "$DEB_PATH"; then
        GITHUB_OK=true
    else
        warn "GitHub скачивание не удалось, перехожу к fallback..."
    fi
else
    warn "GitHub API недоступен, перехожу к fallback..."
fi
 
if $GITHUB_OK; then
    log "Устанавливаю ros2-apt-source.deb..."
    sudo dpkg -i "$DEB_PATH"
    ok "ROS apt source добавлен (через .deb)"
else
    # ── Fallback: GPG-ключ + sources.list вручную ──────────────────────────────
    log "Fallback: добавляю ROS2 GPG-ключ и sources.list напрямую с ros.packages.ros.org..."
 
    KEY_PATH="/usr/share/keyrings/ros-archive-keyring.gpg"
 
    if ! curl_retry "https://ros.packages.ros.org/ros.asc" /tmp/ros.asc; then
        fail "Не удалось скачать GPG-ключ ROS2. Проверьте подключение (попробуйте: ping 8.8.8.8)"
    fi
 
    sudo gpg --dearmor -o "$KEY_PATH" /tmp/ros.asc
    sudo chmod a+r "$KEY_PATH"
 
    ARCH=$(dpkg --print-architecture)
    echo "deb [arch=${ARCH} signed-by=${KEY_PATH}] https://ros.packages.ros.org/ros2/ubuntu ${UBUNTU_CODENAME} main" \
        | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
 
    ok "ROS apt source добавлен (fallback: ключ + sources.list)"
fi
 
# ── 5. ros-dev-tools ──────────────────────────────────────────────────────────
log "Устанавливаю ros-dev-tools..."
sudo apt-get update -qq && sudo apt-get install -y ros-dev-tools
ok "ros-dev-tools установлен"
 
# ── 6. Обновление системы ─────────────────────────────────────────────────────
log "Обновляю пакеты системы (apt upgrade)..."
sudo apt-get update -qq
sudo apt-get upgrade -y
ok "Система обновлена"
 
# ── 7. ROS 2 Jazzy base ───────────────────────────────────────────────────────
log "Устанавливаю ros-jazzy-ros-base..."
sudo apt-get install -y ros-jazzy-ros-base
ok "ROS 2 Jazzy установлен!"
 
# ── 8. Переменные окружения и source в ~/.bashrc ──────────────────────────────
log "Записываю переменные окружения ROS 2 в ~/.bashrc..."
 
# Вспомогательная функция: добавляет строку только если её ещё нет
append_if_missing() {
    local line="$1"
    grep -qF "$line" ~/.bashrc || echo "$line" >> ~/.bashrc
}
 
# Блок пишется один раз; маркер позволяет не дублировать при повторном запуске
if ! grep -qF "# >>> ROS 2 Jazzy >>>" ~/.bashrc; then
    cat >> ~/.bashrc <<'EOF'
 
# >>> ROS 2 Jazzy >>>
# Основной setup — даёт доступ к ros2, colcon и пр.
source /opt/ros/jazzy/setup.bash
 
# Домашняя директория пользовательского воркспейса (при наличии)
# Раскомментируйте и поправьте путь, если используете свой workspace:
# source ~/ros2_ws/install/setup.bash
 
# Дистрибутив ROS
export ROS_DISTRO=jazzy
 
# Домен DDS — изолирует вашу сеть ROS от других устройств в той же сети.
# Все устройства с одинаковым ROS_DOMAIN_ID видят друг друга.
# Допустимые значения: 0–101. По умолчанию 0.
export ROS_DOMAIN_ID=0
 
# Локальный режим (только localhost, без multicast).
# 1 = общаться только внутри одной машины.
# 0 = общаться по сети (нужно для multi-robot).
export ROS_LOCALHOST_ONLY=0
 
# Реализация rmw (middleware). Для Jazzy по умолчанию FastDDS.
# Альтернативы: rmw_cyclonedds_cpp (установить отдельно)
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
 
# Цветной вывод в консоли ros2
export RCUTILS_COLORIZED_OUTPUT=1
 
# Формат лог-строк (можно убрать timestamp если мешает)
export RCUTILS_CONSOLE_OUTPUT_FORMAT="[{severity}] [{time}] [{name}]: {message}"
 
# Локаль — обязательно UTF-8 для корректной работы ROS
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
# <<< ROS 2 Jazzy <<<
EOF
    ok "Блок переменных окружения добавлен в ~/.bashrc"
else
    warn "Блок ROS 2 Jazzy уже существует в ~/.bashrc — пропускаю, чтобы не дублировать"
fi
 
# ── Готово ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗"
echo -e "║  ✓  ROS 2 Jazzy успешно установлен!                  ║"
echo -e "║                                                      ║"
echo -e "║  Переменные окружения записаны в ~/.bashrc           ║"
echo -e "║                                                      ║"
echo -e "║  Перезапустите терминал или выполните:               ║"
echo -e "║    source ~/.bashrc                                  ║"
echo -e "║                                                      ║"
echo -e "║  Проверка: ros2 --version                            ║"
echo -e "╚══════════════════════════════════════════════════════╝${NC}\n"
