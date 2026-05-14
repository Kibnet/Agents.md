# Visual Planning Artifacts

## 0. Метаданные
- Тип (профиль): catalog-governance / product-system-design
- Владелец: central instruction catalog
- Масштаб: medium
- Целевая модель: gpt-5.5
- Целевой релиз / ветка: `2.4.0` / текущая рабочая ветка
- Ограничения:
  - На фазе SPEC изменяется только этот файл.
  - До фразы `Спеку подтверждаю` нельзя менять `instructions/*`, `templates/*`, `scripts/*`, `README.md`, `CHANGELOG.md` и другие проектные файлы.
  - Новое правило должно быть условным: применять к UI-facing визуальным фичам/исправлениям, но не требовать визуального артефакта для backend-only, copy-only без влияния на layout/flow/state/visual acceptance или невизуальных задач.
  - Не добавлять обязательную зависимость от конкретного инструмента дизайна, графического редактора или image generation.
- Связанные ссылки:
  - Не применимо: используются только локальные документы каталога и существующий workflow.

Если секция не применима, явно указано `Не применимо` и причина.

## 1. Overview / Цель
Добавить в центральные инструкции поведение: при планировании визуальных фич и исправлений агент должен заранее зафиксировать визуальный целевой артефакт, который показывает, как интерфейс должен выглядеть и работать после изменения.

Outcome contract:
- Success means:
  - `model-behavior-baseline.md` требует visual planning artifact для UI-facing визуальных изменений.
  - Canonical spec template подсказывает фиксировать wireframe/render/storyboard/annotated screenshot в TO-BE дизайне.
  - `review-loops.md` проверяет наличие такого артефакта или явного `Не применимо` в post-SPEC review.
  - `ui-automation-testing.md` связывает visual planning artifact с UI flow/state acceptance для задач с UI test suite.
  - `CHANGELOG.md` фиксирует новое поведение как minor change.
- Итоговый артефакт / output:
  - Обновленные markdown-инструкции и changelog.
  - Рабочая spec с журналом действий и quality gate.
- Stop rules:
  - На SPEC остановиться после готовой спеки, self-review и запроса подтверждения.
  - На EXEC остановиться после реализации, validator/test-validator, post-EXEC review и отчета.

## 2. Текущее состояние (AS-IS)
- `model-behavior-baseline.md` уже требует для frontend/visual/generated artifact задач рендерить или инспектировать результат доступными инструментами перед завершением.
- `templates/specs/_template.md` содержит TO-BE дизайн, output/evidence rules и acceptance criteria, но не просит целевой визуальный артефакт для UI-facing изменений.
- `review-loops.md` проверяет полноту spec, output/evidence contract и stop rules, но не проверяет визуальный target state.
- `ui-automation-testing.md` требует UI tests для UI behavior/visual flows при наличии test suite, но не требует заранее показать целевой интерфейс.
- `visual-feedback.md` описывает capture реального desktop window после/во время проверки, но не решает planning-задачу wireframe/render.

## 3. Проблема
При планировании визуальных изменений агент может описать UI только текстом. Это оставляет неоднозначными layout, состояния, flow, визуальные приоритеты и ожидаемый результат, из-за чего реализация и review могут расходиться с ожиданием пользователя.

## 4. Цели дизайна
- Разделение ответственности:
  - `model-behavior-baseline.md` задает общий инвариант поведения.
  - `templates/specs/_template.md` делает правило воспроизводимым в spec.
  - `review-loops.md` проверяет выполнение на post-SPEC.
  - `ui-automation-testing.md` уточняет связь с UI flow acceptance.
- Повторное использование:
  - Использовать любой доступный формат: ASCII wireframe, Mermaid/diagram, annotated screenshot, HTML/CSS prototype, generated bitmap mockup, Playwright-rendered preview.
- Тестируемость:
  - Проверять markdown-структуру и ссылки существующим validator.
  - Acceptance criteria фиксируют наличие rule text и changelog entry.
- Консистентность:
  - Для UI-facing задач spec должна показывать не только что меняется, но и какой visual target state ожидается.
- Обратная совместимость:
  - Невизуальные задачи не получают лишнее требование.
  - Если визуальный артефакт невозможен или непропорционален, агент должен явно указать причину и дать текстовую fallback-структуру экранов/состояний.

