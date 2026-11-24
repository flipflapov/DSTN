# Руководство для ИИ-агентов

Прочитайте это, прежде чем что-либо менять. В [CONTRIBUTING.md](CONTRIBUTING.md) — правила для всех участников,
в [docs/design.md](docs/design.md) — форматы и контракт транслятора с runtime; этот файл добавляет то, в чём агенты
чаще всего ошибаются.

## Что это

Шаблон порта сборки GTA VI для Xbox Series, который собирается на ПК игрока из его собственной копии:
`make_game.py` вырезает и переводит шейдеры (RDNA2 → SPIR-V), экспортирует ресурсы и собирает `runtime/` —
PE-загрузчик, который отображает исполняемый файл игры и связывает его импорты с заглушками. В репозитории нет
ничего из игры. DSTN — форк [Leonida](https://github.com/ItsNotRexed/Leonida): переменные окружения называются
`DSTN_*`, runtime — `dstnrt`, пространство имён C++ — `dstn::`.

## Где что лежит

- Заметки в `docs/` фиксируют измеренные форматы, их оглавление — [docs/README.md](docs/README.md); чаще всего
  цитируется `docs/design.md`. Какие документы уже переведены на русский — в
  [docs/translation_status.md](docs/translation_status.md).
- В `scripts/` — запуск GPU- и Wine-тестов (`run_gpu_tests.py`, `run_wine_tests.py`) и вспомогательные скрипты
  сборки на PowerShell.
- `viewer/` — вьювер карты: `index.html` и `serve.py`, локальный сервер для экспортированного мира.
- В `third_party/` — подмодуль `rpf9-explorer` (`tools/rpf9dump` требует `git submodule update --init`),
  встроенный `xtaskqueue`, с которым линкуется заглушка `xgameruntime`, и встроенный rANS-декодер `bcpack-rs` для
  инструментов калибровки BCPack.
- `game/xbox-1.0.2.1.json` — манифест размеров и SHA-256 каждого файла пакета Xbox: только хеши, никакого
  содержимого игры.
- `tests/semantic/` — регрессионный набор транслятора; новое правило транслятора сопровождается маленьким
  рукописным `.asm`-фикстуром там.
- Подставные игры для проверки загрузчика — `runtime/test/fixtures/`, как их запускать — в
  [docs/test_game.md](docs/test_game.md).

## Жёсткие правила

- **Никаких данных игры, никогда**: ни архивов, ни исполняемых файлов, ни вырезанных файлов, ни шейдеров в любом
  виде (DXBC, FSSM, дизассемблированный код, SPIR-V), ни текстур, ни звука, ни логов и отчётов, которые их цитируют,
  — ни в коммитах, ни в issues, ни в pull request, ни в фикстурах тестов. Тест, которому нужен шейдер, строит вход
  вручную или читает его из рабочей папки пользователя.
- **Никаких ключей, расшифровки и обхода защиты.** Если формат оказался зашифрован, запишите это в
  `docs/design.md` и на этом остановитесь.
- **Ничего онлайн**: никаких сервисов и доменов Xbox Live или Rockstar.
- **Чинить, а не отключать**: шейдер, который транслятор отвергает, получает правило, а не место в списке
  пропусков. Новое правило попадает в таблицу контракта в `docs/design.md` с тем, как оно подтверждено (GPU-тест,
  эталон Mesa/LLVM или подсчёт по корпусу).

## Договоритесь, прежде чем начинать

- Работа в DSTN обсуждается в issues этого репозитория. Прежде чем открывать pull request, проверьте открытые
  issues и pull request: если кто-то уже делает то же самое, остановитесь и скажите об этом пользователю, а не пишите
  второй раз.
- В pull request укажите `Fixes #N` для закрываемого issue и `Depends on: #N` для каждого pull request, на котором
  основан ваш.
- Нашли работу, которую сами делать не будете (ошибка, недостающий метод, устаревшая документация, продолжение
  вашего pull request)? Откройте issue: одна строка сути, где это (файл и строка), почему это важно и нужны ли файлы
  игры или особое железо.
- Изменение для исходного проекта Leonida делается на его коде и по его правилам: заявка в issue координации
  («Coordinating who works on what»), ID пункта в pull request. Найти актуальное issue координации:

  ```sh
  gh issue list -R ItsNotRexed/Leonida --state open --search "Coordinating who works on what in:title"
  ```

- По слою D3D12 → Vulkan (`runtime/shims/d3d12_*`, `runtime/src/vulkan_*`) прочитайте также
  [Leonida#313](https://github.com/ItsNotRexed/Leonida/issues/313): там перечислено, какие методы D3D12 ещё открыты.

## Прежде чем гадать, посмотрите

- Формат или поведение, возможно, уже измерены в `docs/design.md`. Указывайте файл и смещение, откуда взято
  утверждение, или называйте его гипотезой.
- Считайте по всему корпусу, а не по выборке: правило, верное для 400 шейдеров, может не выполняться для остальных
  26 000.

## Сначала тестируйте без игры

Это не требует файлов игры и выполняется за секунды:

```powershell
python -m compileall -q make_game.py tools tests
python -I make_game.py --help
python -I scripts/run_semantic_tests.py tests/semantic   # регрессионный набор транслятора, по файлу на ядро; не нужны LLVM, инструменты SPIR-V и GPU
python -I tests/test_<имя>.py                     # отдельный юнит-тест на стандартной библиотеке
node --test tests/test_viewer_streaming.cjs        # потоковая загрузка вьювера; нужен Node 22+
dotnet build tools/rpf9dump/rpf9dump.csproj -c Release
cmake -S runtime -B runtime/build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo; cmake --build runtime/build
```

Для тестов на pytest используйте виртуальное окружение и установите зафиксированные зависимости из
[`tests/requirements.txt`](tests/requirements.txt). Из корня репозитория запустите `python -m pytest` с нужным
файлом теста.

```powershell
python -m pip install -r tests/requirements.txt
python -m pytest tests/test_user_sgpr_census.py
```

Если рабочая папка уже собрана, изменение транслятора сначала проверяют на срезе, а результат сравнивают с
предыдущим прогоном:

```powershell
python -I tools/rdna2spirv.py <work>/shaders/dxbc/disasm --out <scratch> --limit 200
python -I tools/rdna2spirv.py <work>/shaders/dxbc/disasm --out <scratch> --shard 0/8   # один из 8 параллельных срезов
```

Прогоны по срезам пишут `index.part*.json`; объедините их в `index.json` через `--merge`. Сообщайте число
переведённых шейдеров и прошедших `spirv-val` до и после; изменение, уменьшающее любое из них, — регрессия.

## Соглашения

- Инструменты на Python запускаются с `python -I` и используют только стандартную библиотеку, если в файле не
  сказано иное; исключения — инструменты текстур и моделей, импортирующие numpy или Pillow: `bc_feature.py`,
  `amd_swizzle.py`, `tile_probe.py`, `swizzle_search.py`, `tex_export.py`, `tex_mode_probe.py`,
  `calibrated_texture.py`, `world_grid_atlas.py`, `tex_headers.py` и `skinned_glb.py` (без numpy они откатываются на
  стандартную библиотеку).
- `make_game.py` в первую очередь должен работать на Windows: пути через `os.path`, никакого bash в сборке.
- Документация DSTN пишется на русском. Имена файлов, команд, опций, переменных и заголовки, на которые ведут
  якорные ссылки, не переводятся (см. [docs/translation_status.md](docs/translation_status.md)).
- В pull request напишите, что он сделан с помощью ИИ, что вы проверили и на какой видеокарте и драйвере.
