# Review Output Procedures

## 0. Метаданные
- Тип (профиль): `catalog-governance` + профиль `product-system-design`
- Владелец: центральный каталог агентских инструкций
- Масштаб: medium
- Целевая модель: gpt-5.5
- Целевой релиз / ветка: `2.6.0`
- Ограничения:
  - Фаза `SPEC`: менять только этот файл.
  - Фаза `EXEC`: не менять поведение `QUEST` gate и фразу перехода `Спеку подтверждаю`.
  - Новые правила должны быть процедурными и проверяемыми, без избыточного дублирования между owner-документами.
  - Изменения каталога требуют обновления `CHANGELOG.md`.
- Связанные ссылки:
  - `AGENTS.md`
  - `instructions/governance/routing-matrix.md`
  - `instructions/core/model-behavior-baseline.md`
  - `instructions/core/quest-governance.md`
  - `instructions/core/quest-mode.md`
  - `instructions/governance/document-contract.md`
  - `instructions/governance/review-loops.md`
  - `instructions/governance/versioning-policy.md`
  - `templates/specs/_template.md`
  - Google Engineering Practices: `https://google.github.io/eng-practices/review/reviewer/standard.html`
  - Google Engineering Practices: `https://google.github.io/eng-practices/review/reviewer/looking-for.html`
  - Google Engineering Practices: `https://google.github.io/eng-practices/review/developer/small-cls.html`
  - GitHub Docs: `https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/about-pull-request-reviews`
  - Microsoft Learn: `https://learn.microsoft.com/en-us/azure/devops/repos/git/about-pull-requests?view=azure-devops`

Если секция не применима, явно укажите `Не применимо` и короткую причину, вместо заполнения нерелевантными деталями.

## 1. Overview / Цель
Зафиксировать конкретные процедуры и формат вывода review для двух обязательных точек `QUEST` workflow:

- `post-SPEC review` для рабочей спецификации перед запросом подтверждения пользователя;
- `post-EXEC review` для изменений репозитория перед финальным отчётом.

Outcome contract:
- Success means:
  - `review-loops.md` задаёт пошаговую процедуру, severity-классификацию и обязательный output format для `post-SPEC review` и `post-EXEC review`.
  - `templates/specs/_template.md` содержит готовые блоки для фиксации `SPEC Linter`, `SPEC Rubric`, `Post-SPEC Review` и `Post-EXEC Review`.
  - `quest-prompt-spec.md` и `quest-prompt-exec.md` не противоречат новому формату и ссылаются на `review-loops.md` как owner-документ.
  - `CHANGELOG.md` отражает изменение как новый minor-релиз.
- Итоговый артефакт / output:
  - обновлённые governance/template документы;
  - changelog entry;
  - краткий EXEC-отчёт с validation и post-EXEC review.
- Stop rules:
  - На `SPEC` остановиться после готовой спеки, quality gate и запроса подтверждения.
  - На `EXEC` остановиться, если review выявит выбор между несколькими равноценными форматами, влияющими на командный workflow.
  - Не завершать EXEC без validator, validator tests и focused semantic check по новым review markers.

## 2. Текущее состояние (AS-IS)
- `instructions/governance/review-loops.md` уже является owner-документом для `post-SPEC review` и `post-EXEC review`.
- Сейчас он перечисляет обязательные области проверки, но не фиксирует:
  - точный порядок действий review;
  - минимальную классификацию находок;
  - единый Markdown-формат вывода;
  - что именно считать review изменений репозитория: scope diff, validation evidence, docs/changelog, unrelated changes.
