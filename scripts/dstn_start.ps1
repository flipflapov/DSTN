# DSTN (ДАСТАН): стартовое меню для Windows.
#
# Запуск: двойной щелчок по Start-DSTN.bat в корне репозитория. Один шаг без меню: Start-DSTN.bat <шаг>, где шаг —
# check, build, testgame, frame, tests, find, game-check или port.
#
# Каждый запуск пишет всё, что вывели шаги, в logs\dstn-<дата>.log. Этот лог можно присылать разработчику: в нём
# только вывод инструментов. Файлы игры, извлечённые ресурсы и шейдеры никуда не выкладывайте.
#
# Файл сохранён в UTF-8 с BOM: без BOM Windows PowerShell 5.1 читает его как ANSI и портит русский текст.
param(
    [ValidateSet("", "check", "build", "testgame", "frame", "tests", "find", "game-check", "port")]
    [string]$Step = ""
)
Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

$Root = Split-Path $PSScriptRoot -Parent
$BuildDir = Join-Path $Root "runtime\build"
$LogDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Force $LogDir | Out-Null
$LogPath = Join-Path $LogDir ("dstn-" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".log")
$GameFolderFile = Join-Path $LogDir "game_folder.txt"
$script:Log = [System.IO.StreamWriter]::new($LogPath, $true, [System.Text.UTF8Encoding]::new($false))
$script:Log.AutoFlush = $true
$script:LastOutput = @()

# ---------------------------------------------------------------- вывод и журнал

function Write-Log([string]$Text, [string]$Color = "Gray") {
    Write-Host $Text -ForegroundColor $Color
    $script:Log.WriteLine($Text)
}

function Write-Title([string]$Text) {
    Write-Log ""
    Write-Log ("=" * 72) Cyan
    Write-Log "  $Text" Cyan
    Write-Log ("=" * 72) Cyan
}

function Write-Ok([string]$Text) { Write-Log "  [ДА]   $Text" Green }

function Write-Missing([string]$Text, [string]$Hint) {
    Write-Log "  [НЕТ]  $Text" Red
    if ($Hint) { Write-Log "         $Hint" Yellow }
}

function Write-Optional([string]$Text, [string]$Hint) {
    Write-Log "  [--]   $Text" DarkYellow
    if ($Hint) { Write-Log "         $Hint" DarkGray }
}

# Запускает программу, показывает её вывод и пишет его в журнал. Возвращает код выхода; строки вывода остаются в
# $script:LastOutput, чтобы шаг мог проверить результат.
function Invoke-Logged([string]$Exe, [string[]]$Arguments, [string]$WorkDir = "") {
    Write-Log ("> " + $Exe + " " + ($Arguments -join " ")) DarkGray
    $lines = New-Object System.Collections.Generic.List[string]
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"   # строки stderr у внешних программ не должны прерывать шаг
    if ($WorkDir) { Push-Location -LiteralPath $WorkDir }
    try {
        $global:LASTEXITCODE = 0
        & $Exe @Arguments 2>&1 | ForEach-Object {
            $line = "$_"
            $lines.Add($line)
            Write-Host $line
            $script:Log.WriteLine($line)
        }
        $code = $LASTEXITCODE
    } catch {
        Write-Log "  Не удалось запустить: $($_.Exception.Message)" Red
        $code = -1
    } finally {
        if ($WorkDir) { Pop-Location }
        $ErrorActionPreference = $previous
    }
    $script:LastOutput = $lines.ToArray()
    return $code
}

function Write-Result([string]$Name, [bool]$Ok, [string]$Note = "") {
    Write-Log ""
    if ($Ok) {
        Write-Log "ИТОГ: $Name — готово. $Note" Green
    } else {
        Write-Log "ИТОГ: $Name — ошибка. $Note" Red
        Write-Log "Пришлите разработчику файл журнала: $LogPath" Yellow
    }
}

