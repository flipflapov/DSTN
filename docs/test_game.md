# Тестовая игра: запуск загрузчика без файлов игры

Настоящая игра в DSTN пока не запускается: исполняемого файла нет в пакете, по которому велась работа (см.
[runtime/README.md](../runtime/README.md)). Чтобы разрабатывать и проверять загрузчик `dstnrt`, заглушки
импортов и слой D3D12 → Vulkan, в репозитории есть **подставные «игры»**: маленькие Windows-программы из
`runtime/test/fixtures/`. Они импортируют то же, что импортирует консольный исполняемый файл (`xgameruntime.dll`,
`d3d12_xs.dll`, XMem, GDK), и выполняются **внутри** `dstnrt`, как выполнялась бы игра. Это тестовый код, а не
содержимое игры, и файлы игры для него не нужны.

| Подставная игра | Что проверяет | Тест CTest |
|---|---|---|
| `tiny_game` | Первая секунда жизни игры: аргументы, статические инициализаторы, куча, запись и чтение файла, второй поток, импорты `xgameruntime.dll`, код выхода | `run_tiny_game`, `run_tiny_game_tls`, `run_tiny_game_eh`, `run_tiny_game_stack`, `run_tiny_game_dir`, `run_tiny_game_exit_code` |
| `tiny_game_fixed` | Тот же `tiny_game` без таблицы перемещений, только по адресу `0x140000000` | `run_tiny_game_fixed` |
| `tiny_atexit` | Обработчики `atexit`, статические деструкторы и все способы выхода в сравнении с нативным запуском | `run_tiny_atexit` |
| `tiny_frame` | Один кадр: `D3D12XboxCreateDevice`, очистка render target и чтение его обратно на устройстве Vulkan | `run_tiny_frame` |
| `tiny_guest_draw` | Три отрисовки двумя рукописными шейдерами в текстуру 64×64 с проверкой каждого пикселя; опционально сцена на 600 кадров с вводом, звуком и сохранением | `d3d12_translated_draw_guest`, `d3d12_guest_scene` |

## 0. Стартовое меню (Windows)

Все шаги ниже собраны в одно меню: дважды щёлкните `Start-DSTN.bat` в корне репозитория (сам скрипт меню —
`scripts/dstn_start.ps1`). Пункты меню:

| № | Пункт | Шаг для запуска без меню |
|---|---|---|
| 1 | Проверить компьютер: Visual Studio, Windows SDK, Vulkan SDK и видеокарта, Python, .NET, llvm-mc | `Start-DSTN.bat check` |
| 2 | Установить недостающее автоматически (см. ниже) | `Start-DSTN.bat install` |
| 3 | Собрать загрузчик `dstnrt.exe` (разделы 1 и 3 ниже) | `Start-DSTN.bat build` |
| 4 | Запустить `tiny_game` четыре раза: основной запуск, `tls`, `eh`, `stack` | `Start-DSTN.bat testgame` |
| 5 | Тестовый кадр на Vulkan (`tiny_frame`) | `Start-DSTN.bat frame` |
| 6 | Все тесты загрузчика (CTest) | `Start-DSTN.bat tests` |
| 7 | Найти копии игры на этом ПК (`make_game.py --find`) | `Start-DSTN.bat find` |
| 8 | Проверить свою копию игры (`make_game.py --check`) | `Start-DSTN.bat game-check` |
| 9 | Собрать порт: стадии `check,shaders,runtime` или свои | `Start-DSTN.bat port` |
| 10 | Запустить свою копию через VIctory, родственный загрузчик на Rust (см. ниже) | `Start-DSTN.bat victory` |

Пункт 2 ставит только то, чего не хватает, и сначала показывает список и спрашивает согласия. Программы
ставятся через `winget` (встроен в Windows 10/11; если его нет — «App Installer» из Microsoft Store):

| Что | Как |
|---|---|
| Python 3.12 | `winget install Python.Python.3.12` |
| Git | `winget install Git.Git` |
| Visual Studio 2022 Build Tools с C++, Windows SDK 10.0.26100 и C++ CMake tools | `winget install Microsoft.VisualStudio.2022.BuildTools`; если Visual Studio уже есть, недостающие компоненты добавляет её собственный установщик |
| Vulkan SDK | `winget install KhronosGroup.VulkanSDK` |
| .NET 8 SDK | `winget install Microsoft.DotNet.SDK.8` |
| Подмодуль `third_party/rpf9-explorer` | `git submodule update --init --recursive` |
| llvm-mc с целью AMDGPU | `scripts/build_llvm_mc.ps1`, сборка из исходников LLVM, 20–40 минут (спрашивает отдельно) |
| ffmpeg (необязательно) | `winget install Gyan.FFmpeg` (спрашивает отдельно) |

