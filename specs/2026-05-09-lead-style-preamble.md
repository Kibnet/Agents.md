# Lead-style preamble для действий агента

## 0. Метаданные
- Тип (профиль): `product-system-design`
- Владелец: `instructions/core/model-behavior-baseline.md`, `instructions/core/collaboration-baseline.md`
- Масштаб: small
- Целевая модель: gpt-5.5
- Целевой релиз / ветка: `2.2.1` / текущая рабочая ветка
- Ограничения:
  - не ослаблять `QUEST` gate и правила side effects;
  - не превращать preamble в длинный план или запрос подтверждения для каждого шага;
  - сохранить краткость рабочих сообщений и не ухудшить скорость простых задач;
  - сохранить русский язык документов `instructions/*`.
- Связанные ссылки:
  - `AGENTS.md`
  - `instructions/core/model-behavior-baseline.md`
  - `instructions/core/collaboration-baseline.md`
  - `instructions/governance/routing-matrix.md`
  - `instructions/governance/versioning-policy.md`
  - `scripts/validate-instructions.ps1`
  - `CHANGELOG.md`

Если секция не применима, явно указано `Не применимо` и короткая причина.

## 1. Overview / Цель
Усилить центральные инструкции так, чтобы агент перед началом работы и перед значимыми действиями кратко и понятно объяснял пользователю, что собирается сделать, зачем и какой результат ожидает, в стиле короткого отчёта тимлиду.

Outcome contract:
- Success means: центральный baseline явно требует lead-style preamble до значимых действий, а collaboration baseline связывает это с прозрачностью работы.
- Итоговый артефакт / output: обновлённые `instructions/core/model-behavior-baseline.md`, `instructions/core/collaboration-baseline.md`, `CHANGELOG.md` и эта spec.
- Stop rules: не расширять изменение на prompt wrappers, profiles или templates, если центральные baseline-документы покрывают поведение.

## 2. Текущее состояние (AS-IS)
- `model-behavior-baseline.md` уже требует короткий user-visible preamble только для `multi-step` или `tool-heavy` задач.
- `collaboration-baseline.md` требует объяснимость: кратко фиксировать контекст, причины решений и последствия.
- Нет явного правила, что перед началом работы и перед значимым действием агент должен заранее сообщить, что именно он собирается сделать.
- Из-за этого агент может начать инструментальные действия или правки без понятного предварительного контекста для пользователя.

## 3. Проблема
Существующая формулировка слишком узкая: она покрывает tool-heavy сценарии, но не задаёт общий lead-style preamble как устойчивый рабочий ритуал перед значимыми действиями агента.

## 4. Цели дизайна
- Сделать preamble обязательным и понятным пользователю.
- Сохранить краткость: формат должен быть 1-2 предложения, а не полноценный план.
- Не требовать подтверждения перед каждым шагом, если это не задано `QUEST` или другим gate.
- Не перегрузить простые одношаговые ответы служебными сообщениями.
- Сохранить совместимость с outcome-first guidance и progress updates.

## 5. Non-Goals (чего НЕ делаем)
- Не меняем порядок маршрутизации документов.
- Не меняем `QUEST SPEC -> EXEC` правила.
- Не добавляем новый owner-документ.
- Не переписываем все profile-документы и prompt templates.
- Не требуем preamble перед чисто справочным однофразовым ответом без инструментов и side effects.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
- `instructions/core/model-behavior-baseline.md` -> основной owner для правила lead-style preamble.
- `instructions/core/collaboration-baseline.md` -> связывает preamble с прозрачной рабочей коммуникацией.
- `CHANGELOG.md` -> фиксирует patch release `2.2.1`.

### 6.2 Детальный дизайн
- В `model-behavior-baseline.md` заменить текущий `MUST` про preamble для `multi-step/tool-heavy` задач на более точное правило:
  - перед началом значимой работы и перед инструментами/мутациями давать короткий user-visible preamble;
  - формат: что будет сделано, зачем, какой результат ожидается или какие артефакты будут затронуты;
  - стиль: как короткий отчёт тимлиду;
  - без длинного плана и без лишнего запроса подтверждения, если gate не требует его.
- В `collaboration-baseline.md` добавить `MUST`, что перед значимыми блоками работы агент предварительно сообщает намерение и ожидаемый результат.
- Не менять `routing-matrix.md`: `model-behavior-baseline` уже является обязательным core baseline.

## 7. Бизнес-правила / Алгоритмы (если есть)
- Lead-style preamble нужен перед:
  - первым значимым блоком работы по задаче;
  - запуском инструментов, которые читают/проверяют контекст;
  - правками файлов;
  - командами проверки;
  - внешними side effects, если они разрешены текущим gate.
- Preamble можно не добавлять перед:
  - прямым коротким ответом без инструментов;
  - продолжением уже объяснённого блока, если новый шаг не меняет намерение;
  - финальным отчётом.
- Если другой документ требует подтверждения пользователя, preamble не заменяет это подтверждение.

