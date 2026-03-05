# Context: Visual Feedback Loop (Desktop Window Capture)

## Когда применять

- Когда нужна визуальная проверка изменений в desktop UI.
- Когда нужно собрать артефакты (PNG/MP4) для обратной связи и подтверждения поведения окна.
- Когда задача требует подтверждения по кадру/видео до завершения.

## Когда не применять

- Для headless-среды без активной desktop-сессии.
- Для задач, где достаточно логов/юнит-тестов и визуальная проверка не влияет на результат.
- Для Linux/Mac-платформ без соответствующих инструментов захвата окна.

## MUST

- Перед захватом находить точный заголовок окна через `MainWindowTitle`.
- Захватывать только существующее, активное и неноминизированное окно (`gdigrab`/`ffmpeg`).
- Всегда сохранять артефакты с меткой времени и привязывать их к шагу проверки.
- Для нестабильного визуального результата переснимать и фиксировать причинно-следственную связь с изменением.
- Проверять результат: скриншот — по статике, видео — по последовательности переходов/анимаций.

## SHOULD

- Проверять масштаб и DPI перед сравнением.
- Предварительно нормировать размер окна для более стабильных сравнений.
- При невозможности смотреть MP4 извлекать кадры и сравнивать PNG.

## MAY

- Для быстрых ad-hoc проверок использовать `nircmdc.exe savescreenshotwin`.
- Добавлять скрипт-обёртку с retry при ожидании появления окна.

## Команды

### Нужен список окон

```powershell
Get-Process |
  Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle } |
  Select-Object ProcessName, Id, MainWindowTitle |
  Format-Table -AutoSize
```

### Скриншот активного окна

```powershell
nircmdc.exe savescreenshotwin "C:\Temp\active-window.png"
```

### Скриншот конкретного окна

```powershell
ffmpeg -y -f gdigrab -framerate 1 -i "title=TOOL_WINDOW_TITLE" -frames:v 1 -update 1 "C:\Temp\window.png"
```

### Видео конкретного окна

```powershell
ffmpeg -y -f gdigrab -framerate 15 -i "title=TOOL_WINDOW_TITLE" -t 10 -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p "C:\Temp\window.mp4"
```

### Готовый feedback-loop скрипт

```powershell
$partialTitle = "DotnetDebug"
$outDir = "C:\Temp\ui-feedback"
$timeoutSec = 30
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$pngPath = Join-Path $outDir "window-$stamp.png"
$mp4Path = Join-Path $outDir "window-$stamp.mp4"

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$proc = $null
while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
    $proc = Get-Process |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -like "*$partialTitle*" } |
        Select-Object -First 1
    if ($proc) { break }
    Start-Sleep -Milliseconds 500
}

if (-not $proc) {
    throw "Окно с заголовком, содержащим '$partialTitle', не найдено за $timeoutSec сек."
}

$title = $proc.MainWindowTitle
ffmpeg -y -f gdigrab -framerate 1 -i "title=$title" -frames:v 1 -update 1 $pngPath | Out-Null
ffmpeg -y -f gdigrab -framerate 15 -i "title=$title" -t 8 -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p $mp4Path | Out-Null

Write-Host "PNG: $pngPath"
Write-Host "MP4: $mp4Path"
```

## Ограничения

- `gdigrab` не захватывает свернутое окно.
- Заголовок в `title=...` должен быть точным/достаточно уникальным.
- Для стабильной проверки фиксировать DPI и размер окна.
- В headless-среде захват окна может не работать.

## Связанные документы

- [instructions/core/testing-baseline.md](../core/testing-baseline.md)
- [instructions/core/collaboration-baseline.md](../core/collaboration-baseline.md)
- [instructions/profiles/ui-automation-testing.md](../profiles/ui-automation-testing.md)
- [instructions/profiles/dotnet-desktop-client.md](../profiles/dotnet-desktop-client.md)

