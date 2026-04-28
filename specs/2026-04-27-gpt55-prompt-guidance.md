# Адаптация каталога инструкций под GPT-5.5 prompt guidance

## 0. Метаданные
- Тип (профиль): `product-system-design`
- Владелец: `instructions/governance/routing-matrix.md`, новый core-документ `instructions/core/model-behavior-baseline.md`
- Масштаб: medium
- Целевой релиз / ветка: `2.2.0` / текущая рабочая ветка
- Ограничения:
  - не ослаблять существующие `SPEC -> EXEC` gate, testing requirements и safety/side-effect limits;
  - не превращать каталог в набор модельных советов без маршрутизации и owner-документа;
  - не переписывать все профили и workflow prompts механически, если точечная правка central stack решает задачу;
  - сохранять русский язык документов `instructions/*`;
  - использовать абсолютные `MUST` / `NEVER` только для истинных инвариантов, а judgement-call правила формулировать как decision rules.
- Связанные ссылки:
  - `https://developers.openai.com/api/docs/guides/prompt-guidance?model=gpt-5.5`
  - `https://developers.openai.com/api/docs/guides/latest-model`
  - `AGENTS.md`
  - `README.md`
  - `instructions/governance/routing-matrix.md`
  - `instructions/core/collaboration-baseline.md`
  - `instructions/core/quest-prompt-spec.md`
  - `instructions/core/quest-prompt-exec.md`
  - `instructions/governance/review-loops.md`
  - `templates/specs/_template.md`
  - `scripts/validate-instructions.ps1`
  - `CHANGELOG.md`

## 1. Overview / Цель
Адаптировать каталог инструкций под ближайшее использование исключительно с GPT-5.5: закрепить outcome-first стиль, явные success criteria, ограничения, stop rules, краткие progress updates, проверяемость и осознанную настройку reasoning/verbosity без избыточного пошагового prompt-scaffolding.

## 2. Текущее состояние (AS-IS)
- Каталог уже хорошо задаёт маршрутизацию, `QUEST` gate, профили, проверочные команды и review loops.
- При этом модельно-специфического owner-документа нет: правила поведения агента размазаны между `collaboration-baseline`, `quest-*`, `review-loops` и отдельными профилями.
- `quest-prompt-spec.md` и `quest-prompt-exec.md` используют длинные numbered prompt templates. Это допустимо для строгого `QUEST` workflow, но форма хуже соответствует GPT-5.5 guidance: сначала outcome/success criteria/constraints/output/stop rules, затем только обязательные процессные инварианты.
- `templates/specs/_template.md` фиксирует много секций, но не подсказывает кратко отделять обязательный outcome contract от нерелевантных деталей и не содержит явных stop rules для инструментальных/валидационных циклов.
- `review-loops.md` проверяет инженерные риски, но не проверяет prompt-quality риски GPT-5.5: избыточные абсолюты, лишний пошаговый процесс, отсутствие stop rules, неясный output contract, лишняя текущая дата.
- `routing-matrix.md` не включает отдельный baseline для GPT-5.5 behavior, поэтому consumer-репозитории не получают единую норму по outcome-first prompting.
- `README.md`, `AGENTS.md`, validator и changelog пока не знают о model-behavior baseline.

## 3. Проблема
Существующие инструкции рабочие, но для GPT-5.5 они слишком процессно распределены и не имеют единого owner-контракта, который заставляет агента сначала держать цель, критерии успеха, ограничения, контекст, формат результата и stop rules, а не следовать длинному списку шагов там, где точный путь не является инвариантом.

## 4. Цели дизайна
- Добавить единый core-документ для GPT-5.5 model behavior и включить его в central stack.
- Сохранить строгие workflow-инварианты `QUEST`, тестирования, безопасности и side effects.
- Переформатировать prompt wrappers под outcome-first структуру без потери обязательных gate-правил.
- Сделать specs более удобными для GPT-5.5: краткий contract first, нерелевантные секции можно явно помечать как `Не применимо`, stop rules фиксируются до исполнения.
- Добавить review-проверку качества инструкций с точки зрения GPT-5.5 guidance.
- Сохранить валидируемую структуру каталога и changelog.

