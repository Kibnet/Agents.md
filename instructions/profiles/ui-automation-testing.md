# Profile: UI Automation Testing

## Когда применять

- Изменения затрагивают UI behavior, visual user flows или UI-facing state changes, и в репозитории уже есть релевантный UI test suite (`Playwright`, `AppAutomation Headless`, `FlaUI`, `Avalonia.Headless`, Selenium и аналогичные инструменты).
- Нужно сопровождать end-to-end/smoke/regression UI сценарии в уже принятых repository patterns.

## Когда не применять

- Для backend-задач без UI-контракта.
- Для изменений, не влияющих на пользовательские потоки и селекторы.
- Если в репозитории нет действующего UI test suite и задача не включает его создание отдельным согласованным решением.

## MUST

- При багфиксе или новой фиче, затрагивающих UI behavior, visual user flows или UI-facing state changes, использовать UI tests, если в репозитории уже есть релевантный UI suite.
- Добавлять или обновлять релевантное UI test coverage как часть изменения. Предпочитать существующие `AppAutomation Headless`/`FlaUI`, `Avalonia.Headless` или другие принятые в репозитории UI test patterns.
- Использовать стабильные селекторы (`data-testid`, `automation-id`), а не текстовые/позиционные привязки.
- Перед завершением запускать релевантные UI тесты или явно сообщать, почему их не удалось запустить.
- Падающие UI автотесты блокируют завершение задачи.

## SHOULD

- На падениях сохранять диагностические артефакты (лог, screenshot, trace/video при наличии).
- Держать UI тесты на уровне пользовательских сценариев, а не внутренних деталей реализации.

## MAY

- Разделять UI suite на `smoke` и `full` для ускорения локальной обратной связи.

## Команды

```powershell
# Frontend e2e
npm run test:e2e:with-dev

# .NET UI tests (VSTest-compatible)
dotnet test <path-to-ui-tests.csproj>
dotnet test <path-to-ui-tests.csproj> --filter "FullyQualifiedName~UITests"

# TUnit UI tests
dotnet run --project <path-to-ui-tests.csproj> -- --treenode-filter "/*/*/Ui*/*"
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/contexts/testing-dotnet.md](../contexts/testing-dotnet.md)
- [instructions/contexts/testing-frontend.md](../contexts/testing-frontend.md)
- [instructions/profiles/dotnet-desktop-client.md](./dotnet-desktop-client.md)
- [instructions/profiles/frontend-spa-typescript.md](./frontend-spa-typescript.md)
