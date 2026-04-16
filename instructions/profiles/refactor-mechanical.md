# Profile: Mechanical Refactoring

## Когда применять

- Для массовых чисток, удаления зависимостей и технического упорядочивания.
- Для механических замен API/типов без изменения бизнес-смыслов.

## Когда не применять

- Для сложных изменений с влиянием на контрактную логику.
- Когда требуется новая архитектура, а не техническая чистка.

## MUST

- Соблюдать общий процесс из `instructions/governance/refactoring-policy.md`.
- Вести таблицу объёма изменений по файлам.
- Вести матрицу соответствий `было → стало`.
- Планировать поэтапное выполнение с промежуточными проверками.
- Определить критерии завершённости и отката каждого этапа.

## SHOULD

- Использовать автоматизацию для больших объёмов, но контролировать semantic diff.
- Проверять форматирование и сборку после каждого этапа.
- После массовой замены делать ручной проход по пограничным случаям и устаревшим комментариям.

## MAY

- Добавлять refactor-сводки для code reviewers.

## Команды

```text
dotnet format
dotnet build
```

## Связанные документы

- [instructions/core/quest-governance.md](../core/quest-governance.md)
- [instructions/governance/refactoring-policy.md](../governance/refactoring-policy.md)
- [instructions/governance/spec-linter.md](../governance/spec-linter.md)
- [instructions/governance/spec-rubric.md](../governance/spec-rubric.md)
- [templates/specs/_template.md](../../templates/specs/_template.md)