## 5. Non-Goals (чего НЕ делаем)
- Не меняем бизнес-смысл `QUEST`: до подтверждения спеки реализация по-прежнему запрещена.
- Не удаляем существующие обязательные секции документов `instructions/*`.
- Не делаем массовый rewrite всех `instructions/profiles/*` и `prompts/business-process-automation/*` в этой задаче.
- Не внедряем API-level миграцию приложений на Responses API: этот репозиторий хранит инструкции, а не runtime-код OpenAI клиента.
- Не добавляем текущую дату в системные инструкции; GPT-5.5 aware of current UTC date, а business-specific timezone/date остаётся внешним контекстом.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
- `instructions/core/model-behavior-baseline.md` -> новый owner-документ для GPT-5.5 behavior: outcome-first, specificity, reasoning/verbosity, preambles, retrieval/tool budgets, validation, stop rules и phase-aware workflows.
- `instructions/governance/routing-matrix.md` -> подключить `model-behavior-baseline` как обязательный core для всех типов задач и назначить owner для model/prompt behavior.
- `AGENTS.md` -> добавить новый core-документ в список канонических owner-документов/короткий порядок работы.
- `README.md` -> отразить новую архитектурную часть каталога и GPT-5.5 target.
- `instructions/core/collaboration-baseline.md` -> добавить ссылку на model behavior как companion baseline без дублирования всех правил.
- `instructions/core/quest-prompt-spec.md` -> переписать prompt example в структуру `Goal / Success criteria / Constraints / Output / Stop rules`, сохранив обязательный `QUEST` gate.
- `instructions/core/quest-prompt-exec.md` -> аналогично переписать exec prompt example под outcome-first contract и проверяемые stop rules.
- `templates/specs/_template.md` -> добавить подсказки для target model, outcome contract, stop rules и явного `Не применимо` для нерелевантных секций.
- `instructions/governance/review-loops.md` -> добавить prompt-quality пункты в `post-SPEC review` и `post-EXEC review`.
- `scripts/validate-instructions.ps1` -> сделать новый core-документ обязательным путём каталога.
- `CHANGELOG.md` -> добавить `2.2.0` как minor release, потому что появляется новый core owner-документ и routing contract.

### 6.2 Детальный дизайн
- Новый `model-behavior-baseline.md` должен содержать обязательные секции по `document-contract.md`.
- Основные `MUST` нового baseline:
  - считать целевой моделью `gpt-5.5` для этого каталога;
  - формулировать задачи outcome-first: цель, критерии успеха, ограничения, доступный контекст, ожидаемый результат;
  - сохранять пошаговый процесс только там, где точный путь является инвариантом workflow, безопасности, валидации или side effects;
  - использовать `MUST` / `NEVER` для истинных инвариантов, а для judgement calls задавать условия выбора;
  - для tool-heavy задач давать короткий preamble/progress update перед инструментами и кратко обновлять пользователя во время долгой работы;
  - задавать stop rules для retrieval/tool/validation loops;
  - после изменений запускать наиболее релевантные validation commands или явно объяснять недоступность проверки;
  - не добавлять current date в центральные инструкции без business-specific причины;
  - при проектировании Responses workflows учитывать `phase` preservation, если assistant items replayed вручную.
- `SHOULD` нового baseline:
  - начинать с `reasoning.effort=medium` как balanced default, пробовать `low` перед повышением, а `high/xhigh` применять по eval/риску;
  - управлять длиной через `text.verbosity`, word budgets и output contract, не смешивая длину ответа с глубиной reasoning;
  - для factual/retrieval задач фиксировать evidence rules и minimum sufficient evidence;
  - для frontend/visual artifacts требовать render/inspection там, где это возможно.
- В prompt wrappers не нужно удалять все шаги: `SPEC` и `EXEC` являются точными workflow-инвариантами, поэтому процесс сохраняется как constraints/stop rules, а не как главный интерфейс prompt.
- В template спеки добавить компактные подсказки, не меняя обязательную нумерацию `1..20`, чтобы не ломать существующие specs и validator.

