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
- При планировании UI behavior, visual user flows или UI-facing state changes фиксировать visual planning artifact и связывать его с e2e/smoke acceptance сценариями.
- Добавлять или обновлять релевантное UI test coverage как часть изменения. Предпочитать существующие `AppAutomation Headless`/`FlaUI`, `Avalonia.Headless` или другие принятые в репозитории UI test patterns.
- Для UI-facing фич и багфиксов записывать video evidence из автоматизированного UI test run, если в репозитории есть релевантный UI suite и test runner, harness или CI умеет сохранять безопасное видео.
- Для UI-facing багфикса сохранять `до` failing/repro video, демонстрирующее исходный дефект, и `после` passing video, подтверждающее исправление. Characterization video вместо failing/repro допустимо только если дефект нельзя надежно выразить deterministic failing assertion; тогда видео должно визуально демонстрировать дефект, а отчет обязан фиксировать причину выбора characterization.
- Для UI-facing новой фичи сохранять `после` passing video, подтверждающее новый flow/state. `До` baseline video нужно сохранять только когда до реализации существовал meaningful flow; если flow отсутствовал, явно указать `Не применимо` с причиной.
- Fallback вместо video evidence допустим только по объективной причине: UI suite отсутствует, recorder не поддерживается test runner/harness/CI, запись окна или headless-сессии технически невозможна, безопасная запись невозможна из-за чувствительных данных, либо CI/artifact policy запрещает сохранять видео. В fallback указывать причину, команду проверки и next-best evidence (`trace`, screenshots, logs).
- Использовать стабильные селекторы (`data-testid`, `automation-id`), а не текстовые/позиционные привязки.
- Перед завершением запускать релевантные UI тесты или явно сообщать, почему их не удалось запустить.
- Падающие UI автотесты блокируют завершение задачи.

## SHOULD

- На падениях сохранять диагностические артефакты (лог, screenshot, trace/video при наличии).
- Использовать visual planning artifact как ориентир для screenshots/traces/video и для описания expected user-visible states.
- Указывать для UI video evidence команду запуска и repo-relative path, CI artifact URL, PR attachment/link или `local-only` path с явной пометкой ограничения доступности.
- Не коммитить крупные бинарные video artifacts по умолчанию, если в репозитории нет принятой практики хранить такие файлы.
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
