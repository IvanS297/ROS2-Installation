# ROS2-Installation

Набор скриптов для быстрой установки ROS 2 Jazzy на Raspberry Pi — нативно на Ubuntu Noble или через Docker на Debian Trixie. Также включает установщик rmw_zenoh для тех кто хочет заменить DDS на Zenoh.

---

## Что здесь есть

| Файл | Что делает |
|---|---|
| `install_ros2_jazzy.sh` | Нативная установка ROS 2 Jazzy на Ubuntu 24.04 Noble |
| `install_on_docker.sh` | Установка Docker + pull образа `osrf/ros:jazzy-ros-base-noble` на Debian Trixie |
| `install_rmw_zenoh.sh` | Установка и настройка rmw_zenoh_cpp (router или sensor) |

---

## Нативная установка (Ubuntu Noble)

```bash
bash install_ros2_jazzy.sh
source ~/.bashrc
ros2 --version
```

Скрипт настроит локаль, добавит репозиторий ROS2, установит `ros-jazzy-ros-base` и запишет все нужные переменные окружения в `~/.bashrc`. Если GitHub недоступен — автоматически переключится на fallback через `packages.ros.org`.

> Запускать без `sudo` — скрипт сам запросит пароль один раз.

---

## Docker (Debian Trixie / RPi 4, 5)

Используется когда нативная установка невозможна или нежелательна — например на Debian, где официального deb-пакета ROS2 нет.

```bash
bash install_on_docker.sh
newgrp docker
bash run_ros2.sh        # интерактивный запуск
```

Для запуска как сервис (автозапуск при загрузке):

```bash
bash install_service.sh
sudo systemctl enable --now ros2-jazzy
journalctl -u ros2-jazzy -f
```

Перед этим отредактируйте `ExecStart` в unit-файле под свою launch-команду:

```bash
sudo nano /etc/systemd/system/ros2-jazzy.service
sudo systemctl daemon-reload
```

Если нужна кастомизация образа — правьте `Dockerfile` (там закомментированы блоки для навигации, камеры, лидара, ros2-control) и собирайте:

```bash
docker build -t my-ros2-jazzy .
ROS2_IMAGE=my-ros2-jazzy bash run_ros2.sh
```

---

## rmw_zenoh (опционально)

Альтернатива FastDDS — лучше работает через NAT и нестабильные сети. Нужно запустить на обоих устройствах.

**На роутере** (ноутбук/ПК):
```bash
bash install_rmw_zenoh.sh   # выбрать: 1) router, ввести IP этой машины
source ~/.bashrc
ros2 run rmw_zenoh_cpp rmw_zenohd
```

**На сенсоре** (RPi/робот):
```bash
bash install_rmw_zenoh.sh   # выбрать: 2) sensor, ввести свой IP и IP роутера
source ~/.bashrc
ros2 run <package> <node>
```

Конфиги сохраняются в `~/.config/zenoh/`.

---

## Требования

- **Нативно:** Raspberry Pi 4B, Ubuntu 24.04 Noble, подключение к интернету
- **Docker:** Raspberry Pi 4/5, Debian Trixie (arm64), подключение к интернету
- **rmw_zenoh:** ROS 2 Jazzy уже установлен, оба устройства в одной сети