## 7. Бизнес-правила / Алгоритмы (если есть)
- Алгоритм применения GPT-5.5 baseline:
  - собрать central stack по `routing-matrix.md`;
  - подключить `model-behavior-baseline` вместе с остальными core-документами;
  - если профиль или governance-документ задаёт более строгий workflow-инвариант, соблюдать его;
  - если есть конфликт между outcome-first свободой и строгим gate/test/safety правилом, приоритет у строгого инварианта.
- Алгоритм выбора уровня детализации:
  - если точный путь обязателен для безопасности, мутаций файлов, валидации, compliance или внешнего side effect, описывать путь явно;
  - иначе описывать outcome, success criteria, constraints, evidence и final output, позволяя агенту выбрать путь.
- Алгоритм остановки инструментальных циклов:
  - после каждого tool/retrieval/validation результата проверять, достаточно ли данных для core request;
  - если достаточно, отвечать/завершать без дополнительных поисков;
  - продолжать только при недостающем обязательном факте, сломанной проверке, важном неподдержанном claim или явном запросе exhaustive coverage.

## 8. Точки интеграции и триггеры
- Entry point: `AGENTS.md`, затем `routing-matrix.md`.
- Routing trigger: любой тип задачи, потому что модельное поведение является core baseline.
- `QUEST` trigger: `quest-prompt-spec.md`, `quest-prompt-exec.md`, `templates/specs/_template.md`.
- Review trigger: `post-SPEC review` и `post-EXEC review`.
- Validator trigger: новый обязательный core-файл должен существовать и соответствовать структуре `instructions/*`.
- Release trigger: `CHANGELOG.md` фиксирует `2.2.0`.

## 9. Изменения модели данных / состояния
- Persisted-модель приложений не меняется.
- Структура обязательных секций `instructions/*` не меняется.
- Добавляется новый versioned core-документ и меняется routing metadata каталога.

## 10. Миграция / Rollout / Rollback
- Rollout:
  - добавить `model-behavior-baseline.md`;
  - подключить его в routing, entry point, README и validator;
  - обновить prompt wrappers, template спеки и review loops;
  - обновить changelog;
  - прогнать validator и regression suite validator.
- Обратная совместимость:
  - существующие consumer-репозитории продолжают использовать тот же `AGENTS.md` entry point;
  - `QUEST` gate и все ранее обязательные секции сохраняются;
  - старые рабочие specs не требуют миграции.
- Rollback:
  - удалить новый core-документ;
  - убрать его из routing, README, `AGENTS.md` и validator;
  - откатить prompt/template/review изменения;
  - удалить запись `2.2.0` из changelog.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria:
  - В каталоге есть `instructions/core/model-behavior-baseline.md` с обязательными секциями и ссылками.
  - `routing-matrix.md` подключает `model-behavior-baseline` как core baseline для всех типов задач.
  - `AGENTS.md` и `README.md` явно отражают GPT-5.5 target и новый owner-документ.
  - `quest-prompt-spec.md` и `quest-prompt-exec.md` используют outcome-first структуру prompt examples, сохраняя `QUEST` invariants.
  - `templates/specs/_template.md` помогает фиксировать outcome contract, target model, stop rules и `Не применимо` для нерелевантных секций.
  - `review-loops.md` проверяет отсутствие избыточных абсолютных правил, наличие stop rules и корректный output/evidence contract.
  - `scripts/validate-instructions.ps1` считает новый core-документ обязательным.
  - `CHANGELOG.md` содержит запись `2.2.0`.
  - `pwsh -File scripts/validate-instructions.ps1` и `pwsh -File scripts/test-validate-instructions.ps1` проходят.
- Какие тесты добавить/изменить:
  - обновить только required paths в validator; отдельный новый сценарий test suite не нужен, потому что существующий сценарий валидного каталога скопирует новый файл и проверит весь `instructions/*`.
- Characterization tests / contract checks для текущего поведения:
  - `rg -n "model-behavior-baseline|GPT-5\\.5|outcome-first|Stop rules|text\\.verbosity|reasoning\\.effort|current date|phase" AGENTS.md README.md instructions templates scripts CHANGELOG.md`
  - ручная сверка, что `QUEST` gate не ослаблен.
- Базовые замеры до/после для performance tradeoff:
  - не применимо; изменения документальные.
