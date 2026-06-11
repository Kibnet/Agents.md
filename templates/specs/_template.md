# <Название изменения>

## 0. Метаданные
- Тип (профиль):
- Владелец:
- Масштаб: small / medium / large
- Целевая модель: gpt-5.5
- Целевой релиз / ветка:
- Ограничения:
- Связанные ссылки:

Если секция не применима, явно укажите `Не применимо` и короткую причину, вместо заполнения нерелевантными деталями.

## 1. Overview / Цель
Что именно меняется и зачем.

Outcome contract:
- Success means:
- Итоговый артефакт / output:
- Stop rules:

## 2. Текущее состояние (AS-IS)
- Как сейчас работает система
- Где живёт код (модули/классы)
- Скрытые зависимости, инварианты и межфайловые связи (если есть)
- Ограничения и проблемы

## 3. Проблема
Одна корневая проблема, которую решает эта спека.

## 4. Цели дизайна
- Разделение ответственности
- Повторное использование
- Тестируемость
- Консистентность
- Обратная совместимость (если применимо)

## 5. Non-Goals (чего НЕ делаем)
Жёсткие границы задачи.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
- Компонент/файл -> ответственность

### 6.2 Детальный дизайн
- потоки данных
- контракты / API
- output contract / evidence rules
- visual planning artifact для UI-facing изменений: wireframe/render/storyboard/annotated screenshot или `Не применимо` с причиной
- UI test video evidence для UI automation задач: `до`/`после` artifacts из автоматизированных UI test runs или `Не применимо` / fallback с причиной
- границы сохранения поведения / допустимые изменения контракта (если применимо)
- обработка ошибок
- производительность

### 6.3 User-Observable Scenarios
Для изменений, которые влияют на UI, output, workflow, delivery или поведение будущего агента, зафиксировать видимые пользователю сценарии. Для small-задач допустима 1 строка; если не применимо, указать `Не применимо` и причину.

| Scenario | User action / trigger | Expected visible result / output | Evidence required | Covered by AC |
| --- | --- | --- | --- | --- |
| ... | ... | ... | ... | ... |

### 6.4 State / Interaction Matrix
Для UI/workflow/stateful изменений описать ключевые переходы, empty/error/disabled/concurrent cases. Для stateless docs-only изменений указать `Не применимо`.

| Current state | Trigger | Expected transition/result | Empty/error/disabled/concurrent case | Notes |
| --- | --- | --- | --- | --- |
| ... | ... | ... | ... | ... |

### 6.5 Decision Ledger
Фиксировать решения, которые агент принимает сам, и решения, которые должен принять пользователь. Если есть `Needs user before EXEC = Да`, не запрашивать approval как готовую spec; вместо этого задать точный вопрос.

| Decision | Owner | Default / chosen option | Confidence | Risk if assumed | Needs user before EXEC |
| --- | --- | --- | ---: | --- | --- |
| ... | agent/user | ... | 0.0-1.0 | ... | Да/Нет |

### 6.6 Runtime / Config / Data Contract Matrix
Для backend, bot, CI, deploy, config, storage, API и integration задач зафиксировать source of truth и проверку. Если не применимо, указать причину.

| Contract area | Current source of truth | Expected change | Compatibility / migration | Verification |
| --- | --- | --- | --- | --- |
| ... | ... | ... | ... | ... |

## 7. Бизнес-правила / Алгоритмы (если есть)
Формальные правила, таблицы истинности, инварианты.

## 8. Точки интеграции и триггеры
- какие методы/события обязаны вызывать новую логику
- где происходит пересчёт / обновление

## 9. Изменения модели данных / состояния
- новые поля
- persisted vs calculated
- влияние на хранилище

## 10. Миграция / Rollout / Rollback
- поведение при первом запуске
- обратная совместимость
- план отката

## 11. Тестирование и критерии приёмки
Definition of Done / критерии готовности описывают, как проверить уже выполненную работу. Не использовать их как список подготовительных действий, если результат подготовки не является отдельным auditable artifact.

- Acceptance Criteria
- Какие тесты добавить/изменить
- Characterization tests / contract checks для текущего поведения (если применимо)
- Visual acceptance для UI-facing изменений: что должно совпасть с wireframe/render и как это проверить
- UI video evidence для UI-facing фич/багфиксов: команды, `до`/`после` artifact paths/links, применимость baseline и fallback evidence
- Базовые замеры до/после для performance tradeoff (если применимо)
- Команды для проверки
- Stop rules для test/retrieval/tool/validation loops

### Acceptance-to-Test Matrix
Каждый значимый acceptance criterion должен иметь test/check/evidence или явную причину, почему проверка невозможна.

| Acceptance criterion | Automated test | Manual / visual / log check | Evidence artifact | If not tested, why |
| --- | --- | --- | --- | --- |
| ... | ... | ... | ... | ... |

## 12. Риски и edge cases
- возможные проблемы
- способы смягчения

### Expected User Review Objections
Перед запросом approval предсказать вероятные замечания пользователя и либо закрыть их в spec, либо явно оставить как риск/вопрос. Для small-задач минимум 1 строка; для medium/large минимум 3 строки.

| Likely objection | Why likely | Mitigation in spec/code plan | Status |
| --- | --- | --- | --- |
| ... | ... | ... | mitigated / accepted-risk / ask-human |

### Rework Prevention Checklist
- Does the spec name what the user will see or operate?
- Does every user-visible scenario have evidence?
- Did the agent list decisions it assumed?
- Did the agent predict likely objections and mitigate them?
- Did role-based review run for the relevant task type?
- Are acceptance criteria verifiers, not preparation steps?
- Does EXEC have a path to prove the scenarios before final?