- `templates/specs/_template.md` в секции 19 просит зафиксировать quality gate и краткий `Post-SPEC Review`, но не содержит готового формата таблиц.
- `instructions/core/quest-prompt-exec.md` требует финальный отчёт со структурами `Summary`, `Changed files`, `Tests`, `Review`, `Commands`, `How to verify`, `Follow-ups`, но формат блока `Review` не раскрыт.
- `github-delivery-policy.md` требует self-review перед ready for review, но не должен становиться owner-документом для локального `QUEST` review.
- Изученные best practices сходятся на нескольких инвариантах:
  - review должен проверять изменение в контексте системы, а не только локальный diff;
  - reviewer должен явно понимать и фиксировать reviewed scope, если проверял не весь change set;
  - feedback должен быть actionable, с понятным intent и разделением обязательных исправлений от nit/follow-up;
  - review должен учитывать design/code health, correctness, tests, comments, documentation, style/consistency, build/status evidence и размер/scope изменения;
  - значимые PR/change sets должны иметь понятное описание, правильных reviewers и validation evidence.

## 3. Проблема
Обязательный review уже существует, но его процедура и форма вывода недостаточно конкретны, поэтому разные агенты могут фиксировать review неполно, смешивать исправленные находки с остаточными рисками или не показывать reviewer, что именно было проверено в spec и repository diff.

## 4. Цели дизайна
- Разделение ответственности:
  - `review-loops.md` остаётся owner-документом процедур и output format.
  - `templates/specs/_template.md` даёт готовые блоки для сохранения результата в рабочей spec.
  - prompt wrappers только направляют к owner-документу и не дублируют полный контракт.
- Повторное использование:
  - Один формат должен работать для local QUEST, PR preparation и финального отчёта.
- Тестируемость:
  - Наличие новых markers проверяется targeted search.
  - Структурная валидность каталога проверяется существующими scripts.
- Консистентность:
  - Формат должен использовать существующие статусы `PASS / NEEDS-FIX / ASK-HUMAN`.
  - Severity должна быть короткой и применимой к обоим review: `BLOCKER`, `HIGH`, `MEDIUM`, `LOW`.
- Обратная совместимость:
  - Существующие спеки остаются валидными.
  - Фраза подтверждения и фазовые запреты `QUEST` не меняются.

## 5. Non-Goals (чего НЕ делаем)
- Не меняем routing model, conflict resolution и набор обязательных owner-документов.
- Не создаём новый governance-документ для review.
- Не меняем validator contract для структуры `instructions/*`, если новые секции не требуют кода.
- Не вводим обязательный GitHub PR workflow для локальных задач без PR.
- Не требуем автоматически коммитить или публиковать review evidence.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
- `instructions/governance/review-loops.md` -> canonical procedure и output format для `post-SPEC review` и `post-EXEC review`.
- `templates/specs/_template.md` -> embedded placeholders для сохранения review в spec.
- `instructions/core/quest-prompt-spec.md` -> уточнение, что секция 19 использует формат из `review-loops.md`.
- `instructions/core/quest-prompt-exec.md` -> уточнение, что финальный `Review` использует формат из `review-loops.md`.
- `CHANGELOG.md` -> запись о minor-релизе `2.6.0`.

### 6.2 Детальный дизайн
- Добавить в `review-loops.md` обязательную процедуру `post-SPEC review`:
  - собрать context: путь spec, instruction stack, выбранный profile, open questions;
  - проверить scope, AS-IS, goals/non-goals, acceptance criteria, risk/rollback, output/evidence contract, stop rules, alternatives, profile fit;
  - классифицировать findings как `BLOCKER`, `HIGH`, `MEDIUM`, `LOW`;
  - исправить все findings с однозначным исправлением; `BLOCKER` и `HIGH` блокируют запрос подтверждения, если не исправлены или не переведены в `ASK-HUMAN`;
  - повторить затронутые quality gate checks;
  - сохранить результат в spec по фиксированному Markdown-шаблону.
