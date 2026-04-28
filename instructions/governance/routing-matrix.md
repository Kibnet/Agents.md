# Governance: Routing Matrix

## Когда применять

- Нужно определить, какие документы использовать для конкретной задачи.
- Нужно разрешить конфликт или пересечение между несколькими наборами правил.

## Когда не применять

- Когда уже выбран точный набор документов и задача выполняется строго внутри него.

## MUST

- Начинать с `AGENTS.md` как единой точки маршрутизации.
- Использовать этот документ как канонический source of truth для:
  - порядка сборки central instruction stack;
  - модели разрешения конфликтов между документами.
- Для каждой задачи подключать `instructions/core/model-behavior-baseline.md` как обязательный core baseline поведения целевой модели `gpt-5.5`.
- Для каждой задачи фиксировать минимум один core-документ и при необходимости один context + один profile.
- Использовать не более двух profile-документов одновременно:
  - один профиль стека приложения;
  - один профиль типа изменений (если нужен).
- Для аналитических задач без выраженного технологического стека допускается использовать один профиль сценария без `stack profile`, если результатом являются process artifacts, а не код.
- Summary-документы (`AGENTS.md`, `README.md`) считать только точками входа и обзором; они не вводят отдельную conflict model поверх owner-документов.
- Локальный `AGENTS.override.md` в репозитории-потребителе применять только после central stack как дополнительные локальные инструкции поверх него; он не заменяет central stack и может только ужесточать MUST.

## SHOULD

- Выбирать минимальный достаточный набор документов без дублирования.
- При неоднозначности сначала проверять `document-contract.md`, затем профиль приложения/технологии.
- Фиксировать выбранный набор документов в спецификации (`specs`) перед реализацией, если задача проходит через `SPEC gate`.

## MAY

- Использовать таблицу ниже как чеклист перед началом реализации.

## Команды

```powershell
# Быстрая навигация по категориям
Get-ChildItem instructions/core
Get-ChildItem instructions/contexts
Get-ChildItem instructions/profiles
```

## Stack Assembly Order

1. Классифицировать задачу:
   - `catalog-governance`, `consumer-onboarding`, `delivery-task`, `guided-artifact-workflow`.
2. Подключить `model-behavior-baseline` и базовый набор (`core`) по типу задачи.
3. Выбрать один `context` по типу выполнения.
4. Выбрать один профиль технологического стека (`stack profile`), если задача привязана к реализации в конкретном стеке.
5. При необходимости добавить один профиль типа изменения (`overlay profile`) или использовать один профиль сценария для аналитической задачи без стековой привязки.
6. Добавить governance overlays по триггерам задачи.
7. Если задача выполняется в consumer-репозитории и есть локальный `AGENTS.override.md`, применить его после central stack как дополнительные локальные инструкции поверх него и использовать только для ужесточения central `MUST`.

## Conflict Resolution Model

1. Если один `MUST` строже другого, приоритет у более строгого `MUST`.
2. Если строгость сопоставима, приоритет у более специфичного документа для текущего artifact, workflow или технологического стека.
3. Для маршрутизации, состава stack и governance overlays owner-документом является этот `routing-matrix.md`.
4. Для фазового поведения `QUEST`, включая допустимые мутации файлов на `SPEC` и `EXEC`, owner-документом является `instructions/core/quest-mode.md`.
5. Для обязательности `QUEST` и quality gate owner-документом является `instructions/core/quest-governance.md`.
6. Для структуры документов `instructions/*` owner-документом является `instructions/governance/document-contract.md`.
7. Для полезных комментариев и cleanup комментариев owner-документом является `instructions/governance/commenting-policy.md`.
8. Для общего процесса рефакторинга owner-документом является `instructions/governance/refactoring-policy.md`.
9. Для model/prompt behavior, outcome-first формулировок, verbosity/reasoning guidance и stop rules owner-документом является `instructions/core/model-behavior-baseline.md`.
10. Локальный `AGENTS.override.md` не заменяет central stack, может только ужесточать центральные правила и не может ослаблять центральный `MUST`.

## Базовый набор по типу задачи

