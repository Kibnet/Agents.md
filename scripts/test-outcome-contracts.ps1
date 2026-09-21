[CmdletBinding()]
param(
    [string]$RootPath = (Join-Path $PSScriptRoot '..'),
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/Catalog.Markdown.psm1') -Force
$catalogRoot = (Resolve-Path -LiteralPath $RootPath).Path

# Narrow source-integrity guards: these do NOT evaluate agent behavior. Each
# anchor protects an obligation, and its deletion must fail the static suite.
$guards = @(
    @{ Id='C1.hierarchy'; Path='instructions/governance/routing-matrix.md'; Anchor='Сначала соблюдать общую иерархию system/developer/user.' },
    @{ Id='C1.applicability'; Path='instructions/governance/routing-matrix.md'; Anchor='До сравнения строгости определить применимость:' },
    @{ Id='C1.strictness'; Path='instructions/governance/routing-matrix.md'; Anchor='более строгий `MUST` имеет приоритет только среди одновременно применимых требований.' },
    @{ Id='C1.consumer'; Path='instructions/governance/routing-matrix.md'; Anchor='Явный применимый consumer gate сохраняется:' },
    @{ Id='C2.outcome'; Path='instructions/core/collaboration-baseline.md'; Anchor='Сохранять в рабочем контексте исходный пользовательский результат, текущую фазу, уже разрешённые действия' },
    @{ Id='C2.approval'; Path='instructions/core/collaboration-baseline.md'; Anchor='Ответ «да» на одно конкретное предложение принимает описанные в нём параметры и действия.' },
    @{ Id='C2.exact'; Path='instructions/core/quest-mode.md'; Anchor='Фразу пользователя `Спеку подтверждаю` считать единственным переходом из фазы `SPEC` в фазу `EXEC`.' },
    @{ Id='C2.same-scope'; Path='instructions/core/quest-mode.md'; Anchor='После exact approval редакционная конкретизация в том же результате, scope и риске не сбрасывает фазу EXEC' },
    @{ Id='C3.materiality'; Path='instructions/core/collaboration-baseline.md'; Anchor='Спрашивать только о недостающем решении, которое существенно меняет пользовательский результат, полномочия, стоимость ошибки или обратимость' },
    @{ Id='C3.scope'; Path='instructions/core/collaboration-baseline.md'; Anchor='Разрешение ограничено согласованными действием, материалом, адресатом и риском.' },
    @{ Id='C3.agreed-limits'; Path='instructions/core/collaboration-baseline.md'; Anchor='Срочность, одноразовое окно и обязательность результата не отменяют явно согласованные ограничения и не разрешают повышать риск.' },
    @{ Id='C3.no-timeout-approval'; Path='instructions/core/collaboration-baseline.md'; Anchor='Истечение ожидания не считать ответом или согласием.' },
    @{ Id='C4.severity'; Path='instructions/governance/review-loops.md'; Anchor='`BLOCKER` / `HIGH` и любое невыполненное обязательное AC, authorization или validation условие текущей фазы блокируют `PASS` независимо от severity label.' },
    @{ Id='C4.medium'; Path='instructions/governance/review-loops.md'; Anchor='Невыполненное обязательное условие нельзя скрыть такой disposition.' },
    @{ Id='C4.low'; Path='instructions/governance/review-loops.md'; Anchor='Личные предпочтения и `LOW` без нарушения обязательного контракта оформлять как follow-up и не блокировать продолжение.' },
    @{ Id='C5.eligibility'; Path='instructions/core/quest-governance.md'; Anchor='нет config/storage/security/публичного контракта/миграции/внешнего side effect; нет существенной межкомпонентной неопределённости' },
    @{ Id='C5.template.1'; Path='templates/specs/_template-small.md'; Anchor='1. Результат / границы | Исходное поручение, AS-IS и пользовательский сценарий; outcome и Non-Goals' },
    @{ Id='C5.template.2'; Path='templates/specs/_template-small.md'; Anchor='2. Решения / разрешения | Выбранные решения, оставшиеся существенные вопросы, уже разрешённый scope' },
    @{ Id='C5.template.3'; Path='templates/specs/_template-small.md'; Anchor='3. AC→evidence | Обязательные AC и основание выбранного набора проверок' },
    @{ Id='C5.template.4'; Path='templates/specs/_template-small.md'; Anchor='4. Существенный риск / rollback | Вероятный дефект или user objection; безопасный откат' },
    @{ Id='C5.template.5'; Path='templates/specs/_template-small.md'; Anchor='5. Findings / disposition / stop | Что реально проверено, findings/fixes либо обоснованное «Нет находок»' },
    @{ Id='C5.linter'; Path='instructions/governance/spec-linter.md'; Anchor='Не оценивать отдельно 20 expanded-пунктов и не добавлять числовой rubric либо перечень неприменимых ролей.' },
    @{ Id='C5.rubric'; Path='instructions/governance/spec-rubric.md'; Anchor='Для short SPEC: достаточно пяти содержательных проверок по `spec-linter.md` и компактного review по `review-loops.md`, без числовых оценок.' },
    @{ Id='C5.review'; Path='instructions/governance/review-loops.md'; Anchor='Для short SPEC выполнять один компактный evidence-based pass на каждой фазе по пяти содержательным проверкам `spec-linter.md`.' },
    @{ Id='C6.mandatory'; Path='instructions/core/testing-baseline.md'; Anchor='Сохранять явные repo/CI/release gates и обязательства уже утверждённой SPEC; обновление каталога не освобождает от них.' },
    @{ Id='C6.wide'; Path='instructions/core/testing-baseline.md'; Anchor='Полный набор тестов обязателен при изменениях общих storage/config/security/публичных контрактов, миграциях, широкой или неизвестной области влияния либо явном repo/CI/release gate.' },
    @{ Id='C6.green'; Path='instructions/core/testing-baseline.md'; Anchor='Перед успешным завершением получать green для всего обязательного набора проверок.' },
    @{ Id='C6.no-skip'; Path='instructions/core/testing-baseline.md'; Anchor='Нельзя сокращать ранее обязательный набор после failure, чтобы объявить PASS.' },
    @{ Id='C6.dotnet'; Path='instructions/contexts/testing-dotnet.md'; Anchor='Обязательный набор проверок, условия full suite и regression check выбирать по `testing-baseline`; сохранять явные repo/CI/release gates и проверки утверждённой SPEC.' },
    @{ Id='C6.regression'; Path='instructions/core/testing-baseline.md'; Anchor='При воспроизводимом баге сначала найти или добавить failing regression check, подтвердить причину, затем исправить ошибку.' },
    @{ Id='C7.scenario'; Path='instructions/core/model-behavior-baseline.md'; Anchor='Подтверждать исходный пользовательский сценарий и обычный путь использования:' },
    @{ Id='C7.visual'; Path='instructions/core/model-behavior-baseline.md'; Anchor='Визуальным evidence считать только просмотренное изображение нужного состояния актуального артефакта.' },
    @{ Id='C7.persistence'; Path='instructions/core/model-behavior-baseline.md'; Anchor='Не приписывать persistence по одному факту записи настройки.' },
    @{ Id='C8.source'; Path='instructions/core/tool-execution-baseline.md'; Anchor='Выбирать первичный источник по проверяемому claim:' },
    @{ Id='C8.runtime'; Path='instructions/core/tool-execution-baseline.md'; Anchor='Explicit tool/runtime denial не разрешает обход через иной инструмент, endpoint или credential.' },
    @{ Id='C8.artifact'; Path='instructions/core/collaboration-baseline.md'; Anchor='Сохранять согласованные язык, формат и содержательную детализацию артефакта.' },
    @{ Id='C9.coverage'; Path='instructions/core/model-behavior-baseline.md'; Anchor='При массовой работе отдельно отражать найденные, классифицированные, контекстно проверенные и содержательно продвинутые элементы.' }
)

$forbidden = @(
    @{ Path='instructions/core/testing-baseline.md'; Text='successful full test run' },
    @{ Path='templates/specs/_template-small.md'; Text='Linter: критерии 1..20 по spec-linter с пояснением' },
    @{ Path='templates/specs/_template-small.md'; Text='Rubric: шесть оценок 0/2/5 и обоснование' },
    @{ Path='instructions/governance/review-loops.md'; Text='Спрашивать пользователя нужно только если единственного оптимального варианта нет' },
    @{ Path='instructions/governance/spec-linter.md'; Text='Нерешённый HIGH/MEDIUM из review блокирует approval независимо от баллов' },
    @{ Path='instructions/governance/spec-rubric.md'; Text='незакрытом HIGH/MEDIUM review не выдавать готовность по одной сумме' }
)

function Get-SourceIssues([hashtable]$Documents) {
    $issues = [Collections.Generic.List[string]]::new()
    $visible = @{}
    foreach ($path in @($guards.Path + $forbidden.Path | Select-Object -Unique)) {
        if (-not $Documents.ContainsKey($path)) { $visible[$path] = ''; continue }
        $withoutComments = $Documents[$path] -replace '(?s)<!--.*?-->', ''
        $visible[$path] = (Get-CatalogMarkdownStructure -Markdown $withoutComments).Content
    }
    foreach ($guard in $guards) {
        $pattern = '(?m)^(?:- |[0-9]+\. |\| )[^\r\n]*' + [regex]::Escape($guard.Anchor) + '[^\r\n]*\r?$'
        if ($visible[$guard.Path] -notmatch $pattern) { $issues.Add($guard.Id) }
    }
    foreach ($old in $forbidden) {
        if ($visible[$old.Path].Contains($old.Text)) { $issues.Add("obsolete:$($old.Path):$($old.Text)") }
    }
    return $issues.ToArray()
}

function Get-FixtureJson([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) { throw 'Fixture path must be relative and nonempty' }
    $fixtureRoot = [IO.Path]::GetFullPath((Join-Path $catalogRoot 'scripts/fixtures/outcome-contracts'))
    $full = [IO.Path]::GetFullPath((Join-Path $fixtureRoot $RelativePath))
    $relative = [IO.Path]::GetRelativePath($fixtureRoot, $full)
    if ($relative -eq '..' -or $relative -match '^\.\.[\\/]' -or [IO.Path]::IsPathRooted($relative)) { throw 'Fixture path escapes fixture directory' }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Missing fixture: $RelativePath" }
    $value = Get-Content -LiteralPath $full -Raw | ConvertFrom-Json -AsHashtable
    if ($value -isnot [System.Collections.IDictionary]) { throw "Fixture is not an object: $RelativePath" }
    return $value
}

function Get-ManifestIssues($Manifest) {
    $issues = [Collections.Generic.List[string]]::new()
    try {
        if ($null -eq $Manifest -or $Manifest -isnot [System.Collections.IDictionary]) { throw 'Missing manifest object' }
        if ($Manifest.schemaVersion -ne 1) { throw 'Unsupported schemaVersion' }
        if ($Manifest.scenarios -isnot [array] -or $Manifest.scenarios.Count -ne 18) { throw 'Exactly S01-S18 required' }
        $seen = @{}; $contracts = @{}; $references = [Collections.Generic.List[object]]::new()
        foreach ($scenario in $Manifest.scenarios) {
            if ($scenario -isnot [System.Collections.IDictionary] -or $scenario.id -notmatch '^S(0[1-9]|1[0-8])$') { throw 'Invalid scenario ID' }
            if ($seen.ContainsKey($scenario.id)) { throw "Duplicate scenario: $($scenario.id)" }; $seen[$scenario.id] = $true
            if ($scenario.contracts -isnot [array] -or $scenario.contracts.Count -eq 0) { throw 'Missing contract mapping' }
            foreach ($id in $scenario.contracts) { if ($id -notmatch '^C[1-9]$') { throw "Invalid contract: $id" }; $contracts[$id] = $true }
            $expected = switch ($scenario.id) { 'S16' { @('base','mandatory') }; 'S17' { @('base','mandatory') }; 'S18' { @('base','nonblocking') }; default { @('base') } }
            if ($scenario.variants -isnot [array] -or $scenario.variants.Count -ne @($expected).Count) { throw "Wrong variants for $($scenario.id)" }
            $variantIds = @($scenario.variants | ForEach-Object { $_.id })
            if (@(Compare-Object @($expected | Sort-Object) @($variantIds | Sort-Object)).Count -ne 0) { throw "Invalid variant IDs for $($scenario.id)" }
            foreach ($variant in $scenario.variants) { $references.Add($variant) }
        }
        if ($contracts.Count -ne 9) { throw 'Manifest must cover C1-C9' }
        if ($Manifest.heldOut -isnot [array] -or $Manifest.heldOut.Count -ne 2) { throw 'Two held-out cases required' }
        $heldSeen = @{}
        foreach ($held in $Manifest.heldOut) {
            if ($held.id -notin @('H06','H11') -or $heldSeen.ContainsKey($held.id)) { throw 'Invalid or duplicate held-out case' }
            if ($held.basedOn -ne ('S' + $held.id.Substring(1))) { throw 'Invalid held-out source' }
            $heldSeen[$held.id] = $true; $references.Add($held)
        }
        $inputs = @{}; $oracles = @{}
        foreach ($reference in $references) {
            if ($reference.input -notmatch '^cases/[^/]+\.json$' -or $reference.oracle -notmatch '^oracles/[^/]+\.json$') { throw 'Separate case and oracle JSON files required' }
            if ($inputs.ContainsKey($reference.input) -or $oracles.ContainsKey($reference.oracle)) { throw 'Each variant needs distinct input and oracle files' }
            $inputs[$reference.input] = $true; $oracles[$reference.oracle] = $true
            $case = Get-FixtureJson $reference.input; $oracle = Get-FixtureJson $reference.oracle
            if ($case.turns -isnot [array] -or $case.turns.Count -eq 0) { throw 'Case needs turns' }
            foreach ($turn in $case.turns) { if ($turn -isnot [System.Collections.IDictionary] -or [string]::IsNullOrWhiteSpace($turn.text)) { throw 'Each turn needs text' } }
            if ($case.files -isnot [System.Collections.IDictionary] -or $case.operations -isnot [System.Collections.IDictionary]) { throw 'Case needs files and operations maps' }
            if ($case.ContainsKey('oracle') -or $case.ContainsKey('expected') -or $case.ContainsKey('forbidden')) { throw 'Oracle must not be included in model input' }
            foreach ($field in @('expected','forbidden')) {
                if ($oracle[$field] -isnot [array] -or $oracle[$field].Count -eq 0) { throw "Oracle needs $field" }
                foreach ($item in $oracle[$field]) { if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) { throw 'Oracle criteria must be nonempty strings' } }
            }
        }
    }
    catch { $issues.Add($_.Exception.Message) }
    return $issues.ToArray()
}

