# Profile: .NET Backend API

## Когда применять

- Разработка и сопровождение `ASP.NET Core` Web API, gRPC сервисов или background workers на .NET.
- Изменения в endpoint/handler бизнес-логике, API-контрактах или интеграциях с внешними системами.

## Когда не применять

- Для desktop-клиентов на .NET (Avalonia/WPF/WinUI).
- Для frontend SPA и Python-проектов.

## MUST

- Сохранять согласованность внешних контрактов (REST/gRPC/message schema).
- Для breaking изменений контракта фиксировать миграцию/версионирование API.
- Добавлять/обновлять unit и integration тесты для измененной логики.
- Перед завершением запускать `dotnet build` и `dotnet test`.

## SHOULD

- Проверять в тестах валидацию, авторизацию и маппинг ошибок в HTTP-ответы.
- Для нестабильных внешних зависимостей тестировать timeout/retry/idempotency сценарии.

## MAY

- Добавлять contract tests для критичных внешних интеграций.

## Команды

```powershell
dotnet build
dotnet test
dotnet test <path-to-tests.csproj> --filter <TestName>
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/contexts/testing-dotnet.md](../contexts/testing-dotnet.md)
- [instructions/contexts/performance-optimization.md](../contexts/performance-optimization.md)
- [instructions/profiles/dotnet-ravendb.md](./dotnet-ravendb.md)