## 5. Non-Goals (чего НЕ делаем)
- Не создаем новый обязательный governance-документ.
- Не добавляем обязательную поддержку Figma, Canva, image generation или конкретного renderer.
- Не требуем pixel-perfect дизайн для каждой UI-задачи.
- Не меняем правила финальной визуальной проверки в `visual-feedback.md`.
- Не меняем CI/workflow и validator tests, кроме обычной проверки существующими командами.

## 6. Предлагаемое решение (TO-BE)

### 6.1 Распределение ответственности
- `instructions/core/model-behavior-baseline.md` -> общий behavior contract для visual planning artifacts.
- `templates/specs/_template.md` -> явное поле/подсказка в TO-BE и acceptance sections.
- `instructions/governance/review-loops.md` -> post-SPEC review проверяет visual artifact для UI-facing задач.
- `instructions/profiles/ui-automation-testing.md` -> профиль UI behavior связывает visual target artifact с тестируемыми сценариями.
- `CHANGELOG.md` -> запись `2.4.0`.

### 6.2 Детальный дизайн
Изменение `model-behavior-baseline.md`:
- Добавить `MUST` с условием:
  - Для задач, которые меняют UI layout, визуальное состояние, навигационный flow, feedback/error/success state или другое UI-facing поведение, на этапе планирования/SPEC фиксировать visual planning artifact до реализации.
  - Артефакт может быть wireframe, annotated screenshot, storyboard, lightweight HTML/CSS render, generated mockup или другой доступный render.
  - Артефакт должен показывать целевую структуру экрана и ключевые состояния/переходы, достаточные для review.
  - Если артефакт недоступен или непропорционален, явно указать `Не применимо` и дать текстовую fallback-схему layout/states.
- Добавить `SHOULD`:
  - Выбирать минимальную достаточную fidelity: ASCII/low-fi wireframe для простых правок, rendered prototype или screenshot/mockup для сложных layout/interaction changes.

Изменение `templates/specs/_template.md`:
- В `6.2 Детальный дизайн` добавить пункт:
  - `visual planning artifact для UI-facing изменений: wireframe/render/storyboard/annotated screenshot или Не применимо с причиной`
- В `11. Тестирование и критерии приёмки` добавить пункт:
  - `visual acceptance: что должно совпасть с wireframe/render и как это проверить`

Изменение `review-loops.md`:
- В post-SPEC review добавить проверку:
  - для UI-facing задач есть visual planning artifact или явное `Не применимо` с fallback layout/state description.

Изменение `ui-automation-testing.md`:
- Добавить `MUST`:
  - При планировании UI behavior/visual flow/state changes фиксировать visual target artifact и связывать его с e2e/smoke acceptance сценариями.
- Добавить `SHOULD`:
  - Использовать artifact как ориентир для screenshots/traces/video и для описания expected user-visible states.

Изменение `CHANGELOG.md`:
- Добавить `2.4.0` / `Changed`:
  - центральный behavior contract теперь требует visual planning artifact для UI-facing visual changes;
  - spec template и review-loop синхронизированы с этим правилом;
  - UI automation profile связывает visual artifact с acceptance scenarios.

Output/evidence rules:
- Визуальный артефакт не обязан быть высокоточным дизайном.
- Артефакт должен быть приложен или описан в месте, доступном reviewer: spec, markdown diagram, repo-relative artifact path, committed artifact, PR attachment, PR body или screenshot/render path. Если артефакт доступен только локально в текущем workspace, это нужно явно пометить как local-only evidence и указать ограничение доступности.
- Для interactive change нужно показывать хотя бы основные состояния: before/after, empty/loading/error/success или ключевой переход.

Границы сохранения поведения:
- Existing visual feedback/capture workflow остается прежним.
- Existing tests requirements остаются прежними.
- Новое правило усиливает planning quality, но не требует tool-specific setup.

## 7. Бизнес-правила / Алгоритмы (если есть)
Правило выбора fidelity:

| Условие | Минимальный артефакт |
| --- | --- |
| Малое визуальное изменение, один экран | ASCII/Markdown wireframe или annotated existing screenshot |
| Новый layout, сложное состояние, новая навигация | Wireframe + state notes или lightweight render |
| Interaction-heavy flow | Storyboard из ключевых состояний или render/prototype |
| Pixel/visual polish важен для acceptance | Screenshot/mockup/render с цветами, spacing и состояниями |
| Визуальный артефакт невозможен | `Не применимо` + причина + текстовая layout/state fallback-схема |

## 8. Точки интеграции и триггеры
- Триггеры применения:
  - пользователь просит визуальную фичу;
  - пользователь просит UI bugfix, layout fix, visual regression fix;
  - задача меняет визуальное состояние, navigation/interaction flow, empty/loading/error/success state;
  - spec/review требует согласования будущего UI до реализации.
- Интеграции:
  - `model-behavior-baseline.md` применяется всегда через routing.
  - `templates/specs/_template.md` применяется для QUEST задач.
  - `review-loops.md` применяется на post-SPEC.
  - `ui-automation-testing.md` применяется для UI behavior/visual flow задач при наличии UI suite.

## 9. Изменения модели данных / состояния
- Не применимо: runtime data model не меняется.
- Меняется contract центральных инструкций и canonical spec template.

## 10. Миграция / Rollout / Rollback
- Rollout:
  - Обновить 4 markdown-документа и changelog.
  - Запустить validator и validator tests.
- Rollback:
  - Вернуть изменения в этих файлах.
  - Удалить changelog entry.
- SemVer:
  - `MINOR` (`2.4.0`), потому что добавляется новое behavior rule без изменения структуры каталога и без удаления существующих правил.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria:
  - `model-behavior-baseline.md` содержит условный `MUST` про visual planning artifact для UI-facing изменений.
  - `templates/specs/_template.md` содержит подсказку для visual artifact в TO-BE дизайне и visual acceptance в критериях приемки.
  - `review-loops.md` проверяет visual artifact или explicit non-applicability на post-SPEC.
  - `ui-automation-testing.md` связывает artifact с UI acceptance сценариями.
  - `CHANGELOG.md` содержит запись `2.4.0`.
  - `rg` semantic contract check подтверждает наличие ключевых markers нового правила в `instructions`, `templates` и `CHANGELOG.md`.
  - Проверки проходят.
- Какие тесты добавить/изменить:
  - Новые автоматические тесты не нужны: документы покрываются validator structure/link checks, а смысловой contract проверяется обязательной `rg`-командой.
- Characterization tests / contract checks:
  - Перед EXEC проверить `git status --short`.
  - После EXEC обязательно проверить `rg -n "visual planning artifact|wireframe|visual acceptance|визуаль" instructions templates CHANGELOG.md`.
- Команды для проверки:
  - `pwsh -File scripts/validate-instructions.ps1`
  - `pwsh -File scripts/test-validate-instructions.ps1`
  - `rg -n "visual planning artifact|wireframe|visual acceptance|визуаль" instructions templates CHANGELOG.md`
  - `git diff --stat`
- Stop rules для test/retrieval/tool/validation loops:
  - Если validator падает, исправить markdown/links/sections и повторить.
  - Если `rg` contract check не находит ожидаемые markers нового правила, исправить соответствующие документы и повторить.
  - Если wording создает безусловный pixel-perfect requirement, исправить на fidelity-by-risk wording.

## 12. Риски и edge cases
- Риск: агент начнет тратить время на дорогой render для маленьких визуальных правок.
  - Смягчение: явно задать minimal sufficient fidelity.
- Риск: headless/backend environment не позволяет сделать render.
  - Смягчение: разрешить wireframe/storyboard/text fallback с причиной.
- Риск: правило будет применяться к невизуальным UI-internal изменениям.
  - Смягчение: триггер ограничен UI-facing visual/layout/state/flow changes.
- Риск: user-facing spec станет слишком длинной.
  - Смягчение: artifact может быть коротким и low-fi, если этого достаточно для review.

## 13. План выполнения
Этапы EXEC после подтверждения:

