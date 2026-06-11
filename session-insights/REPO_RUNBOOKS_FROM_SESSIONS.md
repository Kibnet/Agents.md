# Repo Runbooks From Sessions

Дата подготовки: 2026-06-05.

Это не authoritative документация репозиториев. Это practical runbook, извлечённый из истории Codex-сессий. Перед использованием команд нужно сверять текущий `cwd`, `AGENTS.md`, `.csproj`, scripts и состояние ветки.

## Сводка по частоте

| Репозиторий / cwd basename | Сессий | User messages | Что чаще всего встречалось |
|---|---:|---:|---|
| `Unlimotion` | 69 | 529 | Avalonia UI, TUnit, Android, PR/CI, task card/tree/search |
| `TopLunchBot` | 43 | 323 | Telegram/Max bot, API, payments, deploy, tests |
| `AppAutomation` | 38 | 842 | UI automation framework, FlaUI, Avalonia.Headless, NuGet, CI |
| `DotnetDebug` | 24 | 195 | AppAutomation/EasyUse extraction, headless/FlaUI tests |
| `Agents` | 20 | 115 | central instruction catalog, Quest, validation scripts |
| `Arm.Srv` | 18 | 116 | .NET backend/API, tests, RavenDB-like integration, UI automation adoption |
| `graph-bot` | 18 | 134 | GraphBot, adapters, performance, NuGet/release |
| `ArduinoAndRaspberry` | 13 | 189 | embedded/runtime control, Python tests, Russian docs |
| `PDFAnnotator` | 10 | 46 | Avalonia PDF app, rendering, encoding, UI layout |
| `UTEP` / `UTEP.Sample` | 24 combined | 111 | CLI/tooling, schema/docs, Russian data |

## Global Preflight For Any Repo

1. Read repo instructions:

```powershell
Get-Content -LiteralPath .\AGENTS.md -Raw
if (Test-Path .\AGENTS.override.md) { Get-Content -LiteralPath .\AGENTS.override.md -Raw }
```

2. Check git state:

```powershell
git status --short
git branch --show-current
git remote -v
```

3. Identify project topology:

```powershell
rg --files -g "*.sln" -g "*.csproj" -g "package.json" -g "pyproject.toml" -g "global.json" -g ".github/workflows/*.yml"
```

4. For large repos, never start with full recursive scans over all files. Scope to `src`, `tests`, `specs`, `.github`, `docs`.

## Unlimotion

### What Matters

- High UI quality in Avalonia desktop and Android/mobile.
- TUnit tests and UI/headless tests are expected for behavior changes.
- PR/CI delivery matters; user often asks for rebase, commit, PR, CI fix.
- Android validation may involve emulator or real phone.
- Full test runs can be very slow; use targeted tests first.

### Useful Commands Seen In Sessions

Targeted TUnit patterns:

```powershell
dotnet run --project src\Unlimotion.Test\Unlimotion.Test.csproj -- --treenode-filter "/*/*/<TestClass>/*<TestName>*" --no-progress
```

Direct executable pattern after build:

```powershell
.\src\Unlimotion.Test\bin\Debug\net10.0\Unlimotion.Test.exe --treenode-filter "/*/*/MainControlTreeCommandsUiTests/*" --maximum-parallel-tests 1 --parallelism-strategy fixed --no-ansi --no-progress --timeout 45m
```

Android build patterns often need explicit SDK/JDK:

```powershell
$env:ANDROID_SDK_ROOT = '<ANDROID_SDK_ROOT>'
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
$env:JAVA_HOME = '<JAVA_HOME>'
dotnet build src\Unlimotion.Android\Unlimotion.Android.csproj -c Debug -t:Package --no-restore -m:1 -nr:false -v:minimal -p:RuntimeIdentifier=android-arm64
```

Repo validation for instruction-related changes:

```powershell
pwsh -File scripts\validate-instructions.ps1
pwsh -File scripts\test-validate-instructions.ps1
```

### Frequent Pitfalls

- Full `src/Unlimotion.Test` can take 30-60 minutes or timeout.
- Search/tree/card UI tests can require serial mode.
- Android build/workload restore can take 30+ minutes.
- Real device/emulator ABI mismatch happened around arm64/x86_64.
- Git branch creation can fail due ref lock/permission in shared worktree.
- User expects screenshots for UI polish, not only green tests.

### Preferred Flow

