# Profile: Frontend SPA TypeScript

## Когда применять

- Разработка SPA на `React`/`Vue`/`Angular` с TypeScript.
- Изменения в компонентах, роутинге, клиентской валидации и state management.

## Когда не применять

- Для .NET-only и Python-only проектов.
- Для desktop-клиентов, где UI не вебовый.

## MUST

- Любые изменения поведения покрывать автотестами (unit/integration).
- При изменениях пользовательского потока обновлять e2e сценарии.
- Перед завершением запускать build и полный тестовый прогон проекта.
- Не завершать задачу с падающим lint/type-check.

## SHOULD

- Поддерживать проектный порог покрытия тестами.
- Использовать стабильные `data-testid`/automation селекторы вместо хрупких CSS-цепочек.

## MAY

- Использовать `npm` или `pnpm` согласно стандарту конкретного репозитория.

## Команды

```powershell
npm run test:run
npm run coverage
npm run build
npm run test:e2e:with-dev
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/contexts/testing-frontend.md](../contexts/testing-frontend.md)
- [instructions/profiles/ui-automation-testing.md](./ui-automation-testing.md)
