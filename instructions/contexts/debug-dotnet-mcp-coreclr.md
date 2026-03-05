# Context: Debug .NET + MCP + CoreCLR

## Когда применять

- Нужно запустить/вести runtime- или test-debug в .NET через VS Code CoreCLR и MCP debug server.
- Нужно работать со stack trace, переменными, breakpoint и пошаговым выполнением.
- Нужно диагностировать проблемы debug-сессии.

## Когда не применять

- Для задач без debug-сессии (обычные правки кода, рефакторинг, документация).
- Для чистого запуска тестов/сборки без отладчика.

## MUST

- Перед сессией проверить health MCP endpoint и корректность launch config.
- Перед началом новой сессии закрыть stale session (`debug_stop`) и проверить breakpoints.
- Запускать отладку через `debug_startWithConfig` по явному имени конфигурации.
- Для test-debug выбирать один тест через UID и один reusable launch profile.
- По завершении чистить временные breakpoints и останавливать сессию.

## SHOULD

- Предпочитать стратегию `continue + breakpoints`, а не line-by-line stepping.
- Использовать условные breakpoints в горячих циклах.
- После шага/continue проверять актуальный stack/frame перед интерпретацией состояния.

## MAY

- При сбое MCP использовать прямой JSON-RPC вызов к `<MCP_BASE_URL>/mcp`.
- Включать стабилизирующие настройки VS Code для CoreCLR при нестабильных сессиях.

## Команды

```powershell
# Pre-flight
Invoke-WebRequest <MCP_BASE_URL>/health -UseBasicParsing

# Сценарий test UID discovery
dotnet test --project <tests.csproj> --list-tests
& "<path-to-tests.exe>" --list-tests --diagnostic --diagnostic-output-directory <tmp-dir> --disable-logo --no-progress
rg -n "DisplayName = <Exact test display name>" <tmp-dir>\*.diag -S

# MCP operations (через tools)
debug_listConfigs
debug_startWithConfig
debug_getStatus
debug_getStackTrace
debug_getVariables
debug_evaluate
debug_continue
debug_stepOver
debug_stepInto
debug_stepOut
debug_pause
debug_stop
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/contexts/testing-dotnet.md](./testing-dotnet.md)
- [instructions/governance/routing-matrix.md](../governance/routing-matrix.md)
