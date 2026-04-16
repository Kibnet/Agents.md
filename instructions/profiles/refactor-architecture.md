# Profile: Architecture Refactoring

## Когда применять

- Для перераспределения ответственности между модулями.
- Для выделения сервисов, слоёв и точек интеграции с сохранением внешних контрактов.

## Когда не применять

- Для коротких багфиксов без значимого рефакторинга.
- Для задач, где важнее backward compatibility без изменений структуры.

## MUST

- Соблюдать общий процесс из `instructions/governance/refactoring-policy.md`.
- Составить схему зависимостей до и после изменений.
- Зафиксировать список публичных API и точки миграции.
- Проверить совместимость и обратную совместимость контрактов.
- Спланировать поэтапный rollout с возможностью отката.

## SHOULD

- Вести таблицу ответственности компонентов.
- Держать refactor в маленьких независимых шагах.

## MAY

- Обновлять документацию архитектурных решений по мере изменения структуры.

## Команды

```text
dotnet build
dotnet test
```

## Связанные документы

- [instructions/core/quest-governance.md](../core/quest-governance.md)
- [instructions/governance/refactoring-policy.md](../governance/refactoring-policy.md)
- [instructions/governance/spec-linter.md](../governance/spec-linter.md)
- [instructions/governance/spec-rubric.md](../governance/spec-rubric.md)
- [templates/specs/_template.md](../../templates/specs/_template.md)
