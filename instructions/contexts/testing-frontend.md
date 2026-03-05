# Context: Testing Frontend

## Когда применять

- Проект на TypeScript/JavaScript (React/Vue/Angular/Vite и т.п.).
- Есть unit/integration/e2e тесты на Vitest/Jest/Playwright.

## Когда не применять

- Для .NET-only и Python-only проектов.
- Когда профиль приложения/технологии требует другой специализированный test workflow.

## MUST

- Любые изменения поведения покрывать автотестами.
- При багфиксе сначала добавить падающий тест, затем внести фикс.
- Перед завершением выполнять полный тестовый прогон проекта.
- Если изменение влияет на UI flow, добавлять/обновлять e2e-проверки.

## SHOULD

- Держать минимум 80% покрытия там, где проект это требует.
- Запускать сначала targeted тесты, затем полный run.
- Фиксировать команды и результаты в отчете.

## MAY

- Использовать watch/UI режимы тест-раннера на этапе локальной разработки.
- Делать smoke e2e перед full e2e, если pipeline тяжелый.

## Команды

```powershell
npm test
npm run test:run
npm run coverage
npm run build
npm run test:e2e:with-dev

# Точечный запуск
npm test -- <test-file>
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/core/testing-baseline.md](../core/testing-baseline.md)
- [instructions/profiles/frontend-spa-typescript.md](../profiles/frontend-spa-typescript.md)
- [instructions/profiles/ui-automation-testing.md](../profiles/ui-automation-testing.md)