## 13. План выполнения
Пошаговый план реализации, если точный порядок является инвариантом. Иначе фиксировать этапы по outcome, dependencies и условиям остановки.

## 14. Открытые вопросы
Если есть — блокируют утверждение.

## 15. Соответствие профилю
- Профиль:
- Выполненные требования профиля:

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| ... | ... | ... |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| ... | ... | ... |

## 18. Альтернативы и компромиссы
- Вариант:
- Плюсы:
- Минусы:
- Почему выбранное решение лучше в контексте этой задачи:

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS/PARTIAL/FAIL | ... |
| B. Качество дизайна | 6-10 | PASS/PARTIAL/FAIL | ... |
| C. Безопасность изменений | 11-13 | PASS/PARTIAL/FAIL | ... |
| D. Проверяемость | 14-16 | PASS/PARTIAL/FAIL | ... |
| E. Готовность к автономной реализации | 17-19 | PASS/PARTIAL/FAIL | ... |
| F. Соответствие профилю | 20 | PASS/PARTIAL/FAIL | ... |

Итог: ГОТОВО / НУЖНА ДОРАБОТКА

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | | |
| 2. Понимание текущего состояния | | |
| 3. Конкретность целевого дизайна | | |
| 4. Безопасность (миграция, откат) | | |
| 5. Тестируемость | | |
| 6. Готовность к автономной реализации | | |

Итоговый балл: __ / 30
Зона: рискованно / под контролем / готово к автономному выполнению

### Role-Based Review Result
Заполнить релевантные роли. Нерелевантные роли можно пометить `Не применимо` с причиной. Для UI-facing задач роль `UX / designer` применима всегда; для config/deploy/CI/secrets/delivery задач применима роль `Delivery / operations / security`.

| Role | Applicability | Review question | Verdict | Required spec changes |
| --- | --- | --- | --- | --- |
| Business analyst / domain workflow | applicable / not applicable | Does the workflow, business rule, config/state behavior match the user's actual goal? | PASS/NEEDS-FIX/ASK-HUMAN | ... |
| UX / designer | applicable / not applicable | Would the visible result, interaction, layout, copy and state handling pass user visual review? | PASS/NEEDS-FIX/ASK-HUMAN | ... |
| Tester / validation | applicable | Does every AC map to test/check/evidence and are negative/edge cases covered? | PASS/NEEDS-FIX/ASK-HUMAN | ... |
| Developer / architect | applicable | Are contracts, boundaries, migrations, performance and maintainability coherent? | PASS/NEEDS-FIX/ASK-HUMAN | ... |
| Delivery / operations / security | applicable / not applicable | Are git/CI/config/deploy/secrets/runtime risks handled and rollback clear? | PASS/NEEDS-FIX/ASK-HUMAN | ... |

### Post-SPEC Review
- Статус: PASS / NEEDS-FIX / ASK-HUMAN
- Scope reviewed: spec path, instruction stack, selected profile, open questions, planned changed files
- Decision: можно запрашивать подтверждение / нужно исправить / нужен выбор пользователя
- Review passes:
  - Scope/Evidence pass:
  - Contract pass:
  - Adversarial risk pass:
  - Role-Based pass:
  - Re-review after fixes / Fix and re-review:
  - Stop decision:
- Evidence inspected:
- Depth checklist:
  - Scope drift / unrelated changes:
  - Acceptance criteria:
  - User-observable scenarios / Decision ledger / Expected objections:
  - Validation evidence:
  - Unsupported claims:
  - Regression / edge case:
  - Comments/docs/changelog:
  - Hidden contract change:
  - Manual-review challenge: что бы я нашёл, если пользователь после моего `PASS` попросит отдельное ручное ревью?
- No-findings justification:

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| BLOCKER/HIGH/MEDIUM/LOW | scope / design / acceptance / risk / evidence / profile / prompt-quality | ... или `Нет находок` | ... | fixed / accepted-risk / ask-human / follow-up |

- Fixed before continuing:
- Checks rerun:
- Needs human:
- Residual risks / follow-ups:

### Post-EXEC Review
- Статус: PASS / NEEDS-FIX / ASK-HUMAN / Не выполнен до EXEC
- Scope reviewed: approved spec, `git status --short`, `git diff --stat`, relevant diff, tests/validation evidence, docs/changelog impact
- Decision: можно завершать / нужно исправить / нужен выбор пользователя / Не применимо до EXEC
- Review passes:
  - Scope/Evidence pass:
  - Contract pass:
  - Adversarial risk pass:
  - Role-Based pass:
  - Re-review after fixes / Fix and re-review:
  - Stop decision:
- Evidence inspected:
- Depth checklist:
  - Scope drift / unrelated changes:
  - Acceptance criteria:
  - User-observable scenarios / Acceptance-to-test matrix / Expected objections:
  - Validation evidence:
  - Unsupported claims:
  - Regression / edge case:
  - Comments/docs/changelog:
  - Hidden contract change:
  - Manual-review challenge: что бы я нашёл, если пользователь после моего `PASS` попросит отдельное ручное ревью?
- No-findings justification:

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| BLOCKER/HIGH/MEDIUM/LOW | spec compliance / regression / tests / docs / comments / unrelated changes / evidence / follow-up | ... или `Нет находок` | ... | fixed / accepted-risk / ask-human / follow-up |

- Fixed before final report:
- Checks rerun:
- Validation evidence:
- Unrelated changes:
- Needs human:
- Residual risks / follow-ups:

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
Заполняется инкрементально после каждого значимого блока работ. Одна строка = один завершённый значимый блок.

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |
