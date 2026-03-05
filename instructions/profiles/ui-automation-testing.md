# Profile: UI Automation Testing

## Когда применять

- Изменения затрагивают автоматизацию UI (`Playwright`, `Avalonia.Headless`, Selenium и аналогичные инструменты).
- Нужно сопровождать end-to-end/smoke/regression UI сценарии.

## Когда не применять

- Для backend-задач без UI-контракта.
- Для изменений, не влияющих на пользовательские потоки и селекторы.

## MUST

- При изменениях UI-контракта обновлять автотесты и test selectors.
- Использовать стабильные селекторы (`data-testid`, `automation-id`), а не текстовые/позиционные привязки.
- Перед завершением запускать минимум smoke-suite UI тестов.
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

# .NET UI tests
dotnet test --filter "FullyQualifiedName~UITests"
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/contexts/testing-dotnet.md](../contexts/testing-dotnet.md)
- [instructions/contexts/testing-frontend.md](../contexts/testing-frontend.md)
- [instructions/profiles/dotnet-desktop-client.md](./dotnet-desktop-client.md)
- [instructions/profiles/frontend-spa-typescript.md](./frontend-spa-typescript.md)