- Добавить в `review-loops.md` обязательную процедуру `post-EXEC review`:
  - собрать context: утверждённая spec, `git status --short`, `git diff --stat`, релевантный diff, выполненные проверки;
  - проверить соответствие spec, отсутствие unrelated changes, tests/validation evidence, docs/changelog, comments/docstrings, regressions, edge cases, factual claims и follow-ups;
  - классифицировать findings как `BLOCKER`, `HIGH`, `MEDIUM`, `LOW`;
  - исправить все findings с однозначным исправлением; `BLOCKER` и `HIGH` блокируют финальный отчёт, если не исправлены или не переведены в `ASK-HUMAN`;
  - повторить затронутые проверки;
  - отдать финальный блок `Review` в фиксированном Markdown-формате.
- Output contract / evidence rules:
  - `Post-SPEC Review` обязательно хранится в рабочей spec.
  - `Post-EXEC Review` обязательно попадает в итоговый EXEC-отчёт; рабочая spec может быть дополнительно обновлена на EXEC, если это принято текущим QUEST log.
  - Таблицы findings должны быть пустыми только с явной строкой `Нет находок`.
  - Конкретный формат `Post-SPEC Review`:

```markdown
### Post-SPEC Review
- Статус: PASS / NEEDS-FIX / ASK-HUMAN
- Scope reviewed: spec path, instruction stack, selected profile, open questions, planned changed files
- Decision: можно запрашивать подтверждение / нужно исправить / нужен выбор пользователя

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| BLOCKER/HIGH/MEDIUM/LOW | scope / design / acceptance / risk / evidence / profile / prompt-quality | ... или `Нет находок` | ... | fixed / accepted-risk / ask-human / follow-up |

- Fixed before continuing:
- Checks rerun:
- Needs human:
- Residual risks / follow-ups:
```

  - Конкретный формат `Post-EXEC Review`:

```markdown
### Post-EXEC Review
- Статус: PASS / NEEDS-FIX / ASK-HUMAN
- Scope reviewed: approved spec, `git status --short`, `git diff --stat`, relevant diff, tests/validation evidence, docs/changelog impact
- Decision: можно завершать / нужно исправить / нужен выбор пользователя

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| BLOCKER/HIGH/MEDIUM/LOW | spec compliance / regression / tests / docs / comments / unrelated changes / evidence / follow-up | ... или `Нет находок` | ... | fixed / accepted-risk / ask-human / follow-up |

- Fixed before final report:
- Checks rerun:
- Validation evidence:
- Unrelated changes:
- Needs human:
- Residual risks / follow-ups:
```

  - Findings должны быть actionable: указывать область, риск, требуемое действие и статус. Личные предпочтения без contract/style/design основания оформляются как `LOW`/follow-up и не блокируют продолжение.
- visual planning artifact для UI-facing изменений: `Не применимо`: задача меняет инструкции review workflow, не UI layout/flow/state приложения.
- UI test video evidence для UI automation задач: `Не применимо`: задача не является UI-facing фичей или багфиксом приложения.
- границы сохранения поведения / допустимые изменения контракта:
  - Усиливается только формат и процедура review.
  - `QUEST` phase gate, approval phrase и forbidden mutations остаются без изменения.
- обработка ошибок:
  - Если review оставляет `ASK-HUMAN`, агент останавливается и задаёт точный вопрос.
  - Если проверки недоступны, report обязан указать причину и next-best check.
- производительность:
  - Не применимо: изменения документационные.

## 7. Бизнес-правила / Алгоритмы (если есть)
Severity:

| Severity | Смысл | Обязательное действие |
| --- | --- | --- |
| `BLOCKER` | Нельзя подтверждать spec или завершать EXEC без исправления/решения | Исправить или спросить пользователя |
| `HIGH` | Высокоуверенный дефект, риск регрессии или нарушение контракта | Исправить, если есть однозначное решение |
| `MEDIUM` | Существенная неоднозначность или улучшение качества без блокировки | Исправить при низкой стоимости или явно оставить risk/follow-up |
| `LOW` | Неблокирующее замечание, стиль, minor clarity | Исправить при низкой стоимости или зафиксировать |

Статусы:

