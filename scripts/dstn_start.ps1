# DSTN (ДАСТАН): стартовое меню для Windows.
#
# Запуск: двойной щелчок по Start-DSTN.bat в корне репозитория. Один шаг без меню: Start-DSTN.bat <шаг>, где шаг —
# check, install, build, testgame, frame, tests, find, game-check или port.
#
# Каждый запуск пишет всё, что вывели шаги, в logs\dstn-<дата>.log. Этот лог можно присылать разработчику: в нём
# только вывод инструментов. Файлы игры, извлечённые ресурсы и шейдеры никуда не выкладывайте.
#
# Файл сохранён в UTF-8 с BOM: без BOM Windows PowerShell 5.1 читает его как ANSI и портит русский текст.
param(
    [ValidateSet("", "check", "install", "build", "testgame", "frame", "tests", "find", "game-check", "port")]
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

# Компоненты Visual Studio, без которых не собрать загрузчик: компилятор C++ x64, Windows SDK 10.0.26100 (корневые
# сигнатуры версии 1.2) и CMake с Ninja («C++ CMake tools for Windows»).
$VsComponents = @(
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "Microsoft.VisualStudio.Component.Windows11SDK.26100",
    "Microsoft.VisualStudio.Component.VC.CMake.Project"
)

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

function Confirm-Yes([string]$Question) {
    $answer = Read-Host "$Question [Д/н]"
    if ($null -eq $answer) { return $false }
    return @("", "д", "да", "y", "yes") -contains $answer.Trim().ToLowerInvariant()
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

# После установки программы PATH и переменные вроде VULKAN_SDK меняются только в реестре: перечитываем их, чтобы
# следующие шаги этого же окна увидели новые программы.
function Update-SessionEnvironment {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ";"
    foreach ($name in "VULKAN_SDK", "LLVM_MC") {
        $value = [Environment]::GetEnvironmentVariable($name, "User")
        if (-not $value) { $value = [Environment]::GetEnvironmentVariable($name, "Machine") }
        if ($value) { Set-Item -Path "Env:$name" -Value $value }
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
        Write-Missing "Python 3.12 или новее" "Пункт 2 «Установить недостающее» поставит его сам."
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

function Test-VsCMake([string]$Vs) {
    if (-not $Vs) { return $false }
    $cmakeDir = Join-Path $Vs "Common7\IDE\CommonExtensions\Microsoft\CMake"
    return (Test-Path -LiteralPath (Join-Path $cmakeDir "CMake\bin\cmake.exe")) -and
           (Test-Path -LiteralPath (Join-Path $cmakeDir "Ninja\ninja.exe"))
}

function Find-WindowsSdk {
    $kits = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\Include"
    if (-not (Test-Path -LiteralPath $kits)) { return $null }
    $sdk = Get-ChildItem -LiteralPath $kits -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^10\.0\.(\d+)\.\d+$' -and [int]$Matches[1] -ge 26100 } |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($sdk) { return $sdk.Name }
    return $null
}

function Test-VulkanSdk {
    return [bool]($env:VULKAN_SDK -and (Test-Path -LiteralPath (Join-Path $env:VULKAN_SDK "Bin\spirv-val.exe")))
}

function Test-DotNet8 {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { return $false }
    return (Invoke-Quiet "dotnet" @("--list-sdks")).Text -match '(?m)^([89]|\d{2,})\.'
}

function Test-Submodule {
    return Test-Path -LiteralPath (Join-Path $Root "third_party\rpf9-explorer\*")
}

# llvm-mc: путь, есть ли у него цель AMDGPU, и задан ли он командой (например, через WSL), которую не проверить.
function Find-LlvmMc {
    $mc = $env:LLVM_MC
    if (-not $mc) {
        $command = Get-Command llvm-mc -ErrorAction SilentlyContinue
        if ($command) { $mc = $command.Source }
    }
    if (-not $mc) { return @{ Path = ""; Amdgpu = $false; Command = $false } }
    if (-not (Test-Path -LiteralPath $mc)) { return @{ Path = $mc; Amdgpu = $false; Command = $true } }
    $amdgpu = (Invoke-Quiet $mc @("--version")).Text -match "amdgcn"
    return @{ Path = $mc; Amdgpu = $amdgpu; Command = $false }
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
        Write-Missing "Загрузчик dstnrt.exe ещё не собран" "Сначала выполните пункт 3 «Собрать загрузчик»."
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
    if (Get-Command winget -ErrorAction SilentlyContinue) { Write-Ok "winget (для автоматической установки)" }
    else { Write-Optional "winget не найден" "Без него пункт 2 ничего не поставит: установите «App Installer» из Microsoft Store." }

    Write-Log ""
    Write-Log "Для загрузчика dstnrt.exe и тестовой игры (пункты 3–6):"
    $vs = Find-VisualStudio
    if ($vs) { Write-Ok "Visual Studio с C++ x64: $vs" }
    else { Write-Missing "Visual Studio 2022 с C++ (подойдут бесплатные Build Tools)" "Пункт 2 поставит Build Tools сам."; $required++ }
    if (Test-VsCMake $vs) { Write-Ok "CMake и Ninja из Visual Studio" }
    elseif ($vs) { Write-Missing "Компонент Visual Studio «C++ CMake tools for Windows»" "Пункт 2 добавит его в вашу Visual Studio."; $required++ }
    $sdk = Find-WindowsSdk
    if ($sdk) { Write-Ok "Windows SDK $sdk" }
    else { Write-Missing "Windows SDK 10.0.26100 или новее" "Пункт 2 добавит его в Visual Studio."; $required++ }

    Write-Log ""
    Write-Log "Для кадра на Vulkan и переведённых шейдеров (пункты 5, 8, 9):"
    if (Test-VulkanSdk) {
        Write-Ok "Vulkan SDK: $env:VULKAN_SDK"
        $vulkaninfo = Join-Path $env:VULKAN_SDK "Bin\vulkaninfo.exe"
        if (Test-Path -LiteralPath $vulkaninfo) {
            $devices = @((Invoke-Quiet $vulkaninfo @("--summary")).Text -split "`n" | Where-Object { $_ -match "deviceName" })
            if ($devices.Count) { foreach ($d in $devices) { Write-Ok ("Видеокарта Vulkan: " + ($d -replace '^\s*deviceName\s*=\s*', '')) } }
            else { Write-Missing "vulkaninfo не нашёл ни одной видеокарты Vulkan" "Обновите драйвер видеокарты." }
        }
    } else {
        Write-Optional "Vulkan SDK не найден (переменная VULKAN_SDK)" "Пункт 2 поставит его сам."
    }

    Write-Log ""
    Write-Log "Для сборки порта из своей копии игры (пункты 7–9):"
    $python = Find-Python
    if ($python) { Write-Ok ("Python: " + ($python -join " ")) }
    else { Write-Missing "Python 3.12 или новее" "Пункт 2 поставит его сам."; $required++ }
    if (Get-Command git -ErrorAction SilentlyContinue) { Write-Ok "Git" }
    else { Write-Optional "Git не найден" "Пункт 2 поставит его сам; он нужен для подмодуля и для сборки llvm-mc." }
    if (Test-Submodule) { Write-Ok "Подмодуль third_party\rpf9-explorer" }
    else { Write-Optional "Подмодуль third_party\rpf9-explorer пуст" "Пункт 2 докачает его (нужен только для экспорта ресурсов)." }
    if (Test-DotNet8) { Write-Ok ".NET SDK 8+" }
    else { Write-Optional ".NET 8 SDK не найден" "Пункт 2 поставит его сам (нужен для экспорта ресурсов, rpf9dump)." }
    $mc = Find-LlvmMc
    if ($mc.Amdgpu) { Write-Ok "llvm-mc с целью AMDGPU: $($mc.Path)" }
    elseif ($mc.Command) { Write-Optional "LLVM_MC задан командой: $($mc.Path)" "Эту команду (например, через WSL) проверка не запускает." }
    elseif ($mc.Path) { Write-Optional "llvm-mc без цели AMDGPU: $($mc.Path)" "Пункт 2 соберёт подходящий (20–40 минут)." }
    else { Write-Optional "llvm-mc не найден" "Нужен для перевода шейдеров; пункт 2 соберёт его (20–40 минут)." }
    if (Get-Command ffmpeg -ErrorAction SilentlyContinue) { Write-Ok "ffmpeg" }
    else { Write-Optional "ffmpeg не найден" "Необязательно: нужен только для звука XMA2 и --wav." }

    $note = "Обязательного не хватает: $required."
    if ($required) { $note += " Запустите пункт 2 «Установить недостающее»." }
    Write-Result "Проверка компьютера" ($required -eq 0) $note
    return ($required -eq 0)
}

# ---------------------------------------------------------------- шаг 2: автоматическая установка

function Install-WithWinget([string]$Name, [string]$Id, [string]$Override = "") {
    $arguments = @("install", "--id", $Id, "--exact", "--source", "winget",
                   "--accept-package-agreements", "--accept-source-agreements")
    if ($Override) { $arguments += @("--override", $Override) } else { $arguments += "--silent" }
    Write-Log ""
    Write-Log "--- $Name (winget: $Id)" Cyan
    $code = Invoke-Logged "winget" $arguments
    Update-SessionEnvironment
    return $code
}

# Добавляет компоненты в уже установленную Visual Studio её собственным установщиком (нужны права администратора:
# Windows покажет запрос UAC).
function Add-VsComponents([string]$Vs) {
    $setup = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\setup.exe"
    if (-not (Test-Path -LiteralPath $setup)) {
        Write-Missing "Установщик Visual Studio не найден: $setup" "Откройте Visual Studio Installer и добавьте компоненты вручную."
        return -1
    }
    $arguments = @("modify", "--installPath", "`"$Vs`"", "--passive", "--norestart")
    foreach ($component in $VsComponents) { $arguments += @("--add", $component) }
    Write-Log ""
    Write-Log "--- Компоненты Visual Studio (откроется окно установщика и запрос прав администратора)" Cyan
    Write-Log ("> " + $setup + " " + ($arguments -join " ")) DarkGray
    try {
        $process = Start-Process -FilePath $setup -ArgumentList $arguments -Verb RunAs -Wait -PassThru
        Write-Log "Установщик Visual Studio завершился с кодом $($process.ExitCode)."
        return $process.ExitCode
    } catch {
        Write-Log "Не удалось запустить установщик Visual Studio: $($_.Exception.Message)" Red
        return -1
    }
}

function Step-Install {
    Write-Title "Шаг 2. Установка недостающего"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Missing "winget не найден" "Установите «App Installer» из Microsoft Store: https://apps.microsoft.com/detail/9NBLGGH4NNS1 — и запустите пункт 2 снова."
        Write-Result "Установка" $false
        return $false
    }

    $vsOverride = "--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools " +
                  (($VsComponents | ForEach-Object { "--add $_" }) -join " ")
    $plan = New-Object System.Collections.Generic.List[object]
    if (-not (Find-Python)) {
        $plan.Add(@{ Name = "Python 3.12"; Id = "Python.Python.3.12"
                     Override = "/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1" })
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { $plan.Add(@{ Name = "Git"; Id = "Git.Git"; Override = "" }) }
    $vs = Find-VisualStudio
    if (-not $vs) {
        $plan.Add(@{ Name = "Visual Studio 2022 Build Tools (C++, Windows SDK 26100, CMake)"
                     Id = "Microsoft.VisualStudio.2022.BuildTools"; Override = $vsOverride })
    } elseif (-not (Find-WindowsSdk) -or -not (Test-VsCMake $vs)) {
        $plan.Add(@{ Name = "Компоненты Visual Studio: Windows SDK 26100 и C++ CMake tools"; Id = ""; Override = ""; Vs = $vs })
    }
    if (-not (Test-VulkanSdk)) { $plan.Add(@{ Name = "Vulkan SDK"; Id = "KhronosGroup.VulkanSDK"; Override = "" }) }
    if (-not (Test-DotNet8)) { $plan.Add(@{ Name = ".NET 8 SDK"; Id = "Microsoft.DotNet.SDK.8"; Override = "" }) }

    $needSubmodule = -not (Test-Submodule)
    $needLlvmMc = -not (Find-LlvmMc).Amdgpu -and -not (Find-LlvmMc).Command
    $needFfmpeg = -not (Get-Command ffmpeg -ErrorAction SilentlyContinue)

    if ($plan.Count -eq 0 -and -not $needSubmodule -and -not $needLlvmMc -and -not $needFfmpeg) {
        Write-Result "Установка" $true "Всё нужное уже установлено."
        return $true
    }
    if ($plan.Count) {
        Write-Log "Будет установлено через winget (с официальных источников):"
        foreach ($item in $plan) { Write-Log "  • $($item.Name)" }
        Write-Log "Установка принимает лицензии этих программ (Microsoft, Python, Git, Khronos). Windows может спросить"
        Write-Log "права администратора для каждой. Visual Studio Build Tools скачивает несколько гигабайт."
        if (-not (Confirm-Yes "Установить?")) {
            Write-Log "Установка отменена."
            $plan.Clear()
        }
    }

    $failed = 0
    foreach ($item in $plan) {
        if ($item.Id) { $code = Install-WithWinget $item.Name $item.Id $item.Override }
        else { $code = Add-VsComponents $item.Vs }
        Update-SessionEnvironment
        if ($code -ne 0) { Write-Log "  Код выхода $($code) — проверю ниже, установилось ли." DarkYellow }
    }

    if ($needSubmodule -and (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log ""
        Write-Log "--- Подмодуль third_party\rpf9-explorer" Cyan
        $null = Invoke-Logged "git" @("submodule", "update", "--init", "--recursive") $Root
    }

    if ($needLlvmMc) {
        Write-Log ""
        Write-Log "llvm-mc с целью AMDGPU нужен для перевода шейдеров. Готового для Windows нет: он собирается из исходников"
        Write-Log "LLVM (около 2 ГБ временного места, 20–40 минут). Нужны Git, Python и Visual Studio из списка выше."
        if ((Get-Command git -ErrorAction SilentlyContinue) -and (Find-Python) -and (Find-VisualStudio)) {
            if (Confirm-Yes "Собрать llvm-mc сейчас?") {
                $powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
                $null = Invoke-Logged $powershell @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                                                   (Join-Path $PSScriptRoot "build_llvm_mc.ps1")) $Root
                Update-SessionEnvironment
            }
        } else {
            Write-Log "Сначала должны установиться Git, Python и Visual Studio; затем запустите пункт 2 ещё раз." DarkYellow
        }
    }

    if ($needFfmpeg -and (Confirm-Yes "Установить необязательный ffmpeg (звук XMA2 и --wav)?")) {
        $null = Install-WithWinget "ffmpeg" "Gyan.FFmpeg"
    }

    Write-Log ""
    Write-Log "Проверяю, что получилось:"
    $ok = Step-Check
    if (-not $ok) {
        Write-Log "Если программа только что установилась, но здесь её нет, закройте окно и запустите Start-DSTN.bat заново:" Yellow
        Write-Log "некоторые установщики меняют PATH так, что это видно только новым окнам." Yellow
    }
    return $ok
}

# ---------------------------------------------------------------- шаги 3–6: загрузчик и тестовые игры

function Step-Build {
    Write-Title "Шаг 3. Сборка загрузчика dstnrt.exe"
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
    Write-Title "Шаг 4. Тестовая игра tiny_game"
    $loader = Get-Loader
    $game = Find-Built "tiny_game.exe"
    if (-not $loader) { return $false }
    if (-not $game) {
        Write-Missing "tiny_game.exe не собран" "Нужны CMake и Ninja из Visual Studio (пункт 2), затем пункт 3."
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
    Write-Title "Шаг 5. Тестовый кадр на Vulkan (tiny_frame)"
    $loader = Get-Loader
    if (-not $loader) { return $false }
    $frame = Find-Built "tiny_frame.exe"
    if (-not $frame) {
        Write-Missing "tiny_frame.exe не собран" "Он собирается, когда при сборке (пункт 3) найден Vulkan SDK."
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
    Write-Title "Шаг 6. Все тесты загрузчика (CTest)"
    $ctest = Find-CTest
    if (-not $ctest) {
        Write-Missing "ctest не найден" "Пункт 2 добавит в Visual Studio компонент «C++ CMake tools for Windows»; затем пункт 3."
        return $false
    }
    if (-not (Test-Path -LiteralPath (Join-Path $BuildDir "CTestTestfile.cmake"))) {
        Write-Missing "В runtime\build нет тестов CTest" "Сначала пункт 3 (сборка через CMake)."
        return $false
    }
    $jobs = [Math]::Max(1, [int]([Environment]::ProcessorCount / 2))
    $code = Invoke-Logged $ctest @("--test-dir", $BuildDir, "-C", "RelWithDebInfo", "--output-on-failure", "-j", "$jobs") $Root
    $summary = $script:LastOutput | Where-Object { $_ -match "tests passed" } | Select-Object -Last 1
    Write-Result "Тесты загрузчика" ($code -eq 0) $(if ($summary) { $summary } else { "Код выхода: $code." })
    return ($code -eq 0)
}

# ---------------------------------------------------------------- шаги 7–9: своя копия игры

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
    Write-Title "Шаг 7. Поиск копий игры на этом ПК"
    $code = Invoke-Python @("make_game.py", "--find")
    Write-Result "Поиск копий" ($code -eq 0) ""
    return ($code -eq 0)
}

function Step-GameCheck {
    Write-Title "Шаг 8. Проверка своей копии игры"
    $folder = Get-GameFolder
    if (-not $folder) { return $false }
    $code = Invoke-Python @("make_game.py", "--check", "--game", $folder)
    $exe = $script:LastOutput | Where-Object { $_ -match "Executable found|is not in the folder" } | Select-Object -Last 1
    Write-Result "Проверка копии" ($code -eq 0) $(if ($exe) { $exe } else { "" })
    return ($code -eq 0)
}

function Step-Port {
    Write-Title "Шаг 9. Сборка порта из своей копии"
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
    "2" = @{ Key = "install";    Title = "Установить недостающее автоматически";              Run = { Step-Install } }
    "3" = @{ Key = "build";      Title = "Собрать загрузчик dstnrt.exe";                      Run = { Step-Build } }
    "4" = @{ Key = "testgame";   Title = "Запустить тестовую игру (tiny_game)";               Run = { Step-TestGame } }
    "5" = @{ Key = "frame";      Title = "Тестовый кадр на Vulkan (tiny_frame)";              Run = { Step-Frame } }
    "6" = @{ Key = "tests";      Title = "Все тесты загрузчика (CTest)";                      Run = { Step-Tests } }
    "7" = @{ Key = "find";       Title = "Найти копии игры на этом ПК";                       Run = { Step-Find } }
    "8" = @{ Key = "game-check"; Title = "Проверить свою копию игры";                         Run = { Step-GameCheck } }
    "9" = @{ Key = "port";       Title = "Собрать порт из копии (шейдеры и загрузчик)";      Run = { Step-Port } }
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
            Write-Host "  10  Открыть папку с журналами"
            Write-Host "   0  Выход"
            $choice = Read-Host "Номер"
            if ($null -eq $choice) { break }
            $choice = $choice.Trim()
            if ($choice -eq "0" -or $choice -eq "") { break }
            if ($choice -eq "10") { Start-Process explorer.exe $LogDir; continue }
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