1. Read current spec if present.
2. Run narrow test around changed behavior.
3. For UI, capture screenshots for wide/narrow or desktop/mobile.
4. Run broader tests only after targeted green or when CI/PR requires.
5. Before PR: git state, branch, commit, push, CI check.

## TopLunchBot

### What Matters

- Telegram/Max bot behavior, API data, payment flows, order/cart correctness.
- Real API behavior and server logs matter; user often asks to check logs/API.
- Tokens/configs are sensitive.
- Bot state and release/deploy state can live outside repo.

### Useful Validation Patterns

```powershell
dotnet test
dotnet test .\tests\TopLunchBot.Tests\TopLunchBot.Tests.csproj
rg -n "TopLunch|Telegram|Max|Payment|Cart|Order|Schedule" src tests
```

When inspecting live/API behavior, first locate config and avoid printing secrets:

```powershell
rg -n "TopLunchApi|Token|Configuration|Schedule|Payment|Sbp" src tests docs
```

### Frequent Pitfalls

- API endpoints may require tokens; missing token makes diagnosis misleading.
- User explicitly constrained some tasks, e.g. "историю заказов пока не трогай".
- Payment flows have business invariants: cart cleanup after payment, day-specific order availability.
- Telegram polling timeout notifications can be noise and need suppression policy.
- Server deploy tasks require careful OS/runtime matching and service state.

### Preferred Flow

1. Extract business invariant from user prompt.
2. Reproduce with unit/integration tests or mock API first.
3. If real API is needed, pass token safely and do not log it.
4. Keep fallback behavior when user requires it.
5. Commit only after tests and secret diff check.

## AppAutomation

### What Matters

- Framework quality, consumer onboarding, deterministic launch path.
- FlaUI and Avalonia.Headless parity.
- NuGet packaging and GitHub release pipelines.
- Smoke test coverage and adoption journals.

### Useful Commands

```powershell
dotnet build
dotnet test
rg -n "FlaUI|Headless|Launch|Session|Smoke|NuGet|SourceGenerator" src tests sample docs specs
```

For CI/release:

```powershell
rg -n "pack|nuget|release|workflow|Version|Package" .github eng src tests
```

### Frequent Pitfalls

- Test matrix can be broad: authoring, FlaUI runtime, headless runtime, source generator.
- Browser/UI automation evidence may be needed for UI-facing changes.
- Packaging changes must preserve consumer onboarding.

### Preferred Flow

1. Identify which layer changes: contracts, host, FlaUI, headless, authoring, sample, docs.
2. Add/update tests in the same layer.
3. Validate package/release metadata if touching `.csproj`, `eng`, `.github`.
4. Keep docs/runbooks aligned with actual launch path.

## DotnetDebug

### What Matters

- Prototype and proving ground for UI automation framework extraction.
- FlaUI.EasyUse, Avalonia.Headless adapter, shared test DSL.
- Screenshots/videos of app windows were used as feedback loop topics.

### Useful Commands

```powershell
dotnet build
dotnet test
rg -n "FlaUI|Headless|EasyUse|MainWindow|UiAssert|AutomationElement|Page" src tests sample
```

### Frequent Pitfalls

- Full UI test runs can be slow or environment-sensitive.
- Demo UI/test scaffolding should become showcase coverage, not incidental code.
- Runtime differences between FlaUI and headless need explicit parity tests.

### Preferred Flow

1. Keep shared DSL and adapter-specific implementations separate.
2. Validate both runtime paths when behavior touches common abstractions.
3. Produce concise docs for consumers.

## Agents

### What Matters

- This repo is the central source of truth for agent instructions.
- Changes to canonical instructions require strict governance.
- Quality gate is mandatory before finish.

### Required Quality Gate

```powershell
pwsh -File scripts\validate-instructions.ps1
pwsh -File scripts\test-validate-instructions.ps1
```

### Frequent Pitfalls

- Local `AGENTS.override.md` must augment central stack, not replace it.
- New instruction rules can duplicate existing governance if not routed through owner docs.
- Current date should not be added to central instructions without business-specific reason.
- For ad-hoc memory-derived info, mark `[ad-hoc note]` when required by memory extension.

### Preferred Flow

1. Read central `AGENTS.md`.
2. Route through `instructions/governance/routing-matrix.md`.
3. If changing `instructions/*`, use Quest SPEC and relevant governance overlays.
4. Run both validators.

## Arm.Srv

### What Matters

- .NET backend/API work with large solution and tests.
- Full solution tests can be slow and timeout.
- User asks for review, CI/build fixes, UTF-8/Russian text preservation.