| Status | Когда использовать |
| --- | --- |
| `PASS` | Блокеров нет, обязательные исправления внесены, остаточные риски явно названы |
| `NEEDS-FIX` | Есть обязательные исправления, которые агент должен выполнить до продолжения |
| `ASK-HUMAN` | Нужен выбор пользователя между жизнеспособными вариантами без uniquely best option |

Best-practice mapping:

| Практика | Как отражается в новом contract |
| --- | --- |
| Review должен улучшать code health без требования недостижимого perfection | `PASS` допускает остаточные явно названные low-risk follow-ups |
| Проверять design, correctness, tests, docs, comments, style/consistency и context | `Area` в findings и `Scope reviewed` фиксируют эти направления |
| Явно указывать reviewed scope | `Scope reviewed` обязателен в обоих review blocks |
| Feedback должен быть actionable и понятным | `Finding` + `Required action` + `Status` обязательны для каждой находки |
| Отделять обязательные исправления от nit/follow-up | Severity и status разделяют blockers, high-confidence fixes и accepted follow-ups |
| Значимые changes требуют validation/build evidence | `Validation evidence` и `Checks rerun` обязательны в `Post-EXEC Review` |

## 8. Точки интеграции и триггеры
- `post-SPEC review` запускается после первичного черновика spec, `SPEC Linter` и `SPEC Rubric`, но до запроса `Спеку подтверждаю`.
- `post-EXEC review` запускается после реализации и обязательных проверок, но до финального отчёта.
- `quest-prompt-spec.md` и `quest-prompt-exec.md` должны направлять агент к формату `review-loops.md`.
- `github-delivery-policy.md` остаётся отдельным PR/release policy; при необходимости PR body может использовать итоговый `post-EXEC review`, но это не новый обязательный контракт.

## 9. Изменения модели данных / состояния
- Новых данных нет.
- Persisted artifacts:
  - рабочая spec в `specs/`;
  - изменения Markdown-документов каталога;
  - changelog entry.

## 10. Миграция / Rollout / Rollback
- Rollout:
  - внести изменения в центральные документы;
  - обновить changelog;
  - выполнить validator и regression tests.
- Обратная совместимость:
  - старые spec-файлы не переписываются;
  - новые требования применяются к будущим review loops.
- Rollback:
  - revert изменений в `review-loops.md`, `templates/specs/_template.md`, prompt wrappers и `CHANGELOG.md`;
  - повторить validator и tests.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria:
  - `review-loops.md` содержит отдельные процедуры для `post-SPEC review` и `post-EXEC review`.
  - `review-loops.md` содержит severity/status contract, обязательный `Scope reviewed`, findings table и Markdown output templates.
  - `templates/specs/_template.md` содержит конкретные блоки `SPEC Linter Result`, `SPEC Rubric Result`, `Post-SPEC Review`, `Post-EXEC Review`.
  - `quest-prompt-spec.md` и `quest-prompt-exec.md` не дублируют процедуру, но явно требуют использовать формат из `review-loops.md`.
  - `CHANGELOG.md` содержит запись `2.6.0`.
- Какие тесты добавить/изменить:
  - Код тестов не менять, если validator уже покрывает структуру документов.
- Characterization tests / contract checks для текущего поведения:
  - Focused semantic check через `rg` по новым markers.
- Visual acceptance для UI-facing изменений: `Не применимо`: нет UI.
- UI video evidence для UI-facing фич/багфиксов: `Не применимо`: нет UI.
- Базовые замеры до/после для performance tradeoff: `Не применимо`.
- Команды для проверки:
  ```powershell
  pwsh -File scripts/validate-instructions.ps1
  pwsh -File scripts/test-validate-instructions.ps1
  rg -n "Post-SPEC Review|Post-EXEC Review|Scope reviewed|Required action|Validation evidence|BLOCKER|NEEDS-FIX|ASK-HUMAN|git diff --stat|Нет находок" instructions templates CHANGELOG.md
  rg -n "## \[2\.6\.0\]" CHANGELOG.md
  ```
