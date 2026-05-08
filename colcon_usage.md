# Colcon — флаги и полезные приёмы

---

## Базовый синтаксис

```bash
colcon build [флаги]
colcon test  [флаги]
colcon info  [флаги]
```

---

## Выбор пакетов для сборки

```bash
# Собрать только конкретные пакеты
colcon build --packages-select pkg_a pkg_b

# Собрать пакет и всё от чего он зависит
colcon build --packages-up-to my_package

# Собрать всё кроме указанных пакетов
colcon build --packages-skip pkg_a pkg_b

# Собрать только пакеты у которых изменились исходники
colcon build --packages-select-by-dep my_package
```

`--packages-up-to` — самый частый вариант при разработке: тянет нужные зависимости и не трогает остальное.

---

## Скорость сборки

```bash
# Параллельная сборка — использовать N ядер (по умолчанию все)
colcon build --parallel-workers 4

# Отключить параллельность (если мало RAM или нужна читаемая ошибка)
colcon build --executor sequential

# Не пересобирать если исходники не менялись
colcon build --packages-select my_package  # + cmake кешируется автоматически
```

На RPi 4 с 4 ГБ RAM комфортно `--parallel-workers 2`. При `--parallel-workers 4` на тяжёлых C++ пакетах легко улетает OOM — система начинает свопиться или падает.

---

## Экономная сборка (мало RAM / слабое железо)

```bash
# Последовательно + ограничить cmake потоки
colcon build \
    --executor sequential \
    --parallel-workers 1 \
    --cmake-args -DCMAKE_BUILD_TYPE=Release

# Если совсем туго — передать ninja/make ограничение потоков
colcon build \
    --executor sequential \
    --cmake-args -DCMAKE_BUILD_TYPE=Release \
    -- --jobs 1
```

`Release` вместо `Debug` даёт заметно меньший бинарник и быстрее компилируется на слабом железе — отладочные символы не генерируются.

---

## Быстрая разработка (Python)

```bash
colcon build --symlink-install
```

Вместо копирования файлов создаёт символические ссылки на исходники. Изменения в `.py` файлах применяются **без пересборки** — просто перезапустить ноду. Для C++ не работает, там всё равно нужна компиляция.

---

## cmake-args — передача флагов компилятору

```bash
# Тип сборки
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release     # быстрый бинарник
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Debug       # с отладочными символами
colcon build --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo  # среднее

# Включить тесты (обычно отключены по умолчанию)
colcon build --cmake-args -DBUILD_TESTING=ON

# Несколько cmake-args за раз
colcon build --cmake-args \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF
```

---

## Вывод и логи

```bash
# Показывать вывод компилятора прямо в терминал
colcon build --event-handlers console_direct+

# Показывать статус (прогресс) без лишнего вывода
colcon build --event-handlers console_cohesion+

# Подавить весь вывод кроме ошибок
colcon build --event-handlers console_direct- status-

# Логи всегда пишутся в log/ — посмотреть последний билд
cat log/latest_build/my_package/stdout_stderr.log
```

По умолчанию colcon молчит пока не упадёт. Если нужно видеть что происходит в реальном времени — `--event-handlers console_direct+`.

---

## Тесты

```bash
# Запустить тесты
colcon test --packages-select my_package

# Посмотреть результаты (коротко)
colcon test-result

# Подробно — с именами упавших тестов
colcon test-result --verbose

# Вывод тестов прямо в терминал
colcon test --event-handlers console_direct+
```

---

## Мета-информация о пакетах

```bash
# Список всех пакетов в воркспейсе
colcon list

# Граф зависимостей (кто от кого зависит)
colcon graph

# Граф в виде ASCII-дерева
colcon graph --dot | dot -Tpng -o deps.png   # нужен graphviz
```

`colcon list` удобно проверять до сборки — убедиться что все пакеты из `src/` видны.

---

## Сохранение флагов в defaults файл

Если одни и те же флаги используются постоянно — можно не писать их каждый раз. Colcon читает `~/.colcon/defaults.yaml`:

```bash
mkdir -p ~/.colcon
cat > ~/.colcon/defaults.yaml << 'EOF'
{
  build: {
    symlink-install: true,
    cmake-args: ["-DCMAKE_BUILD_TYPE=Release"],
    parallel-workers: 2
  }
}
EOF
```

После этого просто `colcon build` — флаги применятся автоматически.

---

## Шпаргалка

| Задача | Команда |
|---|---|
| Собрать один пакет | `colcon build --packages-select my_pkg` |
| Собрать с зависимостями | `colcon build --packages-up-to my_pkg` |
| Быстрая разработка Python | `colcon build --symlink-install` |
| Экономно на RPi | `colcon build --executor sequential --parallel-workers 1` |
| Release сборка | `colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release` |
| Видеть вывод компилятора | `colcon build --event-handlers console_direct+` |
| Список пакетов | `colcon list` |
| Граф зависимостей | `colcon graph` |
| Запустить тесты | `colcon test --packages-select my_pkg` |
| Результаты тестов | `colcon test-result --verbose` |
