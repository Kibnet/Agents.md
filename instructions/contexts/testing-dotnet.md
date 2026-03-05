# Context: Testing .NET

## Когда применять

- Проект использует .NET (C#, xUnit/NUnit/MSTest).
- Нужно валидировать изменения в backend, library или desktop/.NET приложении.

## Когда не применять

- Для frontend-only репозиториев на Node/Vite/Vitest.
- Для Python-проектов без .NET toolchain.

## MUST

- Перед завершением изменений запускать полный набор тестов решения.
- При багфиксе добавлять reproducing test до правки.
- После изменений запускать минимум `dotnet build` и `dotnet test`.
- Если в проекте принят форматтер, запускать его до финальной сдачи.

## SHOULD

- Локально сначала выполнять targeted tests, затем full-run.
- Покрывать ветвления, граничные значения и невалидные входы.
- Для крупных изменений сохранять список ключевых проверок в отчете.

## MAY

- Запускать конкретный тестовый проект отдельно до полного прогона.
- Использовать `--filter` для ускорения итерации отладки.

## Команды

```powershell
dotnet format
dotnet build
dotnet test

# Точечный запуск
dotnet test <path-to-tests.csproj>
dotnet test <path-to-tests.csproj> --filter <TestName>
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/core/testing-baseline.md](../core/testing-baseline.md)
- [instructions/contexts/debug-dotnet-mcp-coreclr.md](./debug-dotnet-mcp-coreclr.md)
- [instructions/profiles/dotnet-backend-api.md](../profiles/dotnet-backend-api.md)
- [instructions/profiles/dotnet-desktop-client.md](../profiles/dotnet-desktop-client.md)
- [instructions/profiles/dotnet-ravendb.md](../profiles/dotnet-ravendb.md)