try {
    $documents = @{}
    foreach ($path in @($guards.Path + $forbidden.Path | Select-Object -Unique)) {
        $full = Join-Path $catalogRoot $path
        if (Test-Path -LiteralPath $full -PathType Leaf) { $documents[$path] = Get-Content -LiteralPath $full -Raw }
    }
    $manifestPath = Join-Path $catalogRoot 'scripts/fixtures/outcome-contracts/manifest.json'
    $manifest = if (Test-Path -LiteralPath $manifestPath -PathType Leaf) { Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable } else { $null }
    $issues = @(Get-SourceIssues $documents) + @(Get-ManifestIssues $manifest)
    if ($issues.Count -gt 0) { throw ('Static outcome checks failed: ' + ($issues -join '; ')) }

    $mutations = 0
    if (-not $ValidateOnly) {
        foreach ($guard in $guards) {
            $copy = $documents.Clone()
            $pattern = '(?m)^(?:- |[0-9]+\. |\| )[^\r\n]*' + [regex]::Escape($guard.Anchor) + '[^\r\n]*\r?$'
            $changed = [regex]::Replace($copy[$guard.Path], $pattern, '- Contract intentionally removed by negative fixture.')
            if ($changed -ceq $copy[$guard.Path]) { throw "No-op mutation: $($guard.Id)" }
            $copy[$guard.Path] = $changed
            if (@(Get-SourceIssues $copy) -notcontains $guard.Id) { throw "Undetected source regression: $($guard.Id)" }
            $mutations++
        }
        foreach ($old in $forbidden) {
            $copy = $documents.Clone()
            $copy[$old.Path] += "`n- " + $old.Text + "`n"
            $expectedIssue = "obsolete:$($old.Path):$($old.Text)"
            if (@(Get-SourceIssues $copy) -notcontains $expectedIssue) { throw "Undetected stale rule: $($old.Path)" }
            $mutations++
        }
        # A code example or comment cannot stand in for a removed obligation.
        $green = $guards | Where-Object Id -eq 'C6.green'
        foreach ($wrapper in @('fence','comment')) {
            $copy = $documents.Clone()
            $line = [regex]::Match($copy[$green.Path], '(?m)^- [^\r\n]*' + [regex]::Escape($green.Anchor) + '[^\r\n]*\r?$').Value
            $hidden = if ($wrapper -eq 'fence') { '```text' + "`n" + $line + "`n" + '```' } else { '<!--' + $line + '-->' }
            $copy[$green.Path] = $copy[$green.Path].Replace($line, $hidden)
            if (@(Get-SourceIssues $copy) -notcontains 'C6.green') { throw "Contract hidden in $wrapper accepted" }
            $mutations++
        }
        foreach ($name in @('missing','schema','missing-scenario','duplicate-scenario','invalid-contract','missing-variant','invalid-variant','missing-input','missing-oracle','escape','shared-input','missing-heldout')) {
            $copy = $manifest | ConvertTo-Json -Depth 30 | ConvertFrom-Json -AsHashtable
            switch ($name) {
                'missing' { $copy = $null }
                'schema' { $copy.schemaVersion = 99 }
                'missing-scenario' { $copy.scenarios = @($copy.scenarios | Select-Object -Skip 1) }
                'duplicate-scenario' { $copy.scenarios[1].id = $copy.scenarios[0].id }
                'invalid-contract' { $copy.scenarios[0].contracts = @('C99') }
                'missing-variant' { $copy.scenarios[15].variants = @($copy.scenarios[15].variants[0]) }
                'invalid-variant' { $copy.scenarios[17].variants[1].id = 'optional' }
                'missing-input' { $copy.scenarios[0].variants[0].input = 'cases/not-present.json' }
                'missing-oracle' { $copy.scenarios[0].variants[0].oracle = 'oracles/not-present.json' }
                'escape' { $copy.scenarios[0].variants[0].input = '../outside.json' }
                'shared-input' { $copy.scenarios[1].variants[0].input = $copy.scenarios[0].variants[0].input }
                'missing-heldout' { $copy.heldOut = @() }
            }
            if (@(Get-ManifestIssues $copy).Count -eq 0) { throw "Undetected manifest regression: $name" }
            $mutations++
        }
    }
    Write-Host "PASS: static outcome source/fixture contracts ($($guards.Count) guards, $mutations negative mutations). Behavioral smoke NOT evaluated."
    exit 0
}
catch {
    Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