| Тип задачи | Обязательные документы |
|---|---|
| `catalog-governance` | `model-behavior-baseline`, `quest-governance`, `collaboration-baseline` |
| `consumer-onboarding` | `model-behavior-baseline`, `collaboration-baseline` |
| `delivery-task` | `model-behavior-baseline`, `quest-governance`, `collaboration-baseline`; + `testing-baseline` при изменении поведения |
| `guided-artifact-workflow` | `model-behavior-baseline`, `collaboration-baseline` |

## Выбор context по типу выполнения

| Условие | Context |
|---|---|
| .NET тестирование/валидация | `testing-dotnet` |
| Frontend тестирование/валидация | `testing-frontend` |
| .NET runtime/test debug, exception capture, live inspection | `debug-dotnet-mcp-coreclr` |
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
| UI behavior / automation / e2e (если в репозитории есть UI test suite) | `ui-automation-testing` |
| UI feature parity | `ui-feature-parity` |
| Rendering / preview pipeline | `rendering-pipeline` |
| Проектирование подсистемы | `product-system-design` |
| Анализ и автоматизация бизнес-процесса | `business-process-automation` |
| Вынос доменной логики | `domain-logic-extraction` |
| Локальный структурный рефакторинг | `refactor-local` |
| Архитектурный рефакторинг | `refactor-architecture` |
| Механический рефакторинг | `refactor-mechanical` |

## Governance overlays по триггерам

| Триггер | Governance |
|---|---|
| Изменение правил/структуры `instructions/*` | `document-contract`, `versioning-policy` |
| Любой рефакторинг кода | `refactoring-policy` |
| Целенаправленное массовое комментирование / cleanup комментариев | `commenting-policy` |
| QUEST: фаза SPEC | `quest-mode`, `spec-linter`, `spec-rubric`, `review-loops` |
| QUEST: фаза EXEC | `quest-mode`, `review-loops` |
| Коммиты и changelog | `commit-message-policy`, `versioning-policy` |
| Подключение каталога в потребительский репозиторий | `onboarding/quick-start`, `onboarding/AGENTS.consumer.template`, `onboarding/AGENTS.override.template` |

## Быстрые примеры маршрутов

Во всех примерах ниже `model-behavior-baseline` подключается как обязательный core baseline и не повторяется в строках для краткости.

| Ситуация | Минимальный стек |
|---|---|
| .NET backend фича | `quest-governance + collaboration-baseline + testing-baseline + testing-dotnet + dotnet-backend-api` |
| Frontend багфикс UI flow при существующих e2e | `quest-governance + collaboration-baseline + testing-baseline + testing-frontend + frontend-spa-typescript + ui-automation-testing` |
| .NET desktop багфикс UI flow при существующих headless/UI tests | `quest-governance + collaboration-baseline + testing-baseline + testing-dotnet + dotnet-desktop-client + ui-automation-testing` |
| RavenDB изменение индекса | `quest-governance + collaboration-baseline + testing-baseline + testing-dotnet + dotnet-ravendb` |
| UI parity между desktop и web | `quest-governance + collaboration-baseline + testing-baseline + (testing-dotnet/testing-frontend) + stack profile + ui-feature-parity` |
| Производительность render-пайплайна | `quest-governance + collaboration-baseline + testing-baseline + performance-optimization + stack profile + rendering-pipeline` |
| Проектирование автоматизации бизнес-процесса | `quest-governance + collaboration-baseline + business-process-automation` |
| Проведение интервью / AS-IS / TO-BE / skill graph по шагам | `collaboration-baseline + business-process-automation` |
| Локальный рефакторинг модуля | `quest-governance + collaboration-baseline + stack profile + refactor-local + refactoring-policy` |
| Массовое улучшение комментариев в hotspot-участках | `quest-governance + collaboration-baseline + stack profile + commenting-policy` |

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/core/model-behavior-baseline.md](../core/model-behavior-baseline.md)
- [instructions/governance/commenting-policy.md](./commenting-policy.md)
- [instructions/governance/document-contract.md](./document-contract.md)
- [instructions/governance/refactoring-policy.md](./refactoring-policy.md)
- [instructions/governance/versioning-policy.md](./versioning-policy.md)
- [instructions/core/quest-mode.md](../core/quest-mode.md)
- [instructions/core/quest-governance.md](../core/quest-governance.md)
- [instructions/governance/review-loops.md](./review-loops.md)
- [instructions/profiles/business-process-automation.md](../profiles/business-process-automation.md)
- [instructions/profiles/refactor-local.md](../profiles/refactor-local.md)