- Stop rules для test/retrieval/tool/validation loops:
  - Остановиться, если validator или regression tests падают и причина не относится к внешней среде.
  - Остановиться, если semantic check не находит обязательные markers.

## 12. Риски и edge cases
- Риск: чрезмерный формат сделает review громоздким для small-задач.
  - Смягчение: разрешить строку `Нет находок` и компактные таблицы.
- Риск: дублирование процедуры между `review-loops.md` и prompt wrappers.
  - Смягчение: полный контракт только в `review-loops.md`.
- Риск: формат findings может восприниматься как обязательный для любого произвольного code review вне `QUEST`.
  - Смягчение: область применения документа остаётся `QUEST` phase review; PR policy может ссылаться на evidence, но не становится owner.
- Риск: старые спеки не соответствуют новому template.
  - Смягчение: не мигрировать исторические spec-файлы.

## 13. План выполнения
1. Обновить `instructions/governance/review-loops.md`: процедуры, severity/status, output templates.
2. Обновить `templates/specs/_template.md`: конкретные blocks для section 19.
3. Обновить `instructions/core/quest-prompt-spec.md` и `instructions/core/quest-prompt-exec.md` точечными ссылками на формат `review-loops.md`.
4. Обновить `CHANGELOG.md` версией `2.6.0`.
5. Выполнить validator, validator tests и focused semantic check.
6. Выполнить `post-EXEC review`, исправить обязательные находки, повторить затронутые проверки.

## 14. Открытые вопросы
Нет блокирующих вопросов.

## 15. Соответствие профилю
- Профиль: `product-system-design`
- Выполненные требования профиля:
  - Цели и non-goals выделены.
  - Целевой контракт workflow и границы owner-документов описаны.
  - Публичный output contract для review зафиксирован.
  - Совместимость с `QUEST` phase gate и существующими prompt wrappers описана.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| `instructions/governance/review-loops.md` | Добавить процедуры и output formats для `post-SPEC`/`post-EXEC` review | Центральный owner-документ review workflow |
| `templates/specs/_template.md` | Добавить готовые блоки фиксации review и quality gate | Новые spec-файлы должны сразу иметь правильный формат |
| `instructions/core/quest-prompt-spec.md` | Уточнить использование формата из `review-loops.md` | Prompt wrapper должен вести к owner-контракту |
| `instructions/core/quest-prompt-exec.md` | Уточнить формат финального блока `Review` | EXEC output должен быть консистентным |
| `CHANGELOG.md` | Добавить `2.6.0` | Значимое изменение каталога по versioning policy |
| `specs/2026-05-14-review-output-procedures.md` | Вести spec и EXEC journal | QUEST trace |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| Post-SPEC review | Список проверок и краткий шаблон | Пошаговая процедура, severity, output template |
| Post-EXEC review | Список проверок и краткий шаблон | Diff/validation-oriented процедура для изменений репозитория |
| Spec template | Общий пункт про quality gate и review | Готовые Markdown-блоки для linter, rubric, post-SPEC и post-EXEC |
| EXEC final report | Есть секция `Review`, формат не раскрыт | `Review` использует canonical format из `review-loops.md` |

## 18. Альтернативы и компромиссы
- Вариант: добавить отдельный `repository-review-policy.md`.
  - Плюсы: меньше размер `review-loops.md`.
  - Минусы: новый owner-документ, routing и validator изменения, выше риск расхождения с `QUEST`.
  - Почему выбранное решение лучше в контексте этой задачи: `review-loops.md` уже является owner-документом для этих phase review.
- Вариант: обновить только `templates/specs/_template.md`.
  - Плюсы: быстро и видно в новых спеках.
  - Минусы: не закрепляет процедуру как обязательный governance contract.
  - Почему выбранное решение лучше в контексте этой задачи: процедура должна быть правилом, а template только местом фиксации результата.
