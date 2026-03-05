# Governance: Routing Matrix

## Когда применять

- Нужно определить, какие документы использовать для конкретной задачи.
- Нужно разрешить конфликт или пересечение между несколькими наборами правил.

## Когда не применять

- Когда уже выбран точный набор документов и задача выполняется строго внутри него.

## MUST

- Начинать с `AGENTS.md` как единой точки маршрутизации.
- Применять приоритет: строгий MUST -> core -> contexts -> profiles -> local override.
- Для каждой задачи фиксировать минимум один core-документ и при необходимости один context + один profile.
- Собирать instruction stack в фиксированном порядке:
  - `base core` -> `task context` -> `stack profile` -> `change profile` (опционально) -> `governance`.
- Использовать не более двух profile-документов одновременно:
  - один профиль стека приложения;
  - один профиль типа изменений (если нужен).
- При конфликте между profile-документами приоритет у более специфичного MUST для текущей задачи.

## SHOULD

- Выбирать минимальный достаточный набор документов без дублирования.
- При неоднозначности сначала проверять `document-contract.md`, затем профиль приложения/технологии.
- Фиксировать выбранный набор документов в спецификации (`specs`) перед реализацией.

## MAY

- Использовать таблицу ниже как чеклист перед началом реализации.

## Команды

```powershell
# Быстрая навигация по категориям
Get-ChildItem instructions/core
Get-ChildItem instructions/contexts
Get-ChildItem instructions/profiles
```

## Алгоритм выбора документов

1. Классифицировать задачу:
   - `catalog-governance`, `consumer-onboarding`, `delivery-task`.
2. Подключить базовый набор (`core`) по типу задачи.
3. Выбрать один `context` по типу выполнения.
4. Выбрать один профиль технологического стека (`stack profile`).
5. При необходимости добавить один профиль типа изменения (`overlay profile`).
6. Добавить governance overlays по триггерам задачи.

## Базовый набор по типу задачи

| Тип задачи | Обязательные документы |
|---|---|
| `catalog-governance` | `quest-governance`, `collaboration-baseline` |
| `consumer-onboarding` | `collaboration-baseline` |
| `delivery-task` | `quest-governance`, `collaboration-baseline`; + `testing-baseline` при изменении поведения |

## Выбор context по типу выполнения

| Условие | Context |
|---|---|
| .NET тестирование/валидация | `testing-dotnet` |
| Frontend тестирование/валидация | `testing-frontend` |
| .NET runtime/test debug | `debug-dotnet-mcp-coreclr` |
| Оптимизация производительности | `performance-optimization` |
| Визуальная обратная связь (скриншот/видео окна) | `visual-feedback` |

## Выбор stack profile по стеку

| Стек | Profile |
|---|---|
| .NET backend/API | `dotnet-backend-api` |
| .NET desktop (Avalonia/WPF/WinUI) | `dotnet-desktop-client` |
| .NET + RavenDB | `dotnet-ravendb` |
| Frontend SPA TypeScript | `frontend-spa-typescript` |
| Python hardware/GPIO | `python-hardware-gpio` |

## Overlay profile по типу изменения

| Тип изменения | Overlay profile |
|---|---|
| UI automation / e2e | `ui-automation-testing` |
| UI feature parity | `ui-feature-parity` |
| Rendering / preview pipeline | `rendering-pipeline` |
| Проектирование подсистемы | `product-system-design` |
| Вынос доменной логики | `domain-logic-extraction` |
| Архитектурный рефакторинг | `refactor-architecture` |
| Механический рефакторинг | `refactor-mechanical` |

## Governance overlays по триггерам

| Триггер | Governance |
|---|---|
| Изменение правил/структуры `instructions/*` | `document-contract`, `versioning-policy` |
| QUEST: фаза SPEC | `quest-mode`, `spec-linter`, `spec-rubric` |
| Коммиты и changelog | `commit-message-policy`, `versioning-policy` |
| Подключение каталога в потребительский репозиторий | `onboarding/quick-start`, `onboarding/AGENTS.consumer.template`, `onboarding/AGENTS.override.template` |

## Быстрые примеры маршрутов

| Ситуация | Минимальный стек |
|---|---|
| .NET backend фича | `quest-governance + collaboration-baseline + testing-baseline + testing-dotnet + dotnet-backend-api` |
| Frontend багфикс UI flow | `quest-governance + collaboration-baseline + testing-baseline + testing-frontend + frontend-spa-typescript + ui-automation-testing` |
| RavenDB изменение индекса | `quest-governance + collaboration-baseline + testing-baseline + testing-dotnet + dotnet-ravendb` |
| UI parity между desktop и web | `quest-governance + collaboration-baseline + testing-baseline + (testing-dotnet/testing-frontend) + stack profile + ui-feature-parity` |
| Производительность render-пайплайна | `quest-governance + collaboration-baseline + testing-baseline + performance-optimization + stack profile + rendering-pipeline` |

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/governance/document-contract.md](./document-contract.md)
- [instructions/governance/versioning-policy.md](./versioning-policy.md)
- [instructions/core/quest-mode.md](../core/quest-mode.md)
- [instructions/core/quest-governance.md](../core/quest-governance.md)