## 8. Точки интеграции и триггеры
- Entry point остаётся `AGENTS.md -> routing-matrix.md`.
- Правило срабатывает через обязательный `model-behavior-baseline` для всех типов задач.
- `collaboration-baseline` дополнительно покрывает рабочую коммуникацию в репозиториях-потребителях.

## 9. Изменения модели данных / состояния
Не применимо: изменение касается только текстовых инструкций и не добавляет persisted state.

## 10. Миграция / Rollout / Rollback
- Rollout:
  - обновить `model-behavior-baseline.md`;
  - обновить `collaboration-baseline.md`;
  - добавить запись `2.2.1` в `CHANGELOG.md`;
  - выполнить validation commands.
- Обратная совместимость:
  - существующий `QUEST` и routing contract не меняются;
  - старые consumer-репозитории получают новое поведение через central stack.
- Rollback:
  - вернуть прежний `MUST` про preamble в `model-behavior-baseline.md`;
  - удалить новый `MUST` из `collaboration-baseline.md`;
  - удалить запись `2.2.1` из `CHANGELOG.md`.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria:
  - `model-behavior-baseline.md` явно требует lead-style preamble перед началом значимой работы и перед инструментами/мутациями.
  - `collaboration-baseline.md` содержит короткое правило о предварительном объяснении намерения и ожидаемого результата.
  - Формулировки не требуют длинных планов и не заменяют `QUEST` approval.
  - `CHANGELOG.md` содержит patch entry `2.2.1`.
- Какие тесты добавить/изменить:
  - новые тесты не нужны; структура документов не меняется.
- Characterization tests / contract checks для текущего поведения:
  - `rg -n "preamble|тимлид|значим" instructions/core/model-behavior-baseline.md instructions/core/collaboration-baseline.md CHANGELOG.md`
- Базовые замеры до/после для performance tradeoff:
  - Не применимо: runtime/performance не меняется.
- Команды для проверки:
  - `pwsh -File scripts/validate-instructions.ps1`
  - `pwsh -File scripts/test-validate-instructions.ps1`
  - `rg -n "preamble|тимлид|значим" instructions/core/model-behavior-baseline.md instructions/core/collaboration-baseline.md CHANGELOG.md`
- Stop rules для test/retrieval/tool/validation loops:
  - остановиться после успешного validator, regression suite и targeted scan;
  - не искать дополнительные документы, если изменённые baseline-документы и changelog покрывают acceptance criteria.

## 12. Риски и edge cases
- Слишком буквальное "перед тем как что-то сделать" может привести к шуму перед каждым микрошагом; формулировка должна ограничить правило значимыми блоками.
- Если сделать правило только в `collaboration-baseline.md`, оно будет хуже связано с GPT-5.5 outcome-first guidance; поэтому owner-формулировка должна быть в `model-behavior-baseline.md`.
- Если не упомянуть, что preamble не заменяет approval, можно случайно размыть `QUEST` gate.

## 13. План выполнения
1. Обновить `model-behavior-baseline.md` lead-style preamble rule.
2. Обновить `collaboration-baseline.md` коротким communication invariant.
3. Добавить `2.2.1` в `CHANGELOG.md`.
4. Выполнить validator, regression suite и targeted scan.
5. Сделать post-EXEC review и при необходимости исправить найденные проблемы.

## 14. Открытые вопросы
Блокирующих открытых вопросов нет.

## 15. Соответствие профилю
- Профиль: `product-system-design`
- Выполненные требования профиля:
  - цели и non-goals выделены;
  - публичный поведенческий контракт агента описан;
  - совместимость с `QUEST` и rollback зафиксированы;
  - security/side-effect аспект отражён через сохранение approval gates.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| `instructions/core/model-behavior-baseline.md` | Уточнить `MUST` про preamble до значимых действий | Сделать правило центральным model behavior contract |
| `instructions/core/collaboration-baseline.md` | Добавить communication invariant про предварительное объяснение намерения | Связать правило с ежедневной рабочей коммуникацией |
| `CHANGELOG.md` | Добавить `2.2.1` | Соблюсти versioning policy |
| `specs/2026-05-09-lead-style-preamble.md` | Рабочая spec и журнал действий | Соблюсти `QUEST` gate |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| Preamble | Только для `multi-step` / `tool-heavy` задач | Перед началом значимой работы и перед инструментами/мутациями |
| Стиль сообщения | Короткий user-visible preamble | Короткий отчёт тимлиду: что, зачем, ожидаемый результат |
| Approval gates | Не затронуты | Не затронуты; preamble не заменяет подтверждение |

## 18. Альтернативы и компромиссы
- Вариант: изменить только `collaboration-baseline.md`.
- Плюсы:
  - минимальный diff.
- Минусы:
  - правило хуже связано с owner-документом model behavior.
- Почему выбранное решение лучше в контексте этой задачи:
  - `model-behavior-baseline.md` уже содержит правило preamble, поэтому точечное уточнение снижает дублирование и сохраняет ownership.