- Команды для проверки:
  - `pwsh -File scripts/validate-instructions.ps1`
  - `pwsh -File scripts/test-validate-instructions.ps1`
  - `rg -n "model-behavior-baseline|GPT-5\\.5|outcome-first|Stop rules|text\\.verbosity|reasoning\\.effort|current date|phase" AGENTS.md README.md instructions templates scripts CHANGELOG.md`

## 12. Риски и edge cases
- Слишком широкое требование outcome-first может быть ошибочно прочитано как отмена `QUEST` step gates; это нужно явно исключить.
- Новый model-specific baseline может устареть при следующей модели; файл лучше назвать `model-behavior-baseline.md`, а не `gpt-5-5-*`, чтобы будущая миграция была содержательной правкой, а не переименованием.
- Если validator не обновить, новый core-документ формально будет существовать, но не станет обязательной частью каталога.
- Если prompt wrappers переписать слишком кратко, агент может пропустить фазовые запреты `SPEC`; эти запреты должны остаться как constraints/stop rules.
- Если добавлять ссылку на официальные OpenAI URL в `instructions/*`, validator пропустит внешнюю ссылку, но документация может меняться; формулировки должны быть автономными.

## 13. План выполнения
1. После подтверждения спеки добавить `instructions/core/model-behavior-baseline.md`.
2. Обновить `routing-matrix.md`, `AGENTS.md`, `README.md` и `collaboration-baseline.md`.
3. Переформатировать prompt examples в `quest-prompt-spec.md` и `quest-prompt-exec.md`.
4. Обновить `templates/specs/_template.md` и `review-loops.md`.
5. Обновить `scripts/validate-instructions.ps1` и `CHANGELOG.md`.
6. Прогнать команды проверки.
7. Выполнить `post-EXEC review` на сохранение `QUEST` gate, отсутствие избыточных абсолютов и валидность ссылок.

## 14. Открытые вопросы
- Блокирующих открытых вопросов нет.

## 15. Соответствие профилю
- Профиль: `product-system-design`
- Выполненные требования профиля:
  - цели и `Non-Goals` выделены явно;
  - целевой публичный контракт каталога описан;
  - совместимость и rollback зафиксированы;
  - интеграционные аспекты routing, validator, review и onboarding/entry point учтены.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| `instructions/core/model-behavior-baseline.md` | Новый core owner-документ GPT-5.5 behavior | Единый контракт outcome-first prompting и stop rules |
| `instructions/governance/routing-matrix.md` | Подключить новый core baseline и owner conflict rule | Сделать правило маршрутизируемым |
| `AGENTS.md` | Добавить новый owner-документ в entry point | Чтобы consumer-агенты видели GPT-5.5 baseline |
| `README.md` | Обновить архитектуру и список точек входа | Документировать изменение каталога |
| `instructions/core/collaboration-baseline.md` | Добавить связь с model behavior без дублирования | Связать рабочий стиль и модельный baseline |
| `instructions/core/quest-prompt-spec.md` | Переписать prompt example в outcome-first структуру | Согласовать `SPEC` prompt с GPT-5.5 guidance |
| `instructions/core/quest-prompt-exec.md` | Переписать exec prompt example в outcome-first структуру | Согласовать `EXEC` prompt с GPT-5.5 guidance |
| `templates/specs/_template.md` | Добавить target model, outcome contract, stop rules, `Не применимо` подсказки | Улучшить качество specs под GPT-5.5 |
| `instructions/governance/review-loops.md` | Добавить prompt-quality review checks | Ловить избыточный process scaffolding и отсутствие stop rules |
| `scripts/validate-instructions.ps1` | Добавить новый core-документ в required paths | Сделать baseline обязательным |
| `CHANGELOG.md` | Добавить release entry `2.2.0` | Соблюсти versioning policy |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| Model behavior | Единого owner-документа нет | `model-behavior-baseline.md` в core stack |
| Prompt style | Длинные step lists в prompt wrappers | Outcome-first contract + обязательные constraints/stop rules |
| `QUEST` | Строгий process gate | Тот же gate, но описан как invariant, а не как общий стиль всех задач |
| Review | Инженерные риски | Инженерные риски + prompt-quality checks GPT-5.5 |
| Specs | Полная матрица секций без model/stop подсказок | Target model, outcome contract, stop rules и явное `Не применимо` |
| Validator | Новый baseline не обязателен | Новый baseline входит в required paths |

