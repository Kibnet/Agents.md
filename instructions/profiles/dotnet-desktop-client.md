# Profile: .NET Desktop Client

## Когда применять

- Разработка desktop-приложений на `Avalonia`, `WPF` или `WinUI`.
- Изменения в UI-навигации, состояниях экрана, binding-командах и клиентской валидации.

## Когда не применять

- Для backend/API сервисов на .NET.
- Для frontend SPA и Python-проектов.

## MUST

- Не допускать блокировки UI-потока длительными синхронными операциями.
- При изменении пользовательского потока обновлять UI/integration тесты.
- Сохранять стабильность `automation-id`/test selectors для автотестов.
- Перед завершением запускать `dotnet build` и `dotnet test`.

## SHOULD

- Проверять сценарии навигации, восстановления состояния и обработки пользовательских ошибок.
- Изолировать platform-specific код от ViewModel/бизнес-логики.

## MAY

- Использовать headless UI smoke-тесты для быстрых локальных проверок.

## Команды

```powershell
dotnet build
dotnet test
dotnet test --filter "FullyQualifiedName~UITests"
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/contexts/testing-dotnet.md](../contexts/testing-dotnet.md)
- [instructions/profiles/ui-automation-testing.md](./ui-automation-testing.md)
