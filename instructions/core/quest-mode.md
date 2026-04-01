# Core: Quest Mode

## Когда применять

- Для задач, где нужен обязательный `SPEC`-first цикл.
- Для изменений с повышенным риском, где нужно явно зафиксировать рамки перед реализацией.

## Когда не применять

- Для одношаговых справочных или формальных вопросов без изменения файлов.
- Когда результатом является только чтение/резюме уже существующей документации.

## MUST

- Перед любым изменением создавать/обновлять рабочую спецификацию в локальном `./specs/` репозитория задачи.
- Для шаблона использовать canonical путь `templates/specs/_template.md` из каталога инструкций, откуда загружены текущие правила.
- Не использовать локальный template из репозитория задачи как source template.
- Если canonical template не найден в центральном каталоге, останавливать фазу `SPEC` с явным сообщением о сломанном onboarding-контракте.
- Выбрать профиль из `instructions/profiles/*` и зафиксировать его в спецификации.
- На фазе `SPEC` разрешено изменять только текущую рабочую спецификацию в локальном `./specs/`.
- До фразы пользователя `Спеку подтверждаю` запрещено менять код, инфраструктуру, `instructions/*`, `prompts/*`, `templates/*`, `scripts/*`, `README.md`, `CHANGELOG.md` и другие файлы проекта вне текущей рабочей спецификации.
- На фазе SPEC использовать `instructions/governance/spec-linter.md`, `instructions/governance/spec-rubric.md` и `instructions/governance/review-loops.md`.
- Перед запросом подтверждения спецификации выполнять `post-SPEC review`, вносить объективно лучшие правки в spec и повторять затронутые quality gate проверки.
- Фразу пользователя `Спеку подтверждаю` считать единственным переходом из фазы `SPEC` в фазу `EXEC`.
- На фазе EXEC реализовывать только в границах `Non-Goals` и ограничений спецификации.
- Перед финальным отчётом выполнять `post-EXEC review`, исправлять критичные и высокоуверенные проблемы, повторять затронутые проверки и только потом завершать задачу.
- Если review упирается в несколько жизнеспособных вариантов без единственного оптимального решения, запрашивать решение у пользователя.

## SHOULD

- Перед утверждением спецификации убедиться, что нет блокирующих `Открытых вопросов`.
- Включать `Acceptance Criteria` и список проверочных команд в конце спеки.
- Хранить отчёт в формате, удобном для последующего аудита (`Summary`, `Changed files`, `Tests`, `Review`, `Commands`, `How to verify`, `Follow-ups`).

## MAY

- Добавлять отдельные доменные профили из `instructions/profiles/*` (например, для миграции архитектуры, UI parity и т.п.).
- Использовать шаблоны prompt для ускорения старта этапов.

## Команды

```powershell
Get-Content <AGENTS_ROOT>\templates\specs\_template.md
Get-Content .\instructions\governance\spec-linter.md
Get-Content .\instructions\governance\spec-rubric.md
Get-Content .\instructions\governance\review-loops.md
```

## Связанные документы

- [instructions/core/quest-governance.md](./quest-governance.md)
- [instructions/core/quest-prompt-spec.md](./quest-prompt-spec.md)
- [instructions/core/quest-prompt-exec.md](./quest-prompt-exec.md)
- [templates/specs/_template.md](../../templates/specs/_template.md)
- [instructions/governance/spec-linter.md](../governance/spec-linter.md)
- [instructions/governance/spec-rubric.md](../governance/spec-rubric.md)
- [instructions/governance/review-loops.md](../governance/review-loops.md)
