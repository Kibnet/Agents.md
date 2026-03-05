param(
    [string]$RootPath = (Join-Path $PSScriptRoot "..")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path $RootPath).Path
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Error {
    param([string]$Message)
    $errors.Add($Message)
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Add-Warning {
    param([string]$Message)
    $warnings.Add($Message)
    Write-Host "WARN: $Message" -ForegroundColor Yellow
}

function Add-Info {
    param([string]$Message)
    Write-Host "INFO: $Message" -ForegroundColor Cyan
}

Add-Info "Проверка каталога: $resolvedRoot"

$requiredPaths = @(
    "AGENTS.md",
    "CHANGELOG.md",
    "instructions/core/quest-governance.md",
    "instructions/core/quest-mode.md",
    "instructions/core/quest-prompt-spec.md",
    "instructions/core/quest-prompt-exec.md",
    "instructions/core/collaboration-baseline.md",
    "instructions/core/testing-baseline.md",
    "instructions/contexts/debug-dotnet-mcp-coreclr.md",
    "instructions/contexts/performance-optimization.md",
    "instructions/contexts/testing-dotnet.md",
    "instructions/contexts/testing-frontend.md",
    "instructions/profiles/dotnet-backend-api.md",
    "instructions/profiles/dotnet-desktop-client.md",
    "instructions/profiles/dotnet-ravendb.md",
    "instructions/profiles/frontend-spa-typescript.md",
    "instructions/profiles/ui-automation-testing.md",
    "instructions/profiles/python-hardware-gpio.md",
    "instructions/governance/routing-matrix.md",
    "instructions/governance/document-contract.md",
    "instructions/governance/versioning-policy.md",
    "instructions/governance/spec-linter.md",
    "instructions/governance/spec-rubric.md",
    "instructions/governance/commit-message-policy.md",
    "instructions/onboarding/quick-start.md",
    "instructions/onboarding/AGENTS.consumer.template.md",
    "instructions/onboarding/AGENTS.override.template.md",
    "instructions/profiles/domain-logic-extraction.md",
    "instructions/profiles/product-system-design.md",
    "instructions/profiles/refactor-architecture.md",
    "instructions/profiles/refactor-mechanical.md",
    "instructions/profiles/rendering-pipeline.md",
    "instructions/profiles/ui-feature-parity.md",
    "scripts/validate-instructions.ps1",
    "scripts/test-validate-instructions.ps1"
)

foreach ($relativePath in $requiredPaths) {
    $fullPath = Join-Path $resolvedRoot $relativePath
    if (-not (Test-Path $fullPath)) {
        Add-Error "Отсутствует обязательный путь: $relativePath"
    }
}

$instructionsRoot = Join-Path $resolvedRoot "instructions"
if (-not (Test-Path $instructionsRoot)) {
    Add-Error "Отсутствует каталог instructions"
}
else {
    $dirPattern = '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    $namePattern = '^[a-z0-9]+(?:-[a-z0-9]+)*\.md$'
    $nameExceptions = @(
        "AGENTS.consumer.template.md",
        "AGENTS.override.template.md"
    )

    Get-ChildItem -Path $instructionsRoot -Recurse -Directory | ForEach-Object {
        if ($_.Name -notmatch $dirPattern) {
            Add-Error "Имя каталога не соответствует kebab-case: $($_.FullName)"
        }
    }

    $requiredHeadings = @(
        "## Когда применять",
        "## Когда не применять",
        "## MUST",
        "## SHOULD",
        "## MAY",
        "## Связанные документы"
    )

    Get-ChildItem -Path $instructionsRoot -Recurse -File -Filter *.md | ForEach-Object {
        $file = $_

        if (($file.Name -notin $nameExceptions) -and ($file.Name -notmatch $namePattern)) {
            Add-Error "Имя файла не соответствует kebab-case: $($file.FullName)"
        }

        $content = Get-Content -Path $file.FullName -Raw

        foreach ($heading in $requiredHeadings) {
            $escaped = [regex]::Escape($heading)
            if ($content -notmatch "(?m)^$escaped\s*$") {
                Add-Error "В файле $($file.FullName) отсутствует секция '$heading'"
            }
        }

        if ($content -notmatch "(?m)^## Команды\s*$") {
            Add-Warning "В файле $($file.FullName) нет секции '## Команды'"
        }
    }
}

$legacyNames = @(
    "Agents.md",
    "Agents_arm.md",
    "Agents_COMMON.md",
    "Agents_doc.md",
    "Agents_MathHelper.md",
    "AGENTS_DEBUG.md",
    "AGENTS_DEBUG2.md",
    "AGENTS_PERF.md",
    "AGENTS_PYTHON.md",
    "DEBUG_RUNBOOK.md",
    "DEBUG_RUNBOOK2.md",
    "DEBUG_RUNBOOK3.md",
    "PERFORMANCE_OPTIMIZATION_AGENT_INSTRUCTIONS.md",
    "UI_TESTS.md",
    "utep-dotnet.md",
    "arm-dotnet-ravendb.md",
    "doc-frontend.md",
    "mathhelper-frontend.md",
    "python-servo-generator.md",
    "doc-ui-tests.md"
)

$legacyScanFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
$agentsIndex = Join-Path $resolvedRoot "AGENTS.md"
if (Test-Path $agentsIndex) {
    $legacyScanFiles.Add((Get-Item $agentsIndex))
}
if (Test-Path $instructionsRoot) {
    Get-ChildItem -Path $instructionsRoot -Recurse -File -Filter *.md | ForEach-Object {
        $legacyScanFiles.Add($_)
    }
}

foreach ($mdFile in $legacyScanFiles) {
    foreach ($legacyName in $legacyNames) {
        $hits = Select-String -Path $mdFile.FullName -SimpleMatch -CaseSensitive $legacyName
        foreach ($hit in $hits) {
            Add-Error "Обнаружена ссылка/упоминание legacy-файла '$legacyName' в $($mdFile.FullName):$($hit.LineNumber)"
        }
    }
}

function Remove-CodeFenceContent {
    param([string]$Markdown)

    $lines = $Markdown -split "\r?\n"
    $inFence = $false
    $buffer = New-Object System.Text.StringBuilder

    foreach ($line in $lines) {
        if ($line -match '^\s*(```|~~~)') {
            $inFence = -not $inFence
            [void]$buffer.AppendLine("")
            continue
        }

        if ($inFence) {
            [void]$buffer.AppendLine("")
            continue
        }

        [void]$buffer.AppendLine($line)
    }

    return $buffer.ToString()
}

function Get-InlineMarkdownTargets {
    param([string]$Markdown)

    $targets = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($Markdown)) {
        return $targets
    }

    $length = $Markdown.Length
    $i = 0
    while ($i -lt $length) {
        if ($Markdown[$i] -ne '[') {
            $i++
            continue
        }

        if ($i -gt 0 -and $Markdown[$i - 1] -eq '!') {
            $i++
            continue
        }

        $j = $i + 1
        while ($j -lt $length) {
            if ($Markdown[$j] -eq '\') {
                $j += 2
                continue
            }
            if ($Markdown[$j] -eq ']') {
                break
            }
            $j++
        }

        if ($j -ge $length) {
            break
        }

        $k = $j + 1
        while ($k -lt $length -and [char]::IsWhiteSpace($Markdown[$k])) {
            $k++
        }

        if ($k -ge $length -or $Markdown[$k] -ne '(') {
            $i = $j + 1
            continue
        }

        $k++
        $targetStart = $k
        $depth = 1
        while ($k -lt $length) {
            if ($Markdown[$k] -eq '\') {
                $k += 2
                continue
            }
            if ($k -ge $length) {
                break
            }

            if ($Markdown[$k] -eq '(') {
                $depth++
            }
            elseif ($Markdown[$k] -eq ')') {
                $depth--
                if ($depth -eq 0) {
                    break
                }
            }
            $k++
        }

        if ($k -lt $length -and $depth -eq 0) {
            $target = $Markdown.Substring($targetStart, $k - $targetStart).Trim()
            if (-not [string]::IsNullOrWhiteSpace($target)) {
                $targets.Add($target)
            }
            $i = $k + 1
            continue
        }

        $i = $j + 1
    }

    return $targets
}

