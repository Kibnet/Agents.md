# Profile: Local Refactoring

## Когда применять

- Для локального структурного упрощения внутри модуля, feature area или bounded context.
- Для выделения функции/сервиса, упрощения ветвления, локализации side effects и удаления мёртвого кода без redesign межмодульных границ.
- Для задач, где поведение должно сохраниться, но текущая структура мешает безопасным изменениям.

## Когда не применять

- Для межмодульного redesign, смены публичных контрактов или migration-heavy изменений.
- Для массовых механических замен по репозиторию.
- Для чистого функционального изменения без выраженного refactor.

## MUST

- Соблюдать общий процесс из `instructions/governance/refactoring-policy.md`.
- Явно фиксировать локальные контракты, инварианты и поведение, которое должно остаться неизменным.
- Иметь минимальную страховку для затронутого участка: существующие тесты, characterization tests или другой воспроизводимый safety net.
- Делать изменения малыми шагами, каждый из которых можно проверить отдельно.

## SHOULD

- Предпочитать переименование, выделение, удаление мёртвого кода и упрощение ветвления перед введением новых абстракций.
- Держать expensive-операции и side effects видимыми, а не размазывать их по нескольким мелким прокладкам.
- Обновлять комментарии рядом с hotspot-участком, если после refactor меняется скрытый контекст или границы безопасного изменения.

## MAY

- Добавлять краткую таблицу `было -> стало` для локального hotspot, если diff неочевиден по месту.

## Команды

```text
dotnet test
npm test
```

## Связанные документы

- [instructions/core/quest-governance.md](../core/quest-governance.md)
- [instructions/governance/refactoring-policy.md](../governance/refactoring-policy.md)
- [instructions/governance/spec-linter.md](../governance/spec-linter.md)
- [instructions/governance/spec-rubric.md](../governance/spec-rubric.md)
- [templates/specs/_template.md](../../templates/specs/_template.md)