1. Обновить `instructions/core/model-behavior-baseline.md`.
2. Обновить `templates/specs/_template.md`.
3. Обновить `instructions/governance/review-loops.md`.
4. Обновить `instructions/profiles/ui-automation-testing.md`.
5. Добавить запись `2.4.0` в `CHANGELOG.md`.
6. Запустить:
   - `pwsh -File scripts/validate-instructions.ps1`
   - `pwsh -File scripts/test-validate-instructions.ps1`
7. Выполнить post-EXEC review и исправить найденные проблемы в рамках спеки.

## 14. Открытые вопросы
- Блокирующих вопросов нет.
- Неблокирующий будущий вопрос: нужен ли отдельный reusable template для PR/spec visual artifacts.

## 15. Соответствие профилю
- Профиль: `instructions/profiles/product-system-design.md`
- Выполненные требования профиля:
  - Цели и non-goals выделены.
  - Границы нового behavior contract описаны.
  - Public contract центральных инструкций зафиксирован.
  - Совместимость с существующими QUEST/review/UI testing документами описана.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| `specs/2026-05-14-visual-planning-artifacts.md` | Рабочая спецификация | QUEST SPEC gate |
| `instructions/core/model-behavior-baseline.md` | Новый conditional `MUST` и fidelity guidance | Центральный behavior contract |
| `templates/specs/_template.md` | Подсказки visual artifact и visual acceptance | Воспроизводимость в SPEC |
| `instructions/governance/review-loops.md` | Проверка visual artifact на post-SPEC | Quality gate |
| `instructions/profiles/ui-automation-testing.md` | Связка artifact с UI acceptance | UI flow-specific contract |
| `CHANGELOG.md` | Запись `2.4.0` | Версионирование каталога |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| Visual planning | Текстовое описание могло быть достаточным | Для UI-facing visual changes нужен visual planning artifact или explicit fallback |
| Spec template | Нет явной подсказки wireframe/render | Есть пункт visual planning artifact |
| Post-SPEC review | Проверяет общую полноту и evidence | Проверяет visual target artifact для UI-facing задач |
| UI automation profile | Требует UI tests | Связывает tests с заранее зафиксированным visual target |
| Final visual check | Уже есть render/inspect перед завершением | Не меняется; дополняется planning-side artifact |

## 18. Альтернативы и компромиссы
- Вариант: изменить только `ui-automation-testing.md`.
  - Плюсы: минимальная правка.
  - Минусы: не сработает для UI задач без существующего UI test suite.
  - Почему не выбран: требование пользователя шире, чем UI automation profile.
- Вариант: создать отдельный governance-документ.
  - Плюсы: максимальная детализация.
  - Минусы: избыточно для одного behavior rule; потребует routing/validator синхронизацию.
  - Почему не выбран: правило лучше как cross-cutting behavior baseline.
- Вариант: обновить `model-behavior-baseline`, template, review-loop и UI profile.
  - Плюсы: правило действует в planning, появляется в spec, проверяется review и уточняется для UI tests.
  - Минусы: больше файлов.
  - Почему выбранное решение лучше: оно закрывает весь путь от планирования до acceptance без нового документа.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, цели и Non-Goals зафиксированы. |
| B. Качество дизайна | 6-10 | PASS | Распределение ответственности, rollout/rollback и fidelity rules описаны. |
| C. Безопасность изменений | 11-13 | PASS | Документирован условный scope и проверки, runtime side effects нет. |
| D. Проверяемость | 14-16 | PASS | Acceptance criteria, команды и file table заданы. |
| E. Готовность к автономной реализации | 17-19 | PASS | Блокирующих вопросов нет, план EXEC конкретен. |
| F. Соответствие профилю | 20 | PASS | Профиль и выполненные требования указаны. |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---|---|
| 1. Ясность цели и границ | 5 | Цель, output, Non-Goals и stop rules заданы. |
| 2. Понимание текущего состояния | 5 | Описаны существующие baseline/template/review/UI contracts. |
| 3. Конкретность целевого дизайна | 5 | Перечислены точные файлы и типы формулировок. |
| 4. Безопасность (миграция, откат) | 5 | Rollout/rollback и SemVer impact указаны. |
| 5. Тестируемость | 5 | Есть validator/test-validator и rg contract checks. |
| 6. Готовность к автономной реализации | 5 | Нет blockers, порядок EXEC определен. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