- Вариант: добавить правило во все prompt wrappers.
- Плюсы:
  - максимально явно для отдельных workflow.
- Минусы:
  - лишний churn и риск расхождения формулировок.
- Почему выбранное решение лучше в контексте этой задачи:
  - central baseline применяется шире и уже подключён маршрутизацией.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, цели и non-goals зафиксированы. |
| B. Качество дизайна | 6-10 | PASS | Responsibility, правила, интеграции, rollout и rollback описаны. |
| C. Безопасность изменений | 11-13 | PASS | Acceptance criteria, риски и план не ослабляют `QUEST` gate. |
| D. Проверяемость | 14-16 | PASS | Открытых вопросов нет, команды проверки и таблица файлов есть. |
| E. Готовность к автономной реализации | 17-19 | PASS | Было/стало, альтернативы и quality gate описаны. |
| F. Соответствие профилю | 20 | PASS | Публичный поведенческий контракт и совместимость покрыты. |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---|---|
| 1. Ясность цели и границ | 5 | Правило ограничено lead-style preamble до значимых действий. |
| 2. Понимание текущего состояния | 5 | Зафиксированы текущие правила preamble и explainability. |
| 3. Конкретность целевого дизайна | 5 | Указаны точные файлы и содержание правок. |
| 4. Безопасность (миграция, откат) | 5 | `QUEST` approval сохраняется, rollback локальный. |
| 5. Тестируемость | 5 | Есть validator, regression suite и targeted scan. |
| 6. Готовность к автономной реализации | 5 | Блокирующих вопросов нет, scope small. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

### Post-SPEC Review
- Статус: PASS
- Что исправлено:
  - scope ограничен значимыми действиями, чтобы не создавать шум перед каждым микрошагом;
  - явно указано, что preamble не заменяет `QUEST` approval;
  - отказались от правки prompt wrappers, потому что central baseline покрывает задачу.
- Что осталось на решение пользователя:
  - подтверждение перехода в `EXEC` фразой `Спеку подтверждаю`.

### Post-EXEC Review
- Статус: PASS
- Что исправлено до завершения:
  - `model-behavior-baseline.md` теперь требует короткий lead-style preamble перед началом значимой работы, инструментами, мутациями файлов или внешними side effects;
  - `collaboration-baseline.md` теперь явно требует перед значимыми блоками работы сообщать намерение, причину действия и ожидаемый результат;
  - `CHANGELOG.md` получил patch entry `2.2.1`.
- Что проверено дополнительно для refactor / comments:
  - `QUEST` gate не ослаблен: preamble явно не заменяет отдельный approval gate;
  - изменение не добавляет новых комментариев/docstring и не меняет routing;
  - scope не расширен на profiles, prompt wrappers или templates.
- Проверки:
  - `pwsh -File scripts/validate-instructions.ps1` — PASS;
  - `pwsh -File scripts/test-validate-instructions.ps1` — PASS;
  - `rg -n "preamble|тимлид|значим" instructions/core/model-behavior-baseline.md instructions/core/collaboration-baseline.md CHANGELOG.md` — PASS;
  - `git diff --check` — PASS, только стандартные CRLF-предупреждения рабочей копии.
- Остаточные риски / follow-ups:
  - Остаточных блокирующих рисков нет; при будущей эксплуатации можно отдельно уточнить примеры хорошего/плохого preamble, если команда увидит шум в коммуникации.

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
Заполняется инкрементально после каждого значимого блока работ. Одна строка = один завершённый значимый блок.

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | catalog-governance / lead-style preamble | 0.96 | Не хватает только явного подтверждения пользователя для перехода в `EXEC` | Запросить подтверждение спеки фразой `Спеку подтверждаю` | Да | Нет | Изменение затрагивает канонические `instructions/*`, поэтому до approval можно менять только рабочую spec | `specs/2026-05-09-lead-style-preamble.md`, `instructions/core/model-behavior-baseline.md`, `instructions/core/collaboration-baseline.md`, `CHANGELOG.md` |
| EXEC | lead-style preamble baseline update | 0.98 | Существенных данных не требуется | Запустить validator, regression suite и targeted scan | Нет | Да: пользователь подтвердил spec фразой `спеку подтверждаю` | Правило добавлено в основной model behavior owner и связано с collaboration baseline без изменения routing или `QUEST` gate | `instructions/core/model-behavior-baseline.md`, `instructions/core/collaboration-baseline.md`, `CHANGELOG.md`, `specs/2026-05-09-lead-style-preamble.md` |
| EXEC | validation and post-EXEC review | 0.99 | Существенных данных не требуется | Завершить задачу и отчитаться пользователю | Нет | Нет | Validator, regression suite, targeted scan и post-review подтвердили структурную валидность и сохранение `QUEST` gate | `specs/2026-05-09-lead-style-preamble.md`, `instructions/core/model-behavior-baseline.md`, `instructions/core/collaboration-baseline.md`, `CHANGELOG.md` |