Пункт 10 скачивает [VIctory](https://github.com/Marvisak/VIctory) (GPL-3.0-or-later) закреплённого коммита в
`%LOCALAPPDATA%\DSTN\victory`, вне репозитория DSTN, при необходимости ставит Rust (`winget install Rustlang.Rustup`),
собирает его (`cargo build --release -p victory`) и запускает исполняемый файл вашей копии
(`victory run <exe> --execute`, папка игры — в `VICTORY_GAME_DIR`). По README VIctory игра у него доходит до меню и
загрузки мира, но мир пока не рисуется, а вход в мир на настоящей видеокарте может её подвесить. Без исполняемого
файла игры (`game_scarlett_master.exe`) запускать нечего и через VIctory. Подробнее о проекте и о том, что из него
можно брать, — в [related_projects.md](related_projects.md#marvisakvictory).

Windows может запросить права администратора для каждого установщика. Если программа установилась, но проверка её
не видит, закройте окно и запустите `Start-DSTN.bat` заново: некоторые установщики меняют `PATH` только для новых окон.

Каждый запуск пишет весь вывод в `logs\dstn-<дата>.log` (папка `logs` не попадает в git). В журнале только вывод
инструментов, без данных игры, поэтому его можно присылать при ошибке. Папку игры меню запоминает в
`logs\game_folder.txt`.

## 1. Сборка на Windows

Нужны Windows 10/11 x64 и Visual Studio 2022 с нагрузкой «Desktop development with C++» и Windows SDK
10.0.26100 или новее. Для кадров на Vulkan нужен ещё [Vulkan SDK](https://vulkan.lunarg.com/).

```powershell
git clone --recursive <адрес репозитория DSTN>
cd DSTN
powershell -File scripts/build_runtime.ps1
```

Скрипт собирает `runtime\build\dstnrt.exe`, рядом с ним `dstnrt_tls_host.dll` (он должен лежать рядом с
`dstnrt.exe`), все подставные игры и тесты. Подставные игры попадают в
`runtime\build\fixtures\game\<тип сборки>\`, например `RelWithDebInfo`.

Тот же результат даёт CMake напрямую:

```powershell
cmake -S runtime -B runtime/build
cmake --build runtime/build --config RelWithDebInfo
```

## 2. Запуск тестовой игры

Самый простой способ: запустить тесты CTest, которые сами выполняют подставные игры через `dstnrt`.

```powershell
ctest --test-dir runtime/build -C RelWithDebInfo -R "^run_tiny_game" -V
```

Вручную — так же, как запускалась бы настоящая игра. Всё, что идёт после `--`, это командная строка самой игры:

```powershell
$game = "runtime\build\fixtures\game\RelWithDebInfo"
runtime\build\dstnrt.exe --run "$game\tiny_game.exe" -- hello 42
```

Успешный запуск печатает строки `tiny_game: PASS ...`, затем `tiny_game: OK` и `game exited with code 0`.
Дополнительные проверки включаются аргументами после `hello 42`:

| Аргумент | Что добавляет |
|---|---|
| `tls` | `thread_local` в потоках самой игры (нужен TLS загрузчика для каждого потока) |
| `eh` | Исключение C++, брошенное и пойманное внутри образа игры |
| `stack` | 8 МБ стека у главного потока и у потока, созданного с размером стека 0 |
| `game-file` | Чтение `GAME:\tiny_game_probe.txt` после смены текущей папки |
| `exit-code` | Выход с кодом 42 вместо 0 |

Пример с файлом игры через консольный путь `GAME:`. Папку с файлами задаёт `--game-dir`, а записи игры уходят в
`--overlay` (по умолчанию `<game-dir>\overlay`):

```powershell
Set-Content -NoNewline "$game\tiny_game_probe.txt" "game"
runtime\build\dstnrt.exe --game-dir $game --run "$game\tiny_game.exe" -- hello 42 game-file
```

### Режимы `dstnrt` для разработки

| Команда | Что делает |
|---|---|
| `dstnrt --dry-run <exe или dll>` | Отображает образ и его модули, связывает импорты и печатает отчёт по каждому модулю. Код образа не выполняется |
| `dstnrt --init <exe или dll>` | То же, плюс TLS-колбэки и `DllMain` каждой DLL. Точка входа EXE не вызывается |
| `dstnrt --run <exe> -- <аргументы>` | Полный запуск точки входа |
| `--trace <файл>` | Перед `--dry-run`, `--init` или `--run`: пишет JSON-строку на каждое событие запуска. Файл не должен существовать |
| `--trace-d3d12` | Записывает каждый вызов D3D12 и его результат |

Неподдержанные импорты видны в отчёте `--dry-run` (`unimplemented=N`) и во время работы управляются переменной
`DSTN_UNIMPLEMENTED` (см. [runtime/README.md](../runtime/README.md)).

## 3. Кадр на Vulkan

`tiny_frame` создаёт устройство через `d3d12_xs.dll!D3D12XboxCreateDevice`, очищает render target и читает его
обратно. Бэкенд Vulkan включается переменной `DSTN_D3D12=vulkan`:

```powershell
$env:DSTN_D3D12 = "vulkan"
runtime\build\dstnrt.exe --run "runtime\build\fixtures\game\RelWithDebInfo\tiny_frame.exe"
ctest --test-dir runtime/build -C RelWithDebInfo -R "^run_tiny_frame$" -V
```

Без видеокарты с Vulkan тест пропускается (код 77), а не падает.

Отрисовка переведёнными шейдерами (`tiny_guest_draw`) и сцена на 600 кадров собираются по опциям CMake
`-DDSTN_TEST_GUEST_DRAW=ON` и `-DDSTN_GUEST_SCENE=ON`; команды для них — в разделах «A synthetic guest draws its
first offscreen frame» и «A 600-frame headless guest scene» файла [runtime/README.md](../runtime/README.md).

## 4. На Linux, под Wine или Proton

`dstnrt` — программа для Windows. На Linux её кросс-компилируют через clang-cl и lld-link (LLVM 19+, кроме 22.1.7 и
22.1.8) с MSVC CRT и Windows SDK от [xwin](https://github.com/Jake-Shadle/xwin) (запуск xwin означает согласие с
лицензией Microsoft), а запускают под Wine:

```sh
xwin --accept-license --sdk-version 10.0.26100 splat --use-winsysroot-style --preserve-ms-arch-notation \
     --output ~/.local/share/xwin-sdk
cmake -S runtime -B runtime/build/windows --toolchain "$PWD/runtime/cmake/clang-cl-xwin.cmake" \
      -DXWIN_DIR="$HOME/.local/share/xwin-sdk"
cmake --build runtime/build/windows --parallel
WINEPREFIX="$HOME/.local/share/dstn-wine" ctest --test-dir runtime/build/windows -R "^run_tiny_game" -V
```

Вручную:

```sh
cd runtime/build/windows
wine ./dstnrt.exe --run "$(winepath -w fixtures/game/RelWithDebInfo/tiny_game.exe)" -- hello 42
```

На машине без экрана (сервер, контейнер, WSL без WSLg) тесты Vulkan запускают под виртуальным X-сервером:
`xvfb-run -a ctest ...`. Подробности и известные проблемы — в разделе «The Windows runtime on Linux, under Wine
or Proton» файла [docs/testing.md](testing.md).

## 5. Своя тестовая игра

Новую подставную игру добавляют так же, как существующие:

1. Создайте в папке `runtime/test/fixtures/` файл `my_game.cpp` — обычную консольную программу для Windows, которая вызывает
   нужные импорты (например, функции `xgameruntime.dll`) и печатает `PASS`/`FAIL` по каждой проверке.
2. Добавьте в `runtime/CMakeLists.txt` рядом с `tiny_game` цель `add_executable(my_game ...)`, свяжите её с нужной
   заглушкой (`xgameruntime_stub`, `d3d12_xs_stub`, `xmem_stub`) и задайте
   `RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/fixtures/game/$<CONFIG>"`.
3. Добавьте тест: `add_test(NAME run_my_game COMMAND dstnrt --run $<TARGET_FILE:my_game> -- ...)`.

Заглушки-DLL только дают программе слинковаться: под `dstnrt` её импорты обслуживает реестр заглушек runtime, поэтому
вызов, которого там нет, сразу виден как `unimplemented`.

## 6. Ваши собственные файлы Xbox

С `--game-dir` любая папка становится консольным `GAME:`, поэтому загрузчику можно дать файлы **из вашей
собственной копии** игры, если они уже лежат на диске как обычные читаемые файлы. Например, собственные DLL пакета
можно проверить без запуска их кода:

```powershell
runtime\build\dstnrt.exe --dry-run "D:\путь\к\вашему\пакету\<имя>.dll" --game-dir "D:\путь\к\вашему\пакету"
```

Обычный путь работы со своей копией — `make_game.py` (раздел «Как собрать» в [README.md](../README.md)): он
проверяет версию, переводит шейдеры и кладёт в `--out` runtime вместе с `game_path.txt` и `shader_path.txt`.

Запускать загрузчику нужно исполняемый файл игры, `game_scarlett_master.exe` (поле `expected_exe` в
`game/xbox-1.0.2.1.json`). В пакете 1.0.2.1, по которому сделан манифест (108 файлов, 223,9 ГБ, в Проводнике около
208 ГБ), этого файла нет. `make_game.py --check` прямо скажет, есть ли он в вашей папке. Если его нет, стадия
`runtime` собирается, но запускать нечего. Если он есть, первая попытка запуска — это разработка, а не игра (игра
пока не стартует): порядок действий и чек-лист трассировки — в [boot.md](boot.md).

DSTN не расшифровывает файлы и не обходит защиту. Если файлы пакета зашифрованы, загрузчик работать с ними не
будет, и способов это обойти здесь нет и не будет. Никогда не выкладывайте файлы игры, извлечённые ресурсы и
переведённые шейдеры.
