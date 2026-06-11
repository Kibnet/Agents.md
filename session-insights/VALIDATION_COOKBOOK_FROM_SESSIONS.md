# Validation Cookbook From Sessions

Дата подготовки: 2026-06-05.

Цель: выбрать минимально-достаточную и полную проверку по типу задачи. Это снижает два повторяющихся класса ошибок: слишком широкие проверки в начале и недостаточное evidence в финале.

## Общий принцип

1. Сначала воспроизвести или проверить изменённое поведение узко.
2. Затем расширять до related suite.
3. Full suite запускать, когда:
   - изменение затрагивает shared contracts;
   - пользователь просит "все тесты";
   - PR/CI требует full validation;
   - targeted проверка не даёт достаточной уверенности.
4. Для UI дать визуальное evidence.
5. Для невозможной проверки явно указать blocker и next-best evidence.

## Task Type Matrix

| Тип задачи | Минимальная проверка | Полная проверка | Evidence в финале |
|---|---|---|---|
| `Agents` root docs/analytics | `pwsh -File scripts/validate-instructions.ps1` | + `pwsh -File scripts/test-validate-instructions.ps1` | обе команды green |
| Изменение `instructions/*` | SPEC + linter/rubric/review-loop + validators | validators + targeted tests for scripts/templates | spec path, validators, review findings |
| .NET business logic | targeted test class/method | related project tests, then solution tests if feasible | command + result + skipped scope |
| TUnit project | `--treenode-filter` targeted | executable with serial options/full project | exact treenode filter |
| Avalonia UI behavior | unit/headless/UI targeted test | related UI suite + screenshot | screenshot path + test result |
| Desktop visual polish | render/screenshot wide and narrow | screenshot states + UI tests if behavior changed | before/after or final screenshots |
| Android/mobile behavior | targeted unit/headless + emulator/real device check if available | APK build + adb/logcat + device interaction | device/emulator, APK/build result, log summary |
| Bot business rule | unit/integration test with mock API | real API/log check if safe and required | test result, API/log evidence without secrets |
| GitHub CI fix | reproduce failure locally if possible | inspect failing job logs + rerun/check status | run/job id or CI status summary |
| Package/release | `dotnet pack`/build metadata check | release workflow dry-run or CI | package version, workflow check |
| PDF/document/presentation | render output | visual comparison + source editability check | rendered pages/slides and artifact path |
| Python/embedded | targeted pytest/module test | hardware/emulator run if applicable | test/log result |
| Browser/web UI | Playwright/browser screenshot | desktop/mobile viewports + console errors | screenshot + console status |

## .NET / TUnit

### Preflight

```powershell
rg --files -g "*.sln" -g "*.csproj" -g "global.json"
rg -n "TUnit|xunit|NUnit|Microsoft.Testing.Platform|VSTest" . -g "*.csproj" -g "*.props" -g "*.targets"
```

### Targeted TUnit Pattern

Use this only after confirming the repo uses TUnit or Microsoft Testing Platform:

```powershell
dotnet run --project <test-project>.csproj -- --treenode-filter "/*/*/<ClassName>/*<TestName>*" --no-progress
```

If direct executable exists and build is current:

```powershell
.\path\to\TestProject.exe --treenode-filter "/*/*/<ClassName>/*" --maximum-parallel-tests 1 --parallelism-strategy fixed --no-ansi --no-progress --timeout 45m
```

### VSTest / xUnit Pattern

Use only after confirming VSTest-style filters:

```powershell
dotnet test <test-project>.csproj --filter FullyQualifiedName~<Name>
```

### Common Mistakes To Avoid

- Do not use `--filter` just because it is familiar.
- Do not use `--no-restore` unless restore is current.
- Do not use `--no-build` unless build is current.
- Do not treat NuGet SSL/auth failure as code failure.

## Avalonia / UI

### Minimum

- Behavior change: add or update UI/headless test.
- Layout/visual-only change: screenshot/render at relevant viewport/window sizes.

### Visual Evidence Checklist

- Wide desktop.
- Narrow/mobile width if feature supports it.
- Empty/loaded/error state when applicable.
- Buttons/icons fully visible.
- No unexpected wrap/overflow.
- Text fits and does not overlap.

### Common Mistakes To Avoid

- Passing build != accepted UI.
- Screenshot after only one viewport is often insufficient.
- Do not ignore user comments like "не компактно", "ущербно", "не полностью видна".

## Android

### Preflight

```powershell
Get-Command adb -ErrorAction SilentlyContinue
Get-ChildItem "$env:ANDROID_SDK_ROOT" -ErrorAction SilentlyContinue
adb devices
```

### Build Pattern

```powershell
$env:ANDROID_SDK_ROOT = '<ANDROID_SDK_ROOT>'
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
$env:JAVA_HOME = '<JAVA_HOME>'
dotnet build <android-project>.csproj -c Debug -t:Package -p:RuntimeIdentifier=android-arm64
```

### Runtime Check

```powershell
adb logcat -c
adb shell monkey -p <package> 1
adb logcat -d
```

### Common Mistakes To Avoid

- Real phone vs emulator ABI mismatch.
- Assuming physical phone is still connected.
- Ignoring logcat native library / permission errors.

## GitHub / PR / CI

### Preflight

```powershell
git status --short
git branch --show-current
git remote -v
```

If using `gh`:

```powershell
gh auth status
```

Prefer GitHub connector tools when available.

### CI Failure Flow

1. Fetch PR metadata.
2. Fetch commit workflow runs.
3. Fetch jobs.
4. Inspect failing job logs.
5. Reproduce locally if possible.
6. Fix, commit, push, verify CI.

### Common Mistakes To Avoid

- Opening duplicate PR.
- Creating branch without checking ref lock/permission.
- Using `gh` unauthenticated.
- Committing status-only line-ending noise.

## Docs / Instructions

For this `Agents` repository:

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
```

If changing canonical instruction files, use SPEC-first flow and related governance docs.

## Presentations / Documents / PDF

### Minimum

- Render final artifact.
- Compare to source/reference.
- Verify target language and editability requirements.

### Common Mistakes To Avoid

- Flattening editable presentation into images when user asked for editable structure.
- Translating visible text but missing text embedded in images.
- Not checking output after render.

## Bot/API Work

### Minimum

- Unit/integration test for business rule.
- Mock API when possible.
- Real API check only when necessary and safe.

### Sensitive Data Rule

- Do not print tokens.
- Do not commit configs with secrets.
- Redact logs in final summary.

## When Validation Is Blocked

Use this structure in final answer:

```text
Проверено:
- <commands>

Не удалось проверить:
- <command/scope>: <reason>

Next-best evidence:
- <what was checked instead>

Risk:
- <specific residual risk>
```