### Post-SPEC Review
- Статус: PASS
- Что исправлено:
  - Правило сформулировано условно, чтобы не требовать визуальные артефакты для невизуальных задач.
  - Добавлено minimal sufficient fidelity, чтобы не превращать каждый UI bugfix в дорогой дизайн-процесс.
  - Добавлен fallback для headless/tool-limited сред.
  - Уточнено, что visual artifact должен быть доступен reviewer; local-only evidence требует явной пометки.
  - Исключение для copy-only задач сужено до случаев без влияния на layout, flow, state или visual acceptance.
  - `rg` semantic contract check переведен в обязательные команды проверки EXEC.
- Что осталось на решение пользователя:
  - Подтвердить spec фразой `Спеку подтверждаю` или попросить изменить proposed policy.

### Post-EXEC Review
- Статус: PASS
- Что исправлено до завершения:
  - В core baseline и review loop перенесено требование доступности visual artifact для reviewer.
  - В core baseline добавлено исключение для copy-only задач без влияния на layout, flow, state или visual acceptance.
- Что проверено дополнительно для refactor / comments:
  - Проверено, что изменение не является refactor и не добавляет code comments.
  - Проверено, что wording не создает безусловный pixel-perfect requirement и допускает minimal sufficient fidelity.
- Остаточные риски / follow-ups:
  - Нет блокирующих рисков. Возможный будущий follow-up: отдельный reusable template для visual artifacts в spec/PR, если команда захочет стандартизировать формат.

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
Заполняется инкрементально после каждого значимого блока работ. Одна строка = один завершённый значимый блок.

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Сбор контекста и маршрутизация | 0.95 | Нет | Создать рабочую spec | Нет | Нет | Изменение центральных инструкций требует QUEST SPEC gate; выбран `product-system-design`, потому что меняется поведенческий contract планирования. | `AGENTS.md`, `routing-matrix.md`, `model-behavior-baseline.md`, `quest-*`, `visual-feedback.md`, `ui-automation-testing.md`, `templates/specs/_template.md` |
| SPEC | Черновик и review спецификации | 0.95 | Нет | Запросить подтверждение пользователя | Да | Да, ожидается подтверждение `Спеку подтверждаю` | Spec задает конкретные файлы, acceptance criteria, fallback для недоступного render и post-SPEC review. | `specs/2026-05-14-visual-planning-artifacts.md` |
| SPEC | Исправление review-находок | 0.95 | Нет | Повторить validator и запросить подтверждение | Нет | Да, пользователь попросил исправить spec | Уточнены доступность visual artifact для reviewer, границы copy-only исключения и обязательный semantic contract check. | `specs/2026-05-14-visual-planning-artifacts.md` |
| EXEC | Переход к реализации | 1.0 | Нет | Обновить behavior/template/review/UI policy | Нет | Да, пользователь подтвердил `Спеку подтверждаю` | Фраза подтверждения получена, поэтому разрешены изменения за пределами рабочей spec в границах утвержденного плана. | `specs/2026-05-14-visual-planning-artifacts.md` |
| EXEC | Реализация visual planning contract | 0.95 | Нет | Запустить validator, validator tests и semantic contract check | Нет | Нет | Обновлены core behavior, canonical spec template, post-SPEC review loop, UI automation profile и changelog в границах утвержденной spec. | `instructions/core/model-behavior-baseline.md`, `templates/specs/_template.md`, `instructions/governance/review-loops.md`, `instructions/profiles/ui-automation-testing.md`, `CHANGELOG.md` |
| EXEC | Post-review уточнение реализации | 0.95 | Нет | Повторить проверки | Нет | Нет | В core baseline и review loop перенесено требование доступности visual artifact для reviewer и исключение для copy-only задач без visual impact. | `instructions/core/model-behavior-baseline.md`, `instructions/governance/review-loops.md`, `specs/2026-05-14-visual-planning-artifacts.md` |
| EXEC | Проверки и post-EXEC review | 0.95 | Нет | Подготовить итоговый отчет | Нет | Нет | Validator, validator tests и semantic contract check прошли; post-EXEC review подтвердил соответствие реализации утвержденной spec. | `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1`, `instructions/*`, `templates/specs/_template.md`, `CHANGELOG.md` |