function Get-ReferenceDefinitions {
    param([string]$Markdown)

    $definitions = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $pattern = '(?m)^\s{0,3}\[([^\]]+)\]:\s*(<[^>]+>|\S+)'
    $matches = [regex]::Matches($Markdown, $pattern)

    foreach ($match in $matches) {
        $id = $match.Groups[1].Value.Trim()
        $target = $match.Groups[2].Value.Trim()
        if ($target.StartsWith("<") -and $target.EndsWith(">")) {
            $target = $target.TrimStart("<").TrimEnd(">")
        }

        if ((-not [string]::IsNullOrWhiteSpace($id)) -and (-not [string]::IsNullOrWhiteSpace($target))) {
            $definitions[$id] = $target
        }
    }

    return $definitions
}

function Get-ReferenceUsages {
    param([string]$Markdown)

    $usages = New-Object System.Collections.Generic.List[string]
    $pattern = '(?<!\!)\[[^\]]+\]\[([^\]]+)\]'
    $matches = [regex]::Matches($Markdown, $pattern)

    foreach ($match in $matches) {
        $id = $match.Groups[1].Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            $usages.Add($id)
        }
    }

    return $usages
}

function Test-LinkTarget {
    param(
        [string]$SourceFile,
        [string]$Target
    )

    $trimmed = $Target.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { return }

    if ($trimmed.StartsWith("http://") -or
        $trimmed.StartsWith("https://") -or
        $trimmed.StartsWith("mailto:") -or
        $trimmed.StartsWith("#")) {
        return
    }

    if ($trimmed.StartsWith("<") -and $trimmed.EndsWith(">")) {
        $trimmed = $trimmed.TrimStart("<").TrimEnd(">")
    }

    if ($trimmed -match '\s"') {
        $trimmed = $trimmed.Split(' ')[0]
    }

    $targetWithoutAnchor = $trimmed.Split('#')[0]
    if ([string]::IsNullOrWhiteSpace($targetWithoutAnchor)) { return }

    $targetWithoutAnchor = [System.Uri]::UnescapeDataString($targetWithoutAnchor)

    $resolvedTarget = $null
    if ([System.IO.Path]::IsPathRooted($targetWithoutAnchor)) {
        $resolvedTarget = $targetWithoutAnchor
    }
    else {
        $sourceDir = Split-Path -Path $SourceFile -Parent
        $resolvedTarget = Join-Path $sourceDir $targetWithoutAnchor
    }

    try {
        $normalized = [System.IO.Path]::GetFullPath($resolvedTarget)
    }
    catch {
        Add-Error "Некорректный путь в ссылке '$Target' (файл $SourceFile)"
        return
    }

    if (-not (Test-Path $normalized)) {
        Add-Error "Битая ссылка '$Target' в файле $SourceFile"
    }
}

