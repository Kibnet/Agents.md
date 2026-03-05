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

    # Scenario 3: broken markdown link
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

    # Scenario 4: legacy reference
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

    # Scenario 5: unresolved reference link
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
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

if ($failed) {
    exit 1
}

Write-Host "PASS: все сценарии test-validate-instructions пройдены" -ForegroundColor Green
exit 0