# ---------------------------------------------------------------- поиск инструментов

# Тихий запуск для проверок: stdout одной строкой и код выхода, stderr отброшен. При ErrorActionPreference = Stop
# Windows PowerShell 5.1 обрывает скрипт на первой строке stderr у внешней программы, поэтому здесь Continue.
function Invoke-Quiet([string]$Exe, [string[]]$Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $global:LASTEXITCODE = 0
        $text = (& $Exe @Arguments 2>$null) -join "`n"
        return @{ Code = $LASTEXITCODE; Text = $text }
    } catch {
        return @{ Code = -1; Text = "" }
    } finally {
        $ErrorActionPreference = $previous
    }
}

# Команда Python как массив (exe и, для py, ключ версии). Запятая перед массивом не даёт PowerShell развернуть
# массив из одного элемента в строку.
function Find-Python {
    $probe = @("-c", "import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)")
    if (Get-Command py -ErrorAction SilentlyContinue) {
        foreach ($version in "3.14", "3.13", "3.12", "3") {
            if ((Invoke-Quiet "py" (@("-$version") + $probe)).Code -eq 0) { return ,@("py", "-$version") }
        }
    }
    if (Get-Command python -ErrorAction SilentlyContinue) {
        if ((Invoke-Quiet "python" $probe).Code -eq 0) { return ,@("python") }
    }
    return $null
}

# Python запускается с -I (как везде в проекте) и -X utf8, чтобы русские пути и сообщения дошли до журнала целыми.
function Invoke-Python([string[]]$Arguments) {
    $python = Find-Python
    if (-not $python) {
        Write-Missing "Python 3.12 или новее" "https://www.python.org/downloads/ — при установке отметьте «Add python.exe to PATH»."
        return -1
    }
    $exe = $python[0]
    $prefix = @($python | Select-Object -Skip 1)
    return Invoke-Logged $exe ($prefix + @("-I", "-X", "utf8") + $Arguments) $Root
}

function Find-VisualStudio {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $vswhere)) { return $null }
    $result = Invoke-Quiet $vswhere @("-latest", "-products", "*", "-requires",
                                      "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath")
    $path = ($result.Text -split "`n" | Where-Object { $_ } | Select-Object -First 1)
    if ($path) { return $path.Trim() }
    return $null
}

