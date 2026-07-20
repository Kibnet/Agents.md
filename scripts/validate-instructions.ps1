param(
    [string]$RootPath = (Join-Path $PSScriptRoot "..")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path $RootPath).Path
$errors = New-Object System.Collections.Generic.List[string]

function Add-Error {
    param([string]$Message)
    $errors.Add($Message)
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Add-Info {
    param([string]$Message)
    Write-Host "INFO: $Message" -ForegroundColor Cyan
}

Add-Info "Проверка каталога: $resolvedRoot"

$requiredPaths = @(
    "AGENTS.md",
    "CHANGELOG.md",
    ".github/workflows/validate-instructions.yml",
    "templates/specs/_template.md",
    "instructions/core/model-behavior-baseline.md",
    "instructions/core/quest-governance.md",
    "instructions/core/quest-mode.md",
    "instructions/core/quest-prompt-spec.md",
    "instructions/core/quest-prompt-exec.md",
    "instructions/core/collaboration-baseline.md",
    "instructions/core/testing-baseline.md",
    "instructions/core/tool-execution-baseline.md",
    "instructions/contexts/debug-dotnet-mcp-coreclr.md",
    "instructions/contexts/performance-optimization.md",
    "instructions/contexts/session-insights-context.md",
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
    "instructions/governance/openai-responses-api.md",
    "instructions/governance/versioning-policy.md",
    "instructions/governance/commenting-policy.md",
    "instructions/governance/refactoring-policy.md",
    "instructions/governance/spec-linter.md",
    "instructions/governance/spec-rubric.md",
    "instructions/governance/review-loops.md",
    "instructions/governance/commit-message-policy.md",
    "instructions/governance/github-delivery-policy.md",
    "instructions/onboarding/quick-start.md",
    "instructions/onboarding/local-environment.md",
    "instructions/onboarding/AGENTS.consumer.template.md",
    "instructions/onboarding/AGENTS.override.template.md",
    "instructions/profiles/domain-logic-extraction.md",
    "instructions/profiles/product-system-design.md",
    "instructions/profiles/business-process-automation.md",
    "instructions/profiles/refactor-local.md",
    "instructions/profiles/refactor-architecture.md",
    "instructions/profiles/refactor-mechanical.md",
    "instructions/profiles/rendering-pipeline.md",
    "instructions/profiles/ui-feature-parity.md",
    "instructions/profiles/storm-product-development.md",
    "prompts/business-process-automation/01-expert-interview-simulation.md",
    "prompts/business-process-automation/02-as-is-process-modeling.md",
    "prompts/business-process-automation/03-automation-opportunities-analysis.md",
    "prompts/business-process-automation/04-to-be-process-design.md",
    "prompts/business-process-automation/05-ai-agent-skill-graph.md",
    "prompts/storm/00-full-cycle.md",
    "prompts/storm/01-bootstrap-from-code.md",
    "prompts/storm/02-trace-tests.md",
    "prompts/storm/03-complete-test-coverage.md",
    "prompts/storm/04-derive-needs-goal.md",
    "prompts/storm/05-goal-gap-backlog.md",
    "prompts/storm/06-cloud-conflicts.md",
    "prompts/storm/07-deprecate-cleanup.md",
    "prompts/storm/08-dependencies-rice-ranking.md",
    "prompts/storm/09-sdd-implement-story.md",
    "prompts/storm/10-audit-and-improve-process.md",
    "prompts/storm/11-generate-gherkin.md",
    "prompts/storm/12-bdd-sync.md",
    "prompts/storm/13-bdd-lint.md",
    "prompts/storm/14-bdd-conflicts.md",
    "prompts/storm/15-bdd-implement-story.md",
    "templates/storm/storm.json",
    "templates/storm/feature-template.feature",
    "templates/storm/process-audit.md",
    "templates/storm/product-goal.md",
    "templates/storm/ranking.md",
    "templates/storm/traceability.md",
    "schemas/storm-artifacts.schema.json",
    "schemas/agent-operations-gold-labels.schema.json",
    "schemas/agent-operations-behavioral-smoke.schema.json",
    "schemas/agent-operations-smoke-review.schema.json",
    "scripts/storm/validate-artifacts.py",
    "scripts/storm/rank-backlog.py",
    "templates/codex/agent-operations-hooks.json",
    "templates/codex/agents/independent-reviewer.toml",
    "templates/codex/local-environment/README.md",
    "templates/codex/local-environment/preflight.ps1",
    "scripts/hooks/agent-operations-hook.ps1",
    "scripts/install-agent-operations.ps1",
    "scripts/probe-agent-operations-activation.ps1",
    "scripts/analyze-codex-session-errors.ps1",
    "scripts/test-agent-operations.ps1",
    "scripts/fixtures/agent-operations/analyzer/trace-main.jsonl",
    "scripts/fixtures/agent-operations/analyzer/trace-child.jsonl",
    "scripts/fixtures/agent-operations/analyzer/gold-set.json",
    "scripts/fixtures/agent-operations/analyzer-salt.txt",
    "scripts/fixtures/agent-operations/installer/config-foreign.toml",
    "scripts/fixtures/agent-operations/installer/hooks-foreign.json",
    "scripts/fixtures/agent-operations/tunit/TUnitFixture.csproj",
    "session-insights/README.md",
    "session-insights/AGENT_SESSION_LESSONS.md",
    "session-insights/REPO_RUNBOOKS_FROM_SESSIONS.md",
    "session-insights/VALIDATION_COOKBOOK_FROM_SESSIONS.md",
    "session-insights/UI_QUALITY_RUBRIC_FROM_SESSIONS.md",
    "session-insights/COMMAND_COOKBOOK_FROM_SESSIONS.md",
    "session-insights/USER_WORKFLOW_PREFERENCES.md",
    "session-insights/AGENTS_IMPROVEMENT_BACKLOG.md",
    "session-insights/DO_NOT_REPEAT.md",
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
        "## Команды",
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

$deprecatedTemplatePathPattern = '(?<!templates/)specs/_template\.md'
$activeTemplateScanFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
$readmeFile = Join-Path $resolvedRoot "README.md"
if (Test-Path $readmeFile) {
    $activeTemplateScanFiles.Add((Get-Item $readmeFile))
}
if (Test-Path $agentsIndex) {
    $activeTemplateScanFiles.Add((Get-Item $agentsIndex))
}
if (Test-Path $instructionsRoot) {
    Get-ChildItem -Path $instructionsRoot -Recurse -File -Filter *.md | ForEach-Object {
        $activeTemplateScanFiles.Add($_)
    }
}

foreach ($mdFile in $activeTemplateScanFiles) {
    $rawContent = Get-Content -Path $mdFile.FullName -Raw
    $normalizedContent = $rawContent -replace '\\', '/'
    if ([regex]::IsMatch($normalizedContent, $deprecatedTemplatePathPattern)) {
        Add-Error "Обнаружена активная ссылка на устаревший template path 'specs/_template.md' в $($mdFile.FullName)"
    }
}

$semanticContracts = @(
    @{
        Path = "instructions/core/model-behavior-baseline.md"
        Pattern = 'семейство `GPT-5\.6` целевой optimization baseline'
        Description = "GPT-5.6 target baseline"
    },
    @{
        Path = "instructions/core/model-behavior-baseline.md"
        Pattern = 'фактический runtime'
        Description = "surface/runtime evidence rule"
    },
    @{
        Path = "instructions/core/collaboration-baseline.md"
        Pattern = 'Для просьб ответить, объяснить, спланировать, диагностировать, сделать review или сообщить status'
        Description = "read-only authorization boundary"
    },
    @{
        Path = "instructions/governance/openai-responses-api.md"
        Pattern = 'reasoning\.context'
        Description = "persisted reasoning contract"
    },
    @{
        Path = "instructions/governance/openai-responses-api.md"
        Pattern = '`none`, `low`, `medium`, `high`, `xhigh`, `max`'
        Description = "GPT-5.6 reasoning effort levels"
    },
    @{
        Path = "instructions/governance/openai-responses-api.md"
        Pattern = 'allowed_callers: \["programmatic"\]'
        Description = "Programmatic Tool Calling contract"
    },
    @{
        Path = "instructions/governance/openai-responses-api.md"
        Pattern = 'safety_identifier'
        Description = "end-user safety identifier contract"
    },
    @{
        Path = "instructions/governance/routing-matrix.md"
        Pattern = 'OpenAI Responses API, API model/tier routing'
        Description = "Responses API routing trigger"
    },
    @{
        Path = "README.md"
        Pattern = '# Surface Contract Matrix для GPT-5\.6'
        Description = "surface contract matrix"
    },
    @{
        Path = "templates/specs/_template.md"
        Pattern = 'Effective runtime:'
        Description = "effective runtime metadata"
    },
    @{
        Path = "templates/specs/_template.md"
        Pattern = 'before/after behavioral smoke'
        Description = "behavior regression evidence"
    },
    @{
        Path = "instructions/governance/review-loops.md"
        Pattern = 'Static validator, semantic scan и cross-model benchmark дополняют, но не заменяют этот smoke'
        Description = "behavioral smoke no-substitution rule"
    },
    @{
        Path = "AGENTS.md"
        Pattern = 'tool-execution-baseline\.md'
        Description = "tool execution owner entry point"
    },
    @{
        Path = "instructions/governance/routing-matrix.md"
        Pattern = 'Для каждой `tool-heavy` задачи подключать `instructions/core/tool-execution-baseline\.md`'
        Description = "mandatory tool-heavy routing"
    },
    @{
        Path = "instructions/core/tool-execution-baseline.md"
        Pattern = '`1` без stderr — expected no-match'
        Description = "rg expected no-match normalization"
    },
    @{
        Path = "instructions/core/tool-execution-baseline.md"
        Pattern = 'Не предлагать broad `writable_roots`'
        Description = "Git metadata protection boundary"
    },
    @{
        Path = "instructions/core/tool-execution-baseline.md"
        Pattern = 'Идентичный retry по stale context запрещён'
        Description = "stale patch no-identical-retry rule"
    },
    @{
        Path = "instructions/core/collaboration-baseline.md"
        Pattern = 'Один файл в один момент имеет одного writer'
        Description = "one-writer ownership"
    },
    @{
        Path = "instructions/core/testing-baseline.md"
        Pattern = 'successful full test run'
        Description = "successful full-run completion gate"
    },
    @{
        Path = "instructions/governance/review-loops.md"
        Pattern = 'Independent review считать технически read-only только при evidence фактического child sandbox `read-only`'
        Description = "effective read-only reviewer evidence"
    },
    @{
        Path = "instructions/contexts/session-insights-context.md"
        Pattern = 'targeted retrieval layer'
        Description = "session insights retrieval-only role"
    },
    @{
        Path = "instructions/onboarding/local-environment.md"
        Pattern = 'не изобретать undocumented `\.codex` schema'
        Description = "documented local-environment schema boundary"
    },
    @{
        Path = "instructions/onboarding/local-environment.md"
        Pattern = 'Codex Desktop.*не изобретать undocumented `\.codex` schema.*не заявлять CLI support'
        Description = "Desktop-only local-environment surface"
    },
    @{
        Path = "instructions/onboarding/local-environment.md"
        Pattern = '-RequiredCommand @\("git", "pwsh", "dotnet"\)'
        Description = "copy-ready preflight array syntax"
    },
    @{
        Path = "templates/codex/local-environment/README.md"
        Pattern = '-OptionalCommand @\("node", "rg"\)'
        Description = "copy-ready optional command array syntax"
    },
    @{
        Path = ".github/workflows/validate-instructions.yml"
        Pattern = 'runs-on: windows-latest'
        Description = "Windows operational CI runner"
    },
    @{
        Path = ".github/workflows/validate-instructions.yml"
        Pattern = 'test-agent-operations\.ps1 -Area All'
        Description = "full Windows operational CI gate"
    },
    @{
        Path = ".github/workflows/validate-instructions.yml"
        Pattern = 'test-validate-instructions\.ps1 -SkipAgentOperations'
        Description = "Linux catalog and Windows operational CI split"
    },
    @{
        Path = "scripts/install-agent-operations.ps1"
        Pattern = 'ApprovedProposalHash'
        Description = "proposal-hash activation gate"
    },
    @{
        Path = "scripts/install-agent-operations.ps1"
        Pattern = 'awaiting-trust'
        Description = "non-managed hook trust state"
    },
    @{
        Path = "scripts/install-agent-operations.ps1"
        Pattern = 'MarkActive'
        Description = "evidence-bound active-state transition"
    },
    @{
        Path = "scripts/hooks/agent-operations-hook.ps1"
        Pattern = 'InstallManifestPath'
        Description = "manifest-bound private telemetry salt"
    },
    @{
        Path = "scripts/probe-agent-operations-activation.ps1"
        Pattern = 'reviewerWriteDenied'
        Description = "activation reviewer write-denial evidence"
    },
    @{
        Path = "scripts/analyze-codex-session-errors.ps1"
        Pattern = 'manual-review-only'
        Description = "classifier accuracy fallback"
    },
    @{
        Path = "scripts/analyze-codex-session-errors.ps1"
        Pattern = 'independent-stratified-v1'
        Description = "independent private-gold sampling"
    },
    @{
        Path = "scripts/test-agent-operations.ps1"
        Pattern = 'ValidateSet\("All", "Hooks", "Installer", "Analyzer", "Privacy"\)'
        Description = "agent operations test areas"
    }
)

foreach ($contract in $semanticContracts) {
    $contractPath = Join-Path $resolvedRoot $contract.Path
    if (-not (Test-Path $contractPath)) {
        continue
    }

    $contractContent = Get-Content -Path $contractPath -Raw
    if ($contractContent -notmatch $contract.Pattern) {
        Add-Error "Нарушен semantic contract '$($contract.Description)' в $($contract.Path)"
    }
}

$hookTemplateFile = Join-Path $resolvedRoot "templates/codex/agent-operations-hooks.json"
if (Test-Path -LiteralPath $hookTemplateFile -PathType Leaf) {
    try {
        $hookTemplate = (Get-Content -LiteralPath $hookTemplateFile -Raw) | ConvertFrom-Json -Depth 30
        $eventNames = @($hookTemplate.hooks.PSObject.Properties.Name | Sort-Object)
        if (($eventNames -join ",") -ne "PostToolUse,PreToolUse") {
            Add-Error "Hook template должен содержать только PreToolUse и PostToolUse"
        }
        foreach ($eventName in $eventNames) {
            foreach ($group in @($hookTemplate.hooks.$eventName)) {
                foreach ($handler in @($group.hooks)) {
                    if ($handler.type -ne "command" -or [int]$handler.timeout -gt 5) {
                        Add-Error "Hook template event '$eventName' нарушает command/timeout contract"
                    }
                }
            }
        }
    }
    catch {
        Add-Error "Hook template не является валидным JSON contract: $($_.Exception.Message)"
    }
}

$reviewerTemplateFile = Join-Path $resolvedRoot "templates/codex/agents/independent-reviewer.toml"
if (Test-Path -LiteralPath $reviewerTemplateFile -PathType Leaf) {
    $reviewerTemplate = Get-Content -LiteralPath $reviewerTemplateFile -Raw
    foreach ($marker in @('name = "independent-reviewer"', 'description = ', 'developer_instructions = ', 'sandbox_mode = "read-only"')) {
        if ($reviewerTemplate -notmatch [regex]::Escape($marker)) {
            Add-Error "Reviewer template не содержит required marker '$marker'"
        }
    }
}

$staleTargetPatterns = @(
    '(?i)Целевая модель:\s*`?gpt-5\.5`?',
    '(?i)целевого поведения модели\s*`gpt-5\.5`',
    '(?i)обязательный core baseline для\s*`gpt-5\.5`',
    '(?i)GPT-5\.5 style',
    '(?i)Считать\s+`?gpt-5\.5`?\s+целевой моделью каталога'
)
$staleTargetFiles = @(
    "AGENTS.md",
    "README.md",
    "instructions/core/model-behavior-baseline.md",
    "instructions/governance/routing-matrix.md",
    "templates/specs/_template.md"
)

foreach ($relativePath in $staleTargetFiles) {
    $targetPath = Join-Path $resolvedRoot $relativePath
    if (-not (Test-Path $targetPath)) {
        continue
    }

    $targetContent = Get-Content -Path $targetPath -Raw
    foreach ($pattern in $staleTargetPatterns) {
        if ($targetContent -match $pattern) {
            Add-Error "Обнаружен устаревший declared target GPT-5.5 в $relativePath"
            break
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

$excludedMarkdownFiles = @(
    "USER_PROFILE_FROM_CODEX_SESSIONS.md",
    "session-insights/PROJECT_INTEREST_MAP.md",
    "session-insights/FLAKY_SLOW_TESTS_REGISTRY.md"
)
$markdownFiles = Get-ChildItem -Path $resolvedRoot -Recurse -File -Filter *.md
foreach ($mdFile in $markdownFiles) {
    $relativeMarkdownPath = [System.IO.Path]::GetRelativePath($resolvedRoot, $mdFile.FullName).Replace("\", "/")
    if ($relativeMarkdownPath.StartsWith(".artifacts/", [System.StringComparison]::OrdinalIgnoreCase) -or
        $relativeMarkdownPath -in $excludedMarkdownFiles) {
        continue
    }

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

if ($errors.Count -gt 0) {
    Add-Info "Проверка завершена с ошибками: $($errors.Count)"
    exit 1
}

Add-Info "Проверка завершена успешно"
exit 0
