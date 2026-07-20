[CmdletBinding()]
param(
    [switch]$SkipAgentOperations
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$validator = Join-Path $root "scripts/validate-instructions.ps1"

if (-not (Test-Path $validator)) {
    Write-Host "FAIL: validator not found: $validator" -ForegroundColor Red
    exit 1
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agents-validator-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

$failed = $false

function Invoke-Validation {
    param(
        [string]$ScenarioName,
        [string]$ScenarioPath,
        [bool]$ShouldPass
    )

    & pwsh -NoProfile -File $validator -RootPath $ScenarioPath *> $null
    $code = $LASTEXITCODE

    if ($ShouldPass -and $code -ne 0) {
        Write-Host "FAIL: сценарий '$ScenarioName' должен проходить, но вернул $code" -ForegroundColor Red
        return $false
    }

    if ((-not $ShouldPass) -and $code -eq 0) {
        Write-Host "FAIL: сценарий '$ScenarioName' должен падать, но вернул 0" -ForegroundColor Red
        return $false
    }

    Write-Host "PASS: $ScenarioName" -ForegroundColor Green
    return $true
}

try {
    $scenarioRoot = Join-Path $tempRoot "scenario"
    New-Item -ItemType Directory -Path $scenarioRoot | Out-Null

    $seedPaths = @(
        "AGENTS.md",
        "CHANGELOG.md",
        "README.md",
        ".github",
        "prompts",
        "schemas",
        "session-insights",
        "templates",
        "specs",
        "instructions",
        "scripts"
    )

    foreach ($seedPath in $seedPaths) {
        Copy-Item -Path (Join-Path $root $seedPath) -Destination $scenarioRoot -Recurse -Force
    }

    # Scenario 1: valid catalog
    if (-not (Invoke-Validation -ScenarioName "валидный каталог" -ScenarioPath $scenarioRoot -ShouldPass $true)) {
        $failed = $true
    }

    # Scenario 2: missing required section
    $targetFile = Join-Path $scenarioRoot "instructions/core/collaboration-baseline.md"
    $original = Get-Content -Path $targetFile -Raw
    try {
        $modified = $original -replace "## SHOULD", "## SHOULD_REMOVED"
        Set-Content -Path $targetFile -Value $modified -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "отсутствует обязательная секция" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $targetFile -Value $original -Encoding UTF8
    }

    # Scenario 3: missing commands section
    $commandsFile = Join-Path $scenarioRoot "instructions/core/quest-mode.md"
    $original = Get-Content -Path $commandsFile -Raw
    try {
        $modified = $original -replace "## Команды", "## COMMANDS_REMOVED"
        Set-Content -Path $commandsFile -Value $modified -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "отсутствует секция команды" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $commandsFile -Value $original -Encoding UTF8
    }

    # Scenario 4: broken markdown link
    $linkFile = Join-Path $scenarioRoot "instructions/governance/routing-matrix.md"
    $original = Get-Content -Path $linkFile -Raw
    try {
        Add-Content -Path $linkFile -Value "`nПроверка ссылки: [broken](./missing(folder)/file.md)" -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "битая ссылка" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $linkFile -Value $original -Encoding UTF8
    }

    # Scenario 5: legacy reference
    $legacyFile = Join-Path $scenarioRoot "instructions/core/testing-baseline.md"
    $original = Get-Content -Path $legacyFile -Raw
    try {
        Add-Content -Path $legacyFile -Value "`nLegacy marker: Agents_COMMON.md" -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "legacy reference" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $legacyFile -Value $original -Encoding UTF8
    }

    # Scenario 6: unresolved reference link
    $referenceFile = Join-Path $scenarioRoot "instructions/governance/versioning-policy.md"
    $original = Get-Content -Path $referenceFile -Raw
    try {
        Add-Content -Path $referenceFile -Value "`nСсылка без определения: [policy][missing-id]" -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "reference link без определения" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $referenceFile -Value $original -Encoding UTF8
    }

    # Scenario 7: missing canonical spec template
    $templateFile = Join-Path $scenarioRoot "templates/specs/_template.md"
    $original = Get-Content -Path $templateFile -Raw
    try {
        Remove-Item -Path $templateFile -Force
        if (-not (Invoke-Validation -ScenarioName "отсутствует canonical spec template" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $templateFile -Value $original -Encoding UTF8
    }

    # Scenario 8: deprecated template path reference in active docs
    $deprecatedPathFile = Join-Path $scenarioRoot "README.md"
    $original = Get-Content -Path $deprecatedPathFile -Raw
    try {
        Add-Content -Path $deprecatedPathFile -Value "`nСтарый путь template: specs/_template.md" -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "устаревший template path" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $deprecatedPathFile -Value $original -Encoding UTF8
    }

    # Scenario 9: missing Responses API owner
    $responsesOwnerFile = Join-Path $scenarioRoot "instructions/governance/openai-responses-api.md"
    $original = Get-Content -Path $responsesOwnerFile -Raw
    try {
        Remove-Item -Path $responsesOwnerFile -Force
        if (-not (Invoke-Validation -ScenarioName "отсутствует Responses API owner" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $responsesOwnerFile -Value $original -Encoding UTF8
    }

    # Scenario 10: stale declared GPT-5.5 target
    $modelBaselineFile = Join-Path $scenarioRoot "instructions/core/model-behavior-baseline.md"
    $original = Get-Content -Path $modelBaselineFile -Raw
    try {
        $modified = $original.Replace(
            'Считать семейство `GPT-5.6` целевой optimization baseline каталога',
            'Считать `gpt-5.5` целевой моделью каталога'
        )
        Set-Content -Path $modelBaselineFile -Value $modified -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "устаревший declared target GPT-5.5" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $modelBaselineFile -Value $original -Encoding UTF8
    }

    # Scenario 11: missing mandatory tool-execution owner
    $toolOwnerFile = Join-Path $scenarioRoot "instructions/core/tool-execution-baseline.md"
    $original = Get-Content -Path $toolOwnerFile -Raw
    try {
        Remove-Item -Path $toolOwnerFile -Force
        if (-not (Invoke-Validation -ScenarioName "отсутствует tool-execution owner" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $toolOwnerFile -Value $original -Encoding UTF8
    }

    # Scenario 12: tool-heavy routing is no longer mandatory
    $routingFile = Join-Path $scenarioRoot "instructions/governance/routing-matrix.md"
    $original = Get-Content -Path $routingFile -Raw
    try {
        $modified = $original.Replace(
            'Для каждой `tool-heavy` задачи подключать `instructions/core/tool-execution-baseline.md`',
            'Для некоторых `tool-heavy` задач подключать `instructions/core/tool-execution-baseline.md`'
        )
        Set-Content -Path $routingFile -Value $modified -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "tool-heavy owner перестал быть обязательным" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $routingFile -Value $original -Encoding UTF8
    }

    # Scenario 13: successful full-run gate is weakened
    $testingFile = Join-Path $scenarioRoot "instructions/core/testing-baseline.md"
    $original = Get-Content -Path $testingFile -Raw
    try {
        $modified = $original.Replace('successful full test run', 'optional full test run')
        Set-Content -Path $testingFile -Value $modified -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "ослаблен successful full-run gate" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $testingFile -Value $original -Encoding UTF8
    }

    # Scenario 14: reviewer is no longer read-only
    $reviewerFile = Join-Path $scenarioRoot "templates/codex/agents/independent-reviewer.toml"
    $original = Get-Content -Path $reviewerFile -Raw
    try {
        $modified = $original.Replace('sandbox_mode = "read-only"', 'sandbox_mode = "workspace-write"')
        Set-Content -Path $reviewerFile -Value $modified -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "reviewer sandbox не read-only" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $reviewerFile -Value $original -Encoding UTF8
    }

    # Scenario 15: unsupported lifecycle event is added
    $hookTemplateFile = Join-Path $scenarioRoot "templates/codex/agent-operations-hooks.json"
    $original = Get-Content -Path $hookTemplateFile -Raw
    try {
        $modified = $original.Replace('"PostToolUse": [', "`"Stop`": [],`n    `"PostToolUse`": [")
        Set-Content -Path $hookTemplateFile -Value $modified -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "добавлен unsupported hook event" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $hookTemplateFile -Value $original -Encoding UTF8
    }

    # Scenario 16: local environment starts inventing config schema
    $localEnvironmentFile = Join-Path $scenarioRoot "instructions/onboarding/local-environment.md"
    $original = Get-Content -Path $localEnvironmentFile -Raw
    try {
        $modified = $original.Replace('не изобретать undocumented `.codex` schema', 'создавать собственную `.codex` schema')
        Set-Content -Path $localEnvironmentFile -Value $modified -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "удалена documented-schema boundary" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $localEnvironmentFile -Value $original -Encoding UTF8
    }

    # Scenario 17: ignored local evidence contains a broken link
    $ignoredArtifactDirectory = Join-Path $scenarioRoot ".artifacts/private-evidence"
    New-Item -ItemType Directory -Path $ignoredArtifactDirectory -Force | Out-Null
    Set-Content -Path (Join-Path $ignoredArtifactDirectory "broken.md") -Value "[ignored](./missing.md)" -Encoding UTF8
    if (-not (Invoke-Validation -ScenarioName "ignored artifacts не влияют на catalog links" -ScenarioPath $scenarioRoot -ShouldPass $true)) {
        $failed = $true
    }

    # Scenario 18: Windows operational CI job is removed
    $workflowFile = Join-Path $scenarioRoot ".github/workflows/validate-instructions.yml"
    $original = Get-Content -Path $workflowFile -Raw
    try {
        $modified = $original.Replace('runs-on: windows-latest', 'runs-on: ubuntu-latest')
        Set-Content -Path $workflowFile -Value $modified -Encoding UTF8
        if (-not (Invoke-Validation -ScenarioName "Windows operational CI job удалён" -ScenarioPath $scenarioRoot -ShouldPass $false)) {
            $failed = $true
        }
    }
    finally {
        Set-Content -Path $workflowFile -Value $original -Encoding UTF8
    }
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

if ($SkipAgentOperations) {
    Write-Host "INFO: Windows operational suite пропущен явным CI split; его запускает отдельный windows-latest job" -ForegroundColor Cyan
}
else {
    $agentOperationsTests = Join-Path $root "scripts/test-agent-operations.ps1"
    & pwsh -NoProfile -File $agentOperationsTests -Area All
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: agent operations contract tests завершились с ошибкой" -ForegroundColor Red
        $failed = $true
    }
}

if ($failed) {
    exit 1
}

Write-Host "PASS: все сценарии test-validate-instructions пройдены" -ForegroundColor Green
exit 0