### Useful Commands

```powershell
dotnet build Arm.sln
dotnet test Arm.sln --no-restore
rg -n "Raven|Order|Request|Handler|Service|Test" src tests
```

### Frequent Pitfalls

- Full `Arm.sln` tests timed out in history.
- Paths sometimes contain Cyrillic segments; quoting and encoding matter.
- Preview .NET SDK warnings can appear and should not be misread as root cause.

### Preferred Flow

1. Start targeted by project/test class.
2. Preserve Russian text encoding; prefer UTF-8 without mojibake.
3. Treat environment/SDK warnings separately from test failures.

## graph-bot

### What Matters

- GraphBot adapters, Telegram/Max integration, performance, logging.
- NuGet/release workflows and package dependencies.
- Chat logging should include text, button presses, statuses and user signals when required.

### Useful Commands

```powershell
dotnet build
dotnet test
rg -n "Telegram|Max|Adapter|BotHost|Button|Status|ChatLog|Performance|NuGet" .
```

### Frequent Pitfalls

- Release build can fail due package/workflow alignment.
- Adapter parity needs explicit tests.
- Performance work should be benchmarked before/after when user asks for optimization report.

### Preferred Flow

1. Identify adapter-agnostic vs adapter-specific logic.
2. Keep Telegram and Max parity visible.
3. For optimization: measure before/after and document impact.

## ArduinoAndRaspberry

### What Matters

- Embedded/runtime behavior, axis motion, synchronization rules.
- Python code, Raspberry runtime modes, Arduino emulator.
- Russian engineer/debugger documentation.

### Useful Commands

```powershell
python -m pytest
rg -n "axis|motion|sync|timeout|servo|calibration|runtime|mode" raspberry arduino docs tests
```

### Frequent Pitfalls

- Runtime semantics matter more than superficial refactor.
- User requires clean Russian docs and UI/log strings.
- Timing/synchronization behavior should be tested with deterministic counters.

### Preferred Flow

1. Turn motion rule into tests first.
2. Keep hardware assumptions explicit.
3. Update Russian operator/debugger docs after behavior changes.

## PDFAnnotator

### What Matters

- Avalonia desktop app for PDF extraction, table editing, annotations.
- PDF rendering fidelity and coordinate mapping.
- Russian UI text and encoding were recurring concerns.

### Useful Commands

```powershell
dotnet build
dotnet test
rg -n "Pdf|Annotation|Extraction|Preset|Table|Csv|Render|DPI|Color" src tests
```

### Frequent Pitfalls

- Mojibake/CP1251 issues appeared in XAML/text.
- `apply_patch` frequently failed due stale context and encoding differences.
- PDF page DPI/coordinate assumptions caused bugs.
- Color picker/style availability needs visual verification.

### Preferred Flow

1. Confirm package versions are current stable.
2. Build after every UI/XAML batch.
3. Render or screenshot key pages.
4. Preserve readable Russian text in files.

## UTEP / UTEP.Sample

### What Matters

- CLI/tooling, schema, manifest, agent runbook.
- Russian data should be readable, not escaped `\u041C` when user asks for human-editable data.
- `dotnet tool install` path/source behavior matters.

### Useful Commands

```powershell
dotnet build
dotnet test
dotnet tool install -g --add-source <local-package-output> utep
rg -n "UTEP|schema|manifest|tool|command|completion" .
```

### Frequent Pitfalls

- Local NuGet source path must point at actual `.nupkg` output.
- JSON escaping can be technically valid but unacceptable for human-maintained Russian content.

## Secretar / n8n / Browser-like Workflows

### What Matters

- n8n workflow/API interaction, browser automation, screenshots.
- Network/connectivity and Playwright availability were blockers.

### Frequent Pitfalls

- `npx @n8n/cli` may install but fail to connect.
- `playwright` module may be absent in project Node environment.
- Use bundled/browser tools when available rather than assuming local package.

## Engines / Presentations

### What Matters

- Editable presentation reconstruction from PDF/AI/source assets.
- Visual match to source render.
- User wants editable HTML/PPT-like structures, not flat images.

### Frequent Pitfalls

- PDF-to-image shortcuts violate editability requirement.
- Need inspect source assets: `.ai`, images, fonts, source downloads.
- Visual comparison to original render is part of acceptance.

### Preferred Flow

1. Locate source assets before reconstructing.
2. Preserve text/figures/images as editable elements.
3. Render contact sheets/screenshots and compare visually.
