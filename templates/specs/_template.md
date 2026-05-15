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
- Acceptance Criteria
- Какие тесты добавить/изменить
- Characterization tests / contract checks для текущего поведения (если применимо)
- Visual acceptance для UI-facing изменений: что должно совпасть с wireframe/render и как это проверить
- UI video evidence для UI-facing фич/багфиксов: команды, `до`/`после` artifact paths/links, применимость baseline и fallback evidence
- Базовые замеры до/после для performance tradeoff (если применимо)
- Команды для проверки
- Stop rules для test/retrieval/tool/validation loops

## 12. Риски и edge cases
- возможные проблемы
- способы смягчения

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

### Post-SPEC Review
- Статус: PASS / NEEDS-FIX / ASK-HUMAN
- Scope reviewed: spec path, instruction stack, selected profile, open questions, planned changed files
- Decision: можно запрашивать подтверждение / нужно исправить / нужен выбор пользователя
- Review passes:
  - Scope/Evidence pass:
  - Contract pass:
  - Adversarial risk pass:
  - Re-review after fixes / Fix and re-review:
  - Stop decision:
- Evidence inspected:
- Depth checklist:
  - Scope drift / unrelated changes:
  - Acceptance criteria:
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
  - Re-review after fixes / Fix and re-review:
  - Stop decision:
- Evidence inspected:
- Depth checklist:
  - Scope drift / unrelated changes:
  - Acceptance criteria:
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
