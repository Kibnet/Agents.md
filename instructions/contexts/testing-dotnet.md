# Context: Testing .NET

## Когда применять

- Проект использует .NET (C#, xUnit/NUnit/MSTest/TUnit).
- Нужно валидировать изменения в backend, library или desktop/.NET приложении.

## Когда не применять

- Для frontend-only репозиториев на Node/Vite/Vitest.
- Для Python-проектов без .NET toolchain.

## MUST

- Перед завершением изменений запускать полный набор тестов решения.
- При багфиксе добавлять reproducing test до правки.
- После изменений запускать минимум `dotnet build` и полный тестовый прогон с тем runner workflow, который принят в проекте.
- Перед выбором команд определять, использует ли проект VSTest-совместимый runner или `TUnit`/`Microsoft.Testing.Platform`.
- Для `TUnit` не использовать VSTest-синтаксис `--filter`; для targeted runs и discovery использовать `--treenode-filter` и `--list-tests`.
- Если в проекте принят форматтер, запускать его до финальной сдачи.

## SHOULD

- Локально сначала выполнять targeted tests, затем full-run.
- Для `TUnit` предпочитать `dotnet run` из каталога тестового проекта; `dotnet test -- ...` использовать, если этого требует локальный workflow или CI.
- Покрывать ветвления, граничные значения и невалидные входы.
- Для крупных изменений сохранять список ключевых проверок в отчете.

## MAY

- Запускать конкретный тестовый проект отдельно до полного прогона.
- Использовать `--filter` для ускорения итерации только в VSTest-совместимых проектах.
- Для `TUnit` использовать `--help`, `--info` и `--list-tests`, чтобы быстро проверить доступные MTP-опции.

## Команды

```powershell
dotnet format
dotnet build

# VSTest-compatible (xUnit / NUnit / MSTest)
dotnet test
dotnet test <path-to-tests.csproj>
dotnet test <path-to-tests.csproj> --filter <TestName>

# TUnit / Microsoft.Testing.Platform
# Tree node path: /<Assembly>/<Namespace>/<Class>/<Test>
dotnet run --project <path-to-tests.csproj>
dotnet run --project <path-to-tests.csproj> -- --list-tests
dotnet run --project <path-to-tests.csproj> -- --treenode-filter "/*/*/MyTestClass/*"
dotnet run --project <path-to-tests.csproj> -- --treenode-filter "/*/*/MyTestClass/MyTestMethod"

# TUnit via dotnet test (если нужен именно dotnet test)
dotnet test <path-to-tests.csproj> -- --list-tests
dotnet test <path-to-tests.csproj> -- --treenode-filter "/*/*/MyTestClass/*"
dotnet test <path-to-tests.csproj> -- --treenode-filter "/*/*/MyTestClass/MyTestMethod"
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/core/testing-baseline.md](../core/testing-baseline.md)
- [instructions/contexts/debug-dotnet-mcp-coreclr.md](./debug-dotnet-mcp-coreclr.md)
- [instructions/profiles/dotnet-backend-api.md](../profiles/dotnet-backend-api.md)
- [instructions/profiles/dotnet-desktop-client.md](../profiles/dotnet-desktop-client.md)
- [instructions/profiles/dotnet-ravendb.md](../profiles/dotnet-ravendb.md)