$markdownFiles = Get-ChildItem -Path $resolvedRoot -Recurse -File -Filter *.md
foreach ($mdFile in $markdownFiles) {
    $raw = Get-Content -Path $mdFile.FullName -Raw
    $content = Remove-CodeFenceContent -Markdown $raw

    $inlineTargets = Get-InlineMarkdownTargets -Markdown $content
    foreach ($target in $inlineTargets) {
        Test-LinkTarget -SourceFile $mdFile.FullName -Target $target
    }

    $referenceDefinitions = Get-ReferenceDefinitions -Markdown $content
    foreach ($entry in $referenceDefinitions.GetEnumerator()) {
        Test-LinkTarget -SourceFile $mdFile.FullName -Target $entry.Value
    }

    $referenceUsages = Get-ReferenceUsages -Markdown $content
    foreach ($usage in $referenceUsages) {
        if (-not $referenceDefinitions.ContainsKey($usage)) {
            Add-Error "Ссылка на reference id '$usage' без определения в файле $($mdFile.FullName)"
        }
    }
}

if ($warnings.Count -gt 0) {
    Add-Info "Предупреждений: $($warnings.Count)"
}

if ($errors.Count -gt 0) {
    Add-Info "Проверка завершена с ошибками: $($errors.Count)"
    exit 1
}

Add-Info "Проверка завершена успешно"
exit 0
