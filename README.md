# Central Agents Instruction Catalog

Единый публичный каталог агентских инструкций для переиспользования в нескольких репозиториях.

## Canonical Entry Points

- `AGENTS.md` — стартовая точка и приоритет правил.
- `instructions/governance/routing-matrix.md` — канонический алгоритм маршрутизации (`core -> context -> profile -> governance`).
- `instructions/core/quest-governance.md` — обязательный `SPEC -> EXEC` gate для инженерных изменений.

## Repository Structure

- `instructions/core/` — базовые правила взаимодействия, тестирования и QUEST-режима.
- `instructions/contexts/` — контексты выполнения (debug, testing, performance, visual feedback).
- `instructions/profiles/` — технологические и типовые профили изменений.
- `instructions/governance/` — контракт документов, маршрутизация, версионирование и commit policy.
- `instructions/onboarding/` — шаблоны и quick start для подключения в репозитории-потребители.
- `specs/_template.md` — канонический шаблон спецификации.
- `scripts/` — валидатор структуры/ссылок и тест валидатора.

## How Routing Works

1. Прочитать `AGENTS.md`.
2. Открыть `instructions/governance/routing-matrix.md`.
3. Определить тип задачи и собрать instruction stack.
4. Для `SPEC`-фазы применять `spec-linter` и `spec-rubric`.

## Using In Another Repository

1. Склонировать каталог рядом с проектом:

```bash
git clone https://github.com/<owner>/<repo>.git .agents-catalog
```

2. Указать путь к каталогу:

```powershell
$env:AGENTS_ROOT = "C:\path\to\agents-catalog"
```

3. В репозитории-потребителе создать:
- `AGENTS.md` по шаблону `instructions/onboarding/AGENTS.consumer.template.md`.
- `AGENTS.override.md` при необходимости локальных ужесточений MUST.

4. Проверить, что локальный `AGENTS.md` ссылается на `<AGENTS_ROOT>\AGENTS.md`, без дублирования правил.

## Quality Gate

Перед завершением изменений запускать:

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
```

Политики:

- `instructions/governance/versioning-policy.md`
- `instructions/governance/document-contract.md`
- `CHANGELOG.md`

## CI

В репозитории добавлен workflow:

- `.github/workflows/validate-instructions.yml`

Он запускает валидацию на `push` и `pull_request`.
