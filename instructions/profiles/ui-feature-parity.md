# Profile: UI Feature Parity

## Когда применять

- Для выравнивания функциональности между UI-реализациями/режимами.
- Для задач, где нужно сравнить и синхронизировать поведенческие сценарии интерфейса.

## Когда не применять

- Для backend-only изменений без UI-сцепления.
- Для задач с единичной точкой входа без вариативных экранов/режимов.

## MUST

- Составить список расхождений и приоритетов.
- Описать целевую UI-структуру и поведенческие сценарии.
- Зафиксировать guards и условия доступа в ключевых флоу.
- Определить пошаговый план по приоритетам parity.

## SHOULD

- Проверять пользовательские сценарии на уровне flows, а не отдельных компонентов.
- Подтверждать соответствие автоматизированными UI тестами.

## MAY

- Добавлять миграционный план для исторических экранов.

## Команды

```text
npm run test:e2e:with-dev
dotnet test --filter "FullyQualifiedName~UITests"
```

## Связанные документы

- [instructions/core/quest-governance.md](../core/quest-governance.md)
- [instructions/profiles/ui-automation-testing.md](./ui-automation-testing.md)
- [instructions/contexts/testing-dotnet.md](../contexts/testing-dotnet.md)
- [instructions/contexts/testing-frontend.md](../contexts/testing-frontend.md)
- [instructions/governance/spec-linter.md](../governance/spec-linter.md)
- [instructions/governance/spec-rubric.md](../governance/spec-rubric.md)
- [templates/specs/_template.md](../../templates/specs/_template.md)