function Find-CTest {
    $vs = Find-VisualStudio
    if ($vs) {
        $candidate = Join-Path $vs "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\ctest.exe"
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    $command = Get-Command ctest -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

function Find-Built([string]$Name) {
    if (-not (Test-Path -LiteralPath $BuildDir)) { return $null }
    $direct = Join-Path $BuildDir $Name
    if (Test-Path -LiteralPath $direct) { return $direct }
    $found = Get-ChildItem -LiteralPath $BuildDir -Recurse -Filter $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

function Get-Loader {
    $loader = Find-Built "dstnrt.exe"
    if (-not $loader) {
        Write-Missing "Загрузчик dstnrt.exe ещё не собран" "Сначала выполните пункт 2 «Собрать загрузчик»."
    }
    return $loader
}

# ---------------------------------------------------------------- шаг 1: проверка компьютера

function Step-Check {
    Write-Title "Шаг 1. Проверка компьютера"
    $required = 0

    Write-Log "Система:"
    if ([Environment]::Is64BitOperatingSystem) { Write-Ok "Windows x64 ($([Environment]::OSVersion.Version))" }
    else { Write-Missing "Нужна 64-разрядная Windows 10/11" ""; $required++ }
    $drive = Get-PSDrive -Name ($Root.Substring(0, 1)) -ErrorAction SilentlyContinue
    if ($drive) {
        $freeGb = [Math]::Round($drive.Free / 1GB)
        if ($freeGb -ge 40) { Write-Ok "Свободно на диске $($drive.Name): $freeGb ГБ" }
        else { Write-Optional "Свободно на диске $($drive.Name): $freeGb ГБ" "Для загрузчика хватит, для шейдеров нужно около 30 ГБ, для полной сборки — около 400 ГБ." }
    }

    Write-Log ""
    Write-Log "Для загрузчика dstnrt.exe и тестовой игры (пункты 2–5):"
    $vs = Find-VisualStudio
    if ($vs) { Write-Ok "Visual Studio с C++ x64: $vs" }
    else { Write-Missing "Visual Studio 2022 с нагрузкой «Desktop development with C++»" "https://visualstudio.microsoft.com/downloads/ (бесплатная Community подходит)."; $required++ }
    if ($vs) {
        $cmakeDir = Join-Path $vs "Common7\IDE\CommonExtensions\Microsoft\CMake"
        if ((Test-Path -LiteralPath (Join-Path $cmakeDir "CMake\bin\cmake.exe")) -and (Test-Path -LiteralPath (Join-Path $cmakeDir "Ninja\ninja.exe"))) {
            Write-Ok "CMake и Ninja из Visual Studio"
        } else {
            Write-Optional "CMake и Ninja из Visual Studio не найдены" "Добавьте в Visual Studio Installer компонент «C++ CMake tools for Windows»: без него сборка обойдётся без тестов CTest и контроллеров."
        }
    }
    $kits = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\Include"
    $sdk = $null
    if (Test-Path -LiteralPath $kits) {
        $sdk = Get-ChildItem -LiteralPath $kits -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^10\.0\.(\d+)\.\d+$' -and [int]$Matches[1] -ge 26100 } |
            Sort-Object Name -Descending | Select-Object -First 1
    }
    if ($sdk) { Write-Ok "Windows SDK $($sdk.Name)" }
    else { Write-Missing "Windows SDK 10.0.26100 или новее" "Visual Studio Installer → Изменить → Отдельные компоненты → Windows 11 SDK (10.0.26100)."; $required++ }

    Write-Log ""
    Write-Log "Для кадра на Vulkan и переведённых шейдеров (пункты 4, 7, 8):"
    if ($env:VULKAN_SDK -and (Test-Path -LiteralPath (Join-Path $env:VULKAN_SDK "Bin\spirv-val.exe"))) {
        Write-Ok "Vulkan SDK: $env:VULKAN_SDK"
        $vulkaninfo = Join-Path $env:VULKAN_SDK "Bin\vulkaninfo.exe"
        if (Test-Path -LiteralPath $vulkaninfo) {
            $devices = @((Invoke-Quiet $vulkaninfo @("--summary")).Text -split "`n" | Where-Object { $_ -match "deviceName" })
            if ($devices.Count) { foreach ($d in $devices) { Write-Ok ("Видеокарта Vulkan: " + ($d -replace '^\s*deviceName\s*=\s*', '')) } }
            else { Write-Missing "vulkaninfo не нашёл ни одной видеокарты Vulkan" "Обновите драйвер видеокарты." }
        }
    } else {
        Write-Optional "Vulkan SDK не найден (переменная VULKAN_SDK)" "https://vulkan.lunarg.com/ — после установки откройте Start-DSTN.bat заново."
    }

    Write-Log ""
    Write-Log "Для сборки порта из своей копии игры (пункты 6–8):"
    $python = Find-Python
    if ($python) { Write-Ok ("Python: " + ($python -join " ")) }
    else { Write-Missing "Python 3.12 или новее" "https://www.python.org/downloads/ — отметьте «Add python.exe to PATH»."; $required++ }
    if (Get-Command git -ErrorAction SilentlyContinue) { Write-Ok "Git" }
    else { Write-Optional "Git не найден" "https://git-scm.com/download/win — нужен, чтобы докачать подмодуль third_party\rpf9-explorer." }
    if (Test-Path -LiteralPath (Join-Path $Root "third_party\rpf9-explorer\*")) { Write-Ok "Подмодуль third_party\rpf9-explorer" }
    else { Write-Optional "Подмодуль third_party\rpf9-explorer пуст" "git submodule update --init (нужен только для экспорта ресурсов)." }
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    $sdks = if ($dotnet) { (Invoke-Quiet "dotnet" @("--list-sdks")).Text } else { "" }
    if ($sdks -match '(?m)^([89]|\d{2,})\.') { Write-Ok ".NET SDK 8+" }
    else { Write-Optional ".NET 8 SDK не найден" "https://dotnet.microsoft.com/download/dotnet/8.0 — нужен для экспорта ресурсов (rpf9dump)." }
    $mc = $env:LLVM_MC
    if (-not $mc) { $command = Get-Command llvm-mc -ErrorAction SilentlyContinue; if ($command) { $mc = $command.Source } }
    if ($mc -and (Test-Path -LiteralPath $mc)) {
        $version = (Invoke-Quiet $mc @("--version")).Text
        if ($version -match "amdgcn") { Write-Ok "llvm-mc с целью AMDGPU: $mc" }
        else { Write-Optional "llvm-mc без цели AMDGPU: $mc" "Соберите свой: powershell -File scripts\build_llvm_mc.ps1 (около 20–40 минут)." }
    } elseif ($mc) {
        Write-Optional "LLVM_MC задан командой: $mc" "Эту команду (например, через WSL) проверка не запускает."
    } else {
        Write-Optional "llvm-mc не найден" "Нужен для перевода шейдеров: powershell -File scripts\build_llvm_mc.ps1 или conda install -c conda-forge llvm-tools."
    }
    if (Get-Command ffmpeg -ErrorAction SilentlyContinue) { Write-Ok "ffmpeg" }
    else { Write-Optional "ffmpeg не найден" "Необязательно: нужен только для звука XMA2 и --wav." }

    Write-Result "Проверка компьютера" ($required -eq 0) ("Обязательного не хватает: $required.")
    return ($required -eq 0)
}

# ---------------------------------------------------------------- шаги 2–5: загрузчик и тестовые игры

function Step-Build {
    Write-Title "Шаг 2. Сборка загрузчика dstnrt.exe"
    Write-Log "Первая сборка идёт 10–20 минут, следующие — быстрее."
    $powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    $code = Invoke-Logged $powershell @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                                         (Join-Path $PSScriptRoot "build_runtime.ps1"), "-PipeOutput") $Root
    $loader = Find-Built "dstnrt.exe"
    $ok = ($code -eq 0) -and [bool]$loader
    Write-Result "Сборка загрузчика" $ok $(if ($ok) { "Файл: $loader" } else { "Код выхода: $code." })
    return $ok
}

function Step-TestGame {
    Write-Title "Шаг 3. Тестовая игра tiny_game"
    $loader = Get-Loader
    $game = Find-Built "tiny_game.exe"
    if (-not $loader) { return $false }
    if (-not $game) {
        Write-Missing "tiny_game.exe не собран" "Нужны CMake и Ninja из Visual Studio (компонент «C++ CMake tools for Windows»), затем пункт 2."
        Write-Result "Тестовая игра" $false
        return $false
    }
    $folder = Split-Path $game -Parent
    $passed = 0
    $runs = @(
        @{ Name = "основной запуск"; Extra = @() },
        @{ Name = "thread_local в потоках игры"; Extra = @("tls") },
        @{ Name = "исключение C++ внутри образа"; Extra = @("eh") },
        @{ Name = "8 МБ стека у потоков"; Extra = @("stack") }
    )
    foreach ($run in $runs) {
        Write-Log ""
        Write-Log "--- $($run.Name)" Cyan
        $code = Invoke-Logged $loader (@("--run", $game, "--", "hello", "42") + $run.Extra) $folder
        $ok = ($code -eq 0) -and ($script:LastOutput -contains "tiny_game: OK")
        if ($ok) { Write-Ok $run.Name; $passed++ } else { Write-Missing "$($run.Name) (код выхода $code)" "" }
    }
    $all = ($passed -eq $runs.Count)
    Write-Result "Тестовая игра" $all "Прошло $passed из $($runs.Count)."
    return $all
}

function Step-Frame {
    Write-Title "Шаг 4. Тестовый кадр на Vulkan (tiny_frame)"
    $loader = Get-Loader
    if (-not $loader) { return $false }
    $frame = Find-Built "tiny_frame.exe"
    if (-not $frame) {
        Write-Missing "tiny_frame.exe не собран" "Он собирается, когда при сборке (пункт 2) найден Vulkan SDK."
        Write-Result "Кадр на Vulkan" $false
        return $false
    }
    $arguments = @("runtime\test\check_tiny_frame.py", $loader, $frame)
    $probe = Find-Built "d3d12_com_test.exe"
    if ($probe) { $arguments += "--probe=$probe" }
    $code = Invoke-Python $arguments
    if ($code -eq 77) {
        Write-Result "Кадр на Vulkan" $true "Пропущено: нет подходящей видеокарты Vulkan (код 77)."
        return $true
    }
    Write-Result "Кадр на Vulkan" ($code -eq 0) "Код выхода: $code."
    return ($code -eq 0)
}

function Step-Tests {
    Write-Title "Шаг 5. Все тесты загрузчика (CTest)"
    $ctest = Find-CTest
    if (-not $ctest) {
        Write-Missing "ctest не найден" "Добавьте в Visual Studio компонент «C++ CMake tools for Windows» и пересоберите (пункт 2)."
        return $false
    }
    if (-not (Test-Path -LiteralPath (Join-Path $BuildDir "CTestTestfile.cmake"))) {
        Write-Missing "В runtime\build нет тестов CTest" "Сначала пункт 2 (сборка через CMake)."
        return $false
    }
    $jobs = [Math]::Max(1, [int]([Environment]::ProcessorCount / 2))
    $code = Invoke-Logged $ctest @("--test-dir", $BuildDir, "-C", "RelWithDebInfo", "--output-on-failure", "-j", "$jobs") $Root
    $summary = $script:LastOutput | Where-Object { $_ -match "tests passed" } | Select-Object -Last 1
    Write-Result "Тесты загрузчика" ($code -eq 0) $(if ($summary) { $summary } else { "Код выхода: $code." })
    return ($code -eq 0)
}

# ---------------------------------------------------------------- шаги 6–8: своя копия игры

function Get-GameFolder {
    $saved = ""
    if (Test-Path -LiteralPath $GameFolderFile) { $saved = (Get-Content -LiteralPath $GameFolderFile -Encoding UTF8 -TotalCount 1) }
    if ($saved) { Write-Log "Папка игры из прошлого раза: $saved" }
    $answer = Read-Host "Путь к папке игры (где лежат MicrosoftGame.Config и .rpf; Enter — оставить прежний)"
    $folder = if ($answer) { $answer.Trim().Trim('"') } else { $saved }
    if (-not $folder) { Write-Missing "Папка игры не указана" ""; return $null }
    if (-not (Test-Path -LiteralPath (Join-Path $folder "MicrosoftGame.Config"))) {
        Write-Missing "В папке нет MicrosoftGame.Config: $folder" "Укажите папку, где файлы игры лежат как обычные файлы."
        return $null
    }
    [System.IO.File]::WriteAllText($GameFolderFile, $folder, [System.Text.UTF8Encoding]::new($false))
    Write-Log "Папка игры: $folder"
    return $folder
}

function Step-Find {
    Write-Title "Шаг 6. Поиск копий игры на этом ПК"
    $code = Invoke-Python @("make_game.py", "--find")
    Write-Result "Поиск копий" ($code -eq 0) ""
    return ($code -eq 0)
}

function Step-GameCheck {
    Write-Title "Шаг 7. Проверка своей копии игры"
    $folder = Get-GameFolder
    if (-not $folder) { return $false }
    $code = Invoke-Python @("make_game.py", "--check", "--game", $folder)
    $exe = $script:LastOutput | Where-Object { $_ -match "Executable found|is not in the folder" } | Select-Object -Last 1
    Write-Result "Проверка копии" ($code -eq 0) $(if ($exe) { $exe } else { "" })
    return ($code -eq 0)
}

function Step-Port {
    Write-Title "Шаг 8. Сборка порта из своей копии"
    Write-Log "Стадии check, shaders и runtime: около 30 ГБ места и несколько часов на перевод шейдеров."
    Write-Log "Полная сборка с ресурсами (assets): около 400 ГБ. Прерванная сборка продолжается с места остановки."
    $folder = Get-GameFolder
    if (-not $folder) { return $false }
    $stages = Read-Host "Стадии через запятую (Enter — check,shaders,runtime)"
    if (-not $stages) { $stages = "check,shaders,runtime" }
    $code = Invoke-Python @("make_game.py", "--game", $folder, "--stages", $stages.Trim())
    Write-Result "Сборка порта" ($code -eq 0) "Код выхода: $code."
    return ($code -eq 0)
}

# ---------------------------------------------------------------- меню

$Steps = [ordered]@{
    "1" = @{ Key = "check";      Title = "Проверить компьютер (что установлено)";             Run = { Step-Check } }
    "2" = @{ Key = "build";      Title = "Собрать загрузчик dstnrt.exe";                      Run = { Step-Build } }
    "3" = @{ Key = "testgame";   Title = "Запустить тестовую игру (tiny_game)";               Run = { Step-TestGame } }
    "4" = @{ Key = "frame";      Title = "Тестовый кадр на Vulkan (tiny_frame)";              Run = { Step-Frame } }
    "5" = @{ Key = "tests";      Title = "Все тесты загрузчика (CTest)";                      Run = { Step-Tests } }
    "6" = @{ Key = "find";       Title = "Найти копии игры на этом ПК";                       Run = { Step-Find } }
    "7" = @{ Key = "game-check"; Title = "Проверить свою копию игры";                         Run = { Step-GameCheck } }
    "8" = @{ Key = "port";       Title = "Собрать порт из копии (шейдеры и загрузчик)";      Run = { Step-Port } }
}

Write-Log "DSTN (ДАСТАН) — стартовое меню для Windows. $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" Cyan
Write-Log "Репозиторий: $Root"
Write-Log "Журнал: $LogPath"
$exitCode = 0
try {
    if ($Step) {
        $entry = $Steps.Values | Where-Object { $_.Key -eq $Step } | Select-Object -First 1
        $ok = & $entry.Run
        if (-not $ok) { $exitCode = 1 }
    } else {
        while ($true) {
            Write-Host ""
            Write-Host "  DSTN — ДАСТАН · что делаем?" -ForegroundColor Cyan
            foreach ($number in $Steps.Keys) { Write-Host ("   {0}  {1}" -f $number, $Steps[$number].Title) }
            Write-Host "   9  Открыть папку с журналами"
            Write-Host "   0  Выход"
            $choice = (Read-Host "Номер").Trim()
            if ($choice -eq "0" -or $choice -eq "") { break }
            if ($choice -eq "9") { Start-Process explorer.exe $LogDir; continue }
            if (-not $Steps.Contains($choice)) { Write-Host "Нет такого пункта: $choice" -ForegroundColor Yellow; continue }
            $null = & $Steps[$choice].Run
        }
    }
} catch {
    Write-Log "Неожиданная ошибка: $($_.Exception.Message)" Red
    Write-Log ($_.ScriptStackTrace) DarkGray
    Write-Log "Пришлите разработчику файл журнала: $LogPath" Yellow
    $exitCode = 2
} finally {
    $script:Log.Dispose()
}
exit $exitCode
