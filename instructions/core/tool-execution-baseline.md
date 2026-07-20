# Core: Tool Execution Baseline

## Когда применять

- Для `tool-heavy` задач: shell/tool calls, чтение или изменение файлов, patch, build/test, Git, browser/UI automation и внешняя runtime/config операция.
- До первого значимого tool call, чтобы предотвратить повторяемый операционный отказ.

## Когда не применять

- Для self-contained ответа без инструментов и изменения состояния.
- Как замену stack-specific testing, security, deployment или approval contract.

## MUST

- До repository delivery определить workspace root, branch/upstream, worktree/Git dir и dirty state; не смешивать unrelated changes с текущей задачей.
- Перед чтением неизвестного пути выполнить узкий inventory через `rg --files`, `Get-ChildItem -LiteralPath` или `Test-Path -LiteralPath`.
- Разделять literal path и glob: для `rg` передавать glob через `-g`, а wildcard не передавать в `-LiteralPath`.
- Нормализовать `rg` outcomes: `0` — matches, `1` без stderr — expected no-match, `>=2` или stderr — tool failure.
- В PowerShell использовать here-string вместо Bash heredoc; перед `:` после переменной применять `${name}` или format operator.
- Перед длинным build/test проверять runner/SDK/dependencies и заранее фиксировать команду, progress evidence и repo-specific timeout strategy.
- Классифицировать permission/auth/network/lock/missing dependency отдельно от product defect; не менять код для маскировки environment blocker.
- После failed patch перечитать актуальный участок и ownership, затем уменьшить hunk. Идентичный retry по stale context запрещён.
- После второго write conflict в одном файле остановить параллельных writers и вернуть ownership main agent; после третьего отказа без новой причины остановиться, а не продолжать retry loop.
- До Git mutation проверить `git rev-parse --git-dir`, top-level, branch/upstream и worktree. Не предлагать broad `writable_roots` как исправление защиты Git metadata.
- После timeout или tool failure повторять команду только с новой проверяемой гипотезой: другой scope, progress/log evidence, устранённый blocker или иной authoritative path.
- Считать lifecycle hooks дополнительной warn-only защитой: отсутствие warning не отменяет этот baseline и task-specific judgement.

## SHOULD

- Сначала использовать repo-proven команды и существующие scripts, затем вводить новый invocation pattern.
- Сужать `rg` и filesystem searches до вероятных каталогов, расширяя scope только при недостаточном evidence.
- Для optional tools выполнять короткий availability preflight до зависимой работы.
- В финальном отчёте отделять product failures, expected outcomes и environment blockers.

## MAY

- Использовать read-only preflight template из `templates/codex/local-environment/`.
- Подключать targeted session-derived runbook после обязательного baseline, если задача повторяет известную проблему.

## Команды

```powershell
git rev-parse --show-toplevel
git rev-parse --git-dir
git branch --show-current
git status --short

rg --files <scope>
rg -n <pattern> <scope> -g "*.cs"
Test-Path -LiteralPath <path>
Get-Command <tool> -ErrorAction SilentlyContinue
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/governance/routing-matrix.md](../governance/routing-matrix.md)
- [instructions/core/collaboration-baseline.md](./collaboration-baseline.md)
- [instructions/core/testing-baseline.md](./testing-baseline.md)
- [instructions/contexts/session-insights-context.md](../contexts/session-insights-context.md)
- [instructions/onboarding/local-environment.md](../onboarding/local-environment.md)
