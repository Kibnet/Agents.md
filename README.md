# Central Agents Instruction Catalog

Единый каталог правил для Codex-агента, который можно подключать в любых репозиториях.

## Что внутри

- `AGENTS.md` — единая точка входа для маршрутизации.
- `instructions/` — структурированные правила:
  - `core/` — базовые правила.
  - `contexts/` — контексты технологий и задач.
  - `profiles/` — технологические/проектные профили.
  - `governance/` — порядок версии, приоритетов и навигации.
  - `onboarding/` — шаблоны подключения в другие репозитории.
- `specs/_template.md` — шаблон спецификации `SPEC`.
- `instructions/core/quest-mode.md`, `instructions/core/quest-prompt-spec.md`, `instructions/core/quest-prompt-exec.md` — рабочие правила и шаблоны для режима `QUEST`.
- `instructions/governance/spec-linter.md`, `instructions/governance/spec-rubric.md` — чеклисты и шкалы оценки `SPEC`.
- `scripts/` — валидация каталога инструкций.

## Быстрый старт

1. Подключить каталог в репозиторий-потребитель.
2. Создать локальный `AGENTS.md` на основе шаблона из `instructions/onboarding/AGENTS.consumer.template.md`.
3. При необходимости создать `AGENTS.override.md`.
4. Проверить валидность ссылок и структуры:

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
```

## Как использовать в другом репозитории

### 1) Склонируйте этот каталог рядом с проектом

```bash
git clone https://github.com/<owner>/<repo>.git .agents-catalog
```

### 2) Укажите путь в локальном `AGENTS.md`

```powershell
# Пример для локального AGENTS.md
$env:AGENTS_ROOT = "C:\path\to\agents-catalog"
```

В шаблоне `AGENTS` укажите ссылку на `<AGENTS_ROOT>\AGENTS.md`.

### 3) Проверьте подключение

- Убедитесь, что локальный `AGENTS.md` содержит только ссылку на центральный каталог.
- Если нужны локальные доп. требования, добавьте их в `AGENTS.override.md` (только ужесточение MUST).

## Quality Gate

- Все правки в `instructions/` должны проходить проверки:
  - `scripts/validate-instructions.ps1`
  - `scripts/test-validate-instructions.ps1`
- Версионирование изменений валидационно описано в `instructions/governance/versioning-policy.md`.
- Обновления фиксируйте в `CHANGELOG.md`.

## GitHub публикация

Для публичного репозитория рекомендуется включить GitHub Actions workflow, который запускает оба скрипта проверки на `push`/`pull_request` (в репозитории добавлен стандартный workflow `validate-instructions.yml`).