## 18. Альтернативы и компромиссы
- Вариант: править только `collaboration-baseline.md`.
- Плюсы:
  - меньше diff.
- Минусы:
  - модельное поведение смешается с общим collaboration contract;
  - нельзя назначить отдельного owner для GPT-5.5-specific правил.
- Почему выбранное решение лучше:
  - отдельный core baseline проще маршрутизировать, валидировать и заменить при будущей миграции модели.

- Вариант: переписать все профили и workflow prompts сразу.
- Плюсы:
  - максимальная полнота.
- Минусы:
  - большой риск случайно ослабить специализированные инварианты;
  - сложнее проверить и откатить.
- Почему выбранное решение лучше:
  - central baseline и prompt wrappers дают основной эффект; массовая чистка может быть отдельной задачей после наблюдения usage.

- Вариант: назвать файл `gpt-5-5-agent-baseline.md`.
- Плюсы:
  - предельно явно указывает модель.
- Минусы:
  - при следующей модели понадобится переименование и churn ссылок.
- Почему выбранное решение лучше:
  - `model-behavior-baseline.md` остаётся стабильным owner-документом, внутри которого можно менять целевую модель.

## 19. Результат quality gate и review
- чеклист из SPEC-LINTER.md:

### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, дизайн-цели и non-goals сформулированы. |
| B. Качество дизайна | 6-10 | PASS | Owner-документ, routing, rollout, rollback и совместимость описаны. |
| C. Безопасность изменений | 11-13 | PASS | `QUEST` gate явно не ослабляется; риски и план проверки есть. |
| D. Проверяемость | 14-16 | PASS | Acceptance criteria, команды и таблица файлов присутствуют. |
| E. Готовность к автономной реализации | 17-19 | PASS | Альтернативы разобраны, блокирующих вопросов нет, scope medium. |
| F. Соответствие профилю | 20 | PASS | Изменение касается публичного контракта подсистемы инструкций и валидатора. |

Итог: ГОТОВО

- итог по SPEC-RUBRIC.md:

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---|---|
| 1. Ясность цели и границ | 5 | Задача сведена к новому model-behavior baseline и точечным интеграциям. |
| 2. Понимание текущего состояния | 5 | Зафиксированы текущие сильные стороны и пробелы central stack. |
| 3. Конкретность целевого дизайна | 5 | Указаны точные файлы, роли, обязательные правила и prompt wrapper изменения. |
| 4. Безопасность (миграция, откат) | 5 | `QUEST` gate и структура каталога сохраняются; rollback локализован. |
| 5. Тестируемость | 5 | Есть validator, regression suite и targeted `rg` contract check. |
| 6. Готовность к автономной реализации | 5 | Блокирующих вопросов нет; решения по альтернативам приняты. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

- краткий Post-SPEC Review:
  - Статус: PASS
  - Что исправлено:
    - выбран стабильный owner-файл `model-behavior-baseline.md`, чтобы не создавать будущий rename churn;
    - явно сохранён `QUEST` gate как workflow-инвариант, несмотря на outcome-first стиль;
    - массовый rewrite всех профилей вынесен из scope, чтобы снизить риск случайной смены специализированных правил.
  - Что осталось на решение пользователя:
    - только подтверждение перехода в `EXEC`.

### Post-EXEC Review
- Статус: PASS
- Что исправлено до завершения:
  - добавлен `instructions/core/model-behavior-baseline.md` как отдельный owner-документ для `gpt-5.5`, outcome-first contract, verbosity/reasoning guidance, stop rules, current date и `phase` handling;
  - `routing-matrix.md`, `AGENTS.md`, `README.md`, `collaboration-baseline.md` и validator синхронизированы так, чтобы `model-behavior-baseline` входил в central stack для всех задач;
  - `quest-prompt-spec.md` и `quest-prompt-exec.md` переведены на структуру `Goal / Success criteria / Constraints / Output / Stop rules` без ослабления фазовых запретов `SPEC`/`EXEC`;
  - `templates/specs/_template.md` получил целевую модель, outcome contract, stop rules и явное правило `Не применимо` для нерелевантных секций;
  - `review-loops.md` теперь проверяет prompt-quality риски GPT-5.5 alongside инженерных рисков;
  - `CHANGELOG.md` обновлён записью `2.2.0`.
