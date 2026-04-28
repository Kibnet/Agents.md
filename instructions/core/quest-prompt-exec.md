# Core: Quest Prompt for Execution

## Когда применять

- Когда пользователю нужна реализация уже утверждённой спецификации.
- Когда нужно запустить режим исполнения без дополнительной интерпретации задачи.

## Когда не применять

- На фазе Spec (до подтверждения спецификации).
- Для задач, где требуется доработка цели и границ.

## MUST

- Запрашивать входным параметром путь к файлу спецификации.
- Использовать `instructions/core/model-behavior-baseline.md` для outcome-first исполнения, progress updates и stop rules.
- Использовать `instructions/core/quest-mode.md` как owner-документ для фазовых правил исполнения.
- Реализовывать строго в пределах утверждённой спецификации.
- Соблюдать `Non-Goals` и ограничения.
- Выполнять все команды и проверки, указанные в спецификации.
- Использовать `instructions/governance/review-loops.md` для обязательного `post-EXEC review`.
- После реализации и обязательных проверок проводить `post-EXEC review` по правилам `instructions/core/quest-mode.md` и `instructions/governance/review-loops.md`.
- Если `post-EXEC review` приводит к нескольким жизнеспособным вариантам без uniquely best option, задавать пользователю точный вопрос вместо произвольного выбора.
- Формировать финальный отчёт со структурой: `Summary`, `Changed files`, `Tests`, `Review`, `Commands`, `How to verify`, `Follow-ups`.

## SHOULD

- Прозрачно перечислять отклонения от исходного плана, если они возникли в ходе исполнения.
- Отмечать зависшие проверки/неподтверждённые риски отдельным блоком `Follow-ups`.
- Кратко указывать, что именно было исправлено по итогам `post-EXEC review`.

## MAY

- Добавлять дополнительные sanity-проверки, если это ускоряет локальную обратную связь и не нарушает контракт.

## Команды

```text
Ты инженерный агент. Реализуй утверждённую спецификацию.

# Input
- Файл спеки: `/specs/<имя_файла>.md`

# Goal
Реализовать утверждённую spec end to end в пределах её целей, ограничений и `Non-Goals`.

# Success criteria
- Все изменения соответствуют утверждённой spec.
- Выполнены тесты и команды проверки из spec либо явно объяснено, почему проверка недоступна.
- `post-EXEC review` выполнен до финального отчёта.
- Критичные и высокоуверенные проблемы с однозначным исправлением устранены, а затронутые проверки повторены.
- Итоговый отчёт содержит `Summary`, `Changed files`, `Tests`, `Review`, `Commands`, `How to verify`, `Follow-ups`.

# Constraints
- Используй `instructions/core/model-behavior-baseline.md` для progress updates, stop rules и output contract.
- Используй `instructions/core/quest-mode.md` как owner фазовых правил `EXEC`.
- Используй `instructions/governance/review-loops.md` для обязательного `post-EXEC review`.
- Не выходи за `Non-Goals`, ограничения и acceptance criteria спеки.
- Не меняй публичный API, UX/product agreement или операционные договорённости вне утверждённой spec.

# Output
- Краткий итог изменений.
- Список изменённых файлов.
- Проверки и их результат.
- Итоги `post-EXEC review`, включая исправленные находки и остаточные риски.

# Stop rules
- Остановись и задай точный вопрос, если реализация требует выбора между несколькими жизнеспособными вариантами без uniquely best option.
- Остановись, если обнаружен блокер, который нельзя устранить в рамках утверждённой spec.
- Завершай только после обязательных проверок, `post-EXEC review` и повторной проверки исправлений.
```

## Связанные документы

- [instructions/core/quest-mode.md](./quest-mode.md)
- [instructions/core/quest-governance.md](./quest-governance.md)
- [instructions/core/model-behavior-baseline.md](./model-behavior-baseline.md)
- [instructions/core/quest-prompt-spec.md](./quest-prompt-spec.md)
- [instructions/governance/review-loops.md](../governance/review-loops.md)
