# Core: Quest Mode

## Когда применять

- Для задач, где нужен обязательный `SPEC`-first цикл.
- Для изменений с повышенным риском, где нужно явно зафиксировать рамки перед реализацией.

## Когда не применять

- Для одношаговых справочных или формальных вопросов без изменения файлов.
- Когда результатом является только чтение/резюме уже существующей документации.

## MUST

- Перед любым изменением создавать/обновлять рабочую спецификацию в локальном `./specs/` репозитория задачи.
- Форму и canonical шаблон выбирать по `quest-governance.md`: `templates/specs/_template-small.md` для допустимого low-risk scope, иначе `templates/specs/_template.md`, из каталога текущего instruction stack.
- Не использовать локальный template из репозитория задачи как source template.
- Если canonical template не найден в центральном каталоге, останавливать фазу `SPEC` с явным сообщением о сломанном onboarding-контракте.
- Выбрать профиль из `instructions/profiles/*` и зафиксировать его в спецификации.
- Сохранять в спецификации исходное поручение, симптом и пользовательский сценарий: конкретизация решения не должна молча подменять результат. При завершении проверять этот сценарий, а не только последнюю техническую правку.
- Рабочая спецификация обязана содержать финальный раздел `Журнал действий агента` по canonical template.
- На фазе `SPEC` разрешено изменять только текущую рабочую спецификацию в локальном `./specs/`.
- До фразы пользователя `Спеку подтверждаю` запрещено менять код, инфраструктуру, `instructions/*`, `prompts/*`, `templates/*`, `scripts/*`, `README.md`, `CHANGELOG.md` и другие файлы проекта вне текущей рабочей спецификации.
- На фазе SPEC использовать `instructions/governance/spec-linter.md`, `instructions/governance/spec-rubric.md` и `instructions/governance/review-loops.md`.
- Перед запросом подтверждения спецификации выполнять `post-SPEC review-loop` выбранной глубины по `instructions/governance/review-loops.md`; исправления и повторные проверки определяет этот owner.
- В expanded SPEC выполнять `Pre-Approval Rework Prevention Gate`: заполнить или явно пометить как `Не применимо` с причиной `User-Observable Scenarios`, `Decision Ledger`, `Acceptance-to-Test Matrix`, `Expected User Review Objections` и `Role-Based Review Result`. Для short SPEC достаточно пяти содержательных проверок по `spec-linter.md` и компактного review по `review-loops.md`, без отдельных матриц и перечня неприменимых ролей.
- Если остаётся существенное user-owned решение, блокирующее EXEC, задать точный вопрос вместо запроса approval; применимость вопроса определяет `collaboration-baseline.md`.
- Фразу пользователя `Спеку подтверждаю` считать единственным переходом из фазы `SPEC` в фазу `EXEC`.
- После exact approval редакционная конкретизация в том же результате, scope и риске не сбрасывает фазу EXEC и не требует повторного подтверждения всей SPEC. Существенное изменение результата или риска оформить в SPEC и провести через действующий gate до зависимых изменений; независимая разрешённая работа может продолжаться.
- На фазах `SPEC` и `EXEC` обновлять `Журнал действий агента` при переходе фазы, существенном решении, blocker и завершении. Фиксировать evidence, остаток работы и фактическое решение человека, когда оно требовалось; не создавать строку на каждый tool call или рутинную проверку.
- На фазе EXEC реализовывать только утверждённый результат, соблюдая `Non-Goals` и ограничения спецификации; последнее уточнение само по себе не заменяет исходную цель.
- Перед финальным отчётом выполнять `User-Observable Completion Gate`: проверить исходный пользовательский сценарий, сопоставить реализацию и обязательные AC с фактическим evidence. Для expanded использовать `User-Observable Scenarios`, `Acceptance-to-Test Matrix` и `Expected User Review Objections`; для short — общую таблицу пяти проверок. Остаточный риск или follow-up не заменяет невыполненное обязательное условие; применимость PASS определяет review owner.
- Перед финальным отчётом выполнять `post-EXEC review-loop` выбранной глубины по `instructions/governance/review-loops.md`; исправлять необходимые in-scope нарушения и повторять затронутые проверки по этому owner, не расширяя diff ради LOW-предпочтений.
- Решения при review передавать пользователю по критерию существенности из `collaboration-baseline.md`; отсутствие единственного оптимального внутреннего варианта само по себе не требует вопроса.

## SHOULD

- Перед утверждением спецификации убедиться, что нет блокирующих `Открытых вопросов`.
- Включать `Acceptance Criteria` и список проверочных команд в конце спеки.
- Полный audit и review evidence хранить в SPEC; финальный ответ давать по outcome, проверкам и существенным ограничениям со ссылкой на артефакт. Не повторять весь audit в чате.

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