- Что проверено дополнительно для refactor / comments:
  - `QUEST` gate сохранён: фраза `Спеку подтверждаю` осталась единственным переходом в `EXEC`, а запрет изменений вне рабочей spec на фазе `SPEC` не ослаблен;
  - новый baseline не заменяет профильные owner-документы, testing, governance или safety rules;
  - targeted scan подтвердил наличие `model-behavior-baseline`, GPT-5.5 markers, `Stop rules`, `reasoning.effort`, `text.verbosity`, `current date` и `phase` в ожидаемых файлах.
- Проверки:
  - `pwsh -File scripts\validate-instructions.ps1` — PASS;
  - `pwsh -File scripts\test-validate-instructions.ps1` — PASS;
  - `git diff --check` — PASS, только стандартные предупреждения о будущей CRLF-нормализации в рабочей копии;
  - `rg -n "model-behavior-baseline|GPT-5\\.5|gpt-5\\.5|outcome-first|Stop rules|text\\.verbosity|reasoning\\.effort|current date|phase" AGENTS.md README.md instructions templates scripts CHANGELOG.md` — PASS.
- Остаточные риски / follow-ups:
  - массовая чистка всех профильных документов и guided workflow prompts намеренно оставлена вне scope; при необходимости её стоит проводить отдельной spec после наблюдения usage с GPT-5.5.

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
Заполняется инкрементально после каждого значимого блока работ. Одна строка = один завершённый значимый блок.

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | catalog-governance / GPT-5.5 prompt guidance migration | 0.94 | Не хватает только явного подтверждения пользователя для перехода в `EXEC` | Запросить подтверждение спеки фразой `Спеку подтверждаю` | Да | Нет | Задача меняет `instructions/*`, template, validator и changelog, поэтому по `quest-mode.md` до подтверждения можно менять только рабочую spec | `specs/2026-04-27-gpt55-prompt-guidance.md`, `AGENTS.md`, `README.md`, `instructions/*`, `templates/specs/_template.md`, `scripts/validate-instructions.ps1`, `CHANGELOG.md` |
| EXEC | добавление GPT-5.5 model behavior baseline и подключение central stack | 0.97 | Существенных данных не требуется | Обновить QUEST prompt wrappers, spec template и review loops | Нет | Да: пользователь подтвердил спеки фразой `Спеку подтверждаю` | Добавлен отдельный owner-документ, чтобы outcome-first и stop rules стали частью routing, а не разрозненными советами | `instructions/core/model-behavior-baseline.md`, `instructions/governance/routing-matrix.md`, `AGENTS.md`, `README.md`, `instructions/core/collaboration-baseline.md`, `scripts/validate-instructions.ps1`, `specs/2026-04-27-gpt55-prompt-guidance.md` |
| EXEC | обновление QUEST prompt wrappers, spec template и review loops | 0.96 | Существенных данных не требуется | Обновить changelog и выполнить проверки каталога | Нет | Нет | Строгие `QUEST` инварианты сохранены, но prompt examples и template теперь начинаются с outcome, success criteria, constraints, output и stop rules | `instructions/core/quest-prompt-spec.md`, `instructions/core/quest-prompt-exec.md`, `templates/specs/_template.md`, `instructions/governance/review-loops.md`, `specs/2026-04-27-gpt55-prompt-guidance.md` |
| EXEC | changelog, validation и post-EXEC review | 0.99 | Существенных данных не требуется | Завершить задачу и отчитаться пользователю | Нет | Нет | Validator, regression suite, targeted scan и post-review подтвердили структурную валидность и сохранение `QUEST` gate | `CHANGELOG.md`, `scripts/validate-instructions.ps1`, `specs/2026-04-27-gpt55-prompt-guidance.md`, `AGENTS.md`, `README.md`, `instructions/*`, `templates/specs/_template.md` |