- Вариант: продублировать полный формат в prompt wrappers.
  - Плюсы: standalone prompt становится подробнее.
  - Минусы: повышает риск divergence.
  - Почему выбранное решение лучше в контексте этой задачи: prompt wrappers должны ссылаться на owner-документ.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, goals и non-goals зафиксированы. |
| B. Качество дизайна | 6-10 | PASS | Ответственность owner-документов, формат, алгоритм и rollout описаны. |
| C. Безопасность изменений | 11-13 | PASS | Совместимость, rollback и запрет изменения phase gate указаны. |
| D. Проверяемость | 14-16 | PASS | Acceptance criteria, validator commands и semantic check заданы. |
| E. Готовность к автономной реализации | 17-19 | PASS | План по файлам есть, блокирующих вопросов нет. |
| F. Соответствие профилю | 20 | PASS | Контракт workflow описан как product-system-design artifact. |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | 5 | Две review-точки и non-goals явно ограничены. |
| 2. Понимание текущего состояния | 5 | AS-IS описывает текущие `review-loops`, template и prompt wrappers. |
| 3. Конкретность целевого дизайна | 5 | Указаны процедуры, severity, statuses, output format и файлы. |
| 4. Безопасность (миграция, откат) | 5 | Rollout/rollback и совместимость со старыми спеками зафиксированы. |
| 5. Тестируемость | 5 | Есть validator, regression tests и semantic marker check. |
| 6. Готовность к автономной реализации | 5 | План и таблица файлов достаточны, открытых вопросов нет. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

### Post-SPEC Review
- Статус: PASS
- Scope reviewed: `specs/2026-05-14-review-output-procedures.md`, central `catalog-governance` stack, профиль `product-system-design`, planned changed files, текущие review risks.
- Decision: можно запрашивать подтверждение после внесённых исправлений.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| HIGH | output format | Спека требовала конкретный формат вывода, но не задавала сами Markdown-блоки и колонки. | Добавить explicit `Post-SPEC Review` и `Post-EXEC Review` templates с `Scope reviewed`, findings table и follow-up/evidence блоками. | fixed |
| HIGH | auto-fix rule | Правило исправления только `BLOCKER/HIGH` могло ослабить existing MUST исправлять все однозначные проблемы. | Заменить на правило исправления всех findings с однозначным исправлением; `BLOCKER/HIGH` блокируют переход. | fixed |
| MEDIUM | validation | Focused semantic check не проверял changelog marker `2.6.0`. | Добавить отдельную проверку `rg -n "## \[2\.6\.0\]" CHANGELOG.md`. | fixed |
| MEDIUM | instruction stack | В связанных документах не были отражены `document-contract.md` и `versioning-policy.md`. | Добавить документы в related links/context. | fixed |
| MEDIUM | best practices | Спека не фиксировала, какие внешние review practices учтены. | Добавить best-practice mapping по официальным Google/GitHub/Microsoft sources. | fixed |

- Что исправлено:
  - Уточнено, что `review-loops.md` остаётся единственным owner-документом процедуры, а prompt wrappers не должны дублировать полный контракт.
  - Добавлен explicit semantic check по markers `BLOCKER`, `NEEDS-FIX`, `ASK-HUMAN`, `git diff --stat`, `Нет находок`.
  - Добавлено правило совместимости: исторические spec-файлы не мигрируются.
  - Добавлены конкретные Markdown-шаблоны `Post-SPEC Review` и `Post-EXEC Review`.
  - Правило auto-fix синхронизировано с текущим `quest-mode`/`review-loops`: исправлять все однозначные findings, а не только `BLOCKER/HIGH`.
  - Validation дополнен проверкой changelog marker `2.6.0`.
  - В контекст добавлены `document-contract.md`, `versioning-policy.md` и изученные официальные best-practice sources.
- Checks rerun:
  - Manual SPEC linter/rubric impact check: результат остаётся `ГОТОВО`, `30/30`.
  - Focused marker check по текущей spec выполнен вручную при редактировании: обязательные markers присутствуют в плане.
