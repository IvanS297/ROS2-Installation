# Colcon Workspace — быстрый старт

Здесь собраны команды для создания рабочего пространства ROS 2 и работы с ним через colcon.

---

## Создание воркспейса

```bash
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws
colcon build
source install/setup.bash
```

После первого `colcon build` появятся папки `build/`, `install/`, `log/`. Папка `src/` — ваша, туда кладёте пакеты.

---

## Создание пакета

**Python:**
```bash
cd ~/ros2_ws/src
ros2 pkg create my_package \
    --build-type ament_python \
    --dependencies rclpy std_msgs
```

**C++:**
```bash
cd ~/ros2_ws/src
ros2 pkg create my_package \
    --build-type ament_cmake \
    --dependencies rclcpp std_msgs
```

---

## Сборка

```bash
cd ~/ros2_ws

# Собрать всё
colcon build

# Собрать только один пакет
colcon build --packages-select my_package

# Собрать с символическими ссылками (Python — изменения применяются без пересборки)
colcon build --symlink-install

# Собрать и показать вывод компилятора
colcon build --event-handlers console_direct+
```

---

## Подключение воркспейса

После каждой сборки нужно переподключить окружение:

```bash
source ~/ros2_ws/install/setup.bash
```

Чтобы не делать это вручную каждый раз — добавьте в `~/.bashrc`:

```bash
echo "source ~/ros2_ws/install/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

> Если в `~/.bashrc` уже есть `source /opt/ros/jazzy/setup.bash` — строка воркспейса должна идти **после** неё.

---

## Тестирование

```bash
cd ~/ros2_ws

# Запустить все тесты
colcon test

# Тесты только одного пакета
colcon test --packages-select my_package

# Посмотреть результаты
colcon test-result --verbose
```

---

## Полезные команды

```bash
# Проверить что пакет виден ROS2
ros2 pkg list | grep my_package

# Найти где лежит пакет
ros2 pkg prefix my_package

# Список нод в пакете
ros2 pkg executables my_package

# Очистить билд одного пакета (пересобрать с нуля)
rm -rf build/my_package install/my_package
colcon build --packages-select my_package

# Полная очистка воркспейса
rm -rf build/ install/ log/
colcon build
```

---

## Структура пакета

```
ros2_ws/
└── src/
    └── my_package/
        ├── my_package/          # Python: код нод
        │   ├── __init__.py
        │   └── my_node.py
        ├── resource/
        ├── test/
        ├── package.xml          # зависимости пакета
        └── setup.py             # для Python пакетов
```

Для C++ вместо `setup.py` будет `CMakeLists.txt`.

---

## Зависимости

Если клонировали чужой пакет и нужно доставить зависимости:

```bash
cd ~/ros2_ws
rosdep install --from-paths src --ignore-src -r -y
```

---

## Типичный рабочий цикл

```bash
# 1. Написали/изменили код в src/
# 2. Пересобрали
colcon build --packages-select my_package --symlink-install

# 3. Переподключили окружение
source install/setup.bash

# 4. Запустили
ros2 run my_package my_node
# или
ros2 launch my_package my_launch.launch.py
```