- Needs human:
  - Нет.
- Что осталось на решение пользователя:
  - Нет.

### Post-EXEC Review
- Статус: PASS
- Scope reviewed: approved spec `specs/2026-05-14-review-output-procedures.md`, `git status --short`, `git diff --stat`, relevant diff for `review-loops.md`, canonical spec template, QUEST prompt wrappers, `CHANGELOG.md`, validation evidence.
- Decision: можно завершать.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| LOW | evidence | `git diff --stat` не включает untracked рабочую spec, поэтому scope дополнительно сверен через `git status --short`. | Явно указать spec в reviewed scope и changed files final report. | fixed |

- Fixed before final report:
  - Явно отделена рабочая spec как related untracked artifact, не unrelated change.
- Checks rerun:
  - `pwsh -File scripts/validate-instructions.ps1` -> PASS.
  - `pwsh -File scripts/test-validate-instructions.ps1` -> PASS.
  - `rg -n "Post-SPEC Review|Post-EXEC Review|Scope reviewed|Required action|Validation evidence|BLOCKER|NEEDS-FIX|ASK-HUMAN|git diff --stat|Нет находок" instructions templates CHANGELOG.md` -> PASS.
  - `rg -n "## \[2\.6\.0\]" CHANGELOG.md` -> PASS.
- Validation evidence:
  - Validator and regression suite passed.
  - Semantic marker checks passed.
- Unrelated changes:
  - Нет. `git status --short` показывает только файлы утверждённой spec.
- Needs human:
  - Нет.
- Residual risks / follow-ups:
  - Нет обязательных follow-ups.

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
Заполняется инкрементально после каждого значимого блока работ. Одна строка = один завершённый значимый блок.

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Сбор instruction stack и контекста | 0.96 | Нет | Подготовить рабочую spec | Нет | Нет | Задача меняет канонические инструкции, поэтому применён `catalog-governance` stack с QUEST gate. | `AGENTS.md`, `instructions/governance/routing-matrix.md`, `instructions/core/*`, `instructions/governance/*`, `templates/specs/_template.md` |
| SPEC | Черновик, quality gate и post-SPEC review | 0.97 | Нет | Запросить подтверждение пользователя | Да | Да, ожидается подтверждение `Спеку подтверждаю` | Spec задаёт конкретные процедуры, формат вывода, acceptance criteria, проверки и границы реализации без изменения файлов вне `specs/`. | `specs/2026-05-14-review-output-procedures.md` |
| SPEC | Закрытие review-рисков и сверка с best practices | 0.98 | Нет | Запросить подтверждение пользователя | Да | Да: пользователь попросил изучить best practices и закрыть риски spec | В spec добавлены concrete output templates, actionable findings contract, reviewed scope, changelog validation, central governance links и best-practice mapping по официальным источникам. | `specs/2026-05-14-review-output-procedures.md` |
| EXEC | Реализация review output contract | 0.96 | Нет | Запустить validator, regression tests и semantic marker check | Нет | Да: пользователь подтвердил spec | Обновлены owner review-loop, canonical spec template, QUEST prompt wrappers и changelog в границах утверждённой spec. | `instructions/governance/review-loops.md`, `templates/specs/_template.md`, `instructions/core/quest-prompt-spec.md`, `instructions/core/quest-prompt-exec.md`, `CHANGELOG.md`, `specs/2026-05-14-review-output-procedures.md` |
| EXEC | Validation и post-EXEC review | 0.98 | Нет | Завершить отчёт пользователю | Нет | Нет | Validator, regression suite и semantic marker checks прошли; post-EXEC review подтвердил соответствие реализации spec и отсутствие unrelated changes. | `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1`, `instructions/*`, `templates/specs/_template.md`, `CHANGELOG.md`, `specs/2026-05-14-review-output-procedures.md` |
