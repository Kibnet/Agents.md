# Единый каталог агентских инструкций

Этот репозиторий является единым `source of truth` для агентских инструкций в инфраструктуре с несколькими репозиториями.

## Область применения

- Поддержка единых правил для работы агента в разных репозиториях.
- Маршрутизация по ситуациям: базовые правила, контекст выполнения, проектный профиль.
- Подключение внешних репозиториев без копирования больших наборов инструкций.

## Канонические Owner-Документы

Точную модель выбора документов и разрешения конфликтов определяет:

- [instructions/governance/routing-matrix.md](instructions/governance/routing-matrix.md)

Дополнительно:

1. Для optimization baseline семейства `GPT-5.6`, outcome-first формулировок, surface-aware model guidance и stop rules использовать [instructions/core/model-behavior-baseline.md](instructions/core/model-behavior-baseline.md). Это целевой behavior contract, а не гарантия доступности модели в текущей поверхности/runtime.
2. Для обязательного preflight и обработки повторяемых path, PowerShell, patch, Git, timeout и environment failures в `tool-heavy` задачах использовать [instructions/core/tool-execution-baseline.md](instructions/core/tool-execution-baseline.md).
3. Для applicability и quality gate `QUEST` использовать [instructions/core/quest-governance.md](instructions/core/quest-governance.md).
4. Для фазового поведения `QUEST`, включая допустимые мутации файлов на `SPEC` и `EXEC`, использовать [instructions/core/quest-mode.md](instructions/core/quest-mode.md).
5. Локальный `AGENTS.override.md` в репозитории-потребителе применять только после central stack как дополнительные локальные инструкции поверх него; он не заменяет центральный `AGENTS.md` и может только ужесточать центральные MUST.
6. Для STORM product workflow, BDD/Gherkin behavior layer и команд `/storm:*` использовать [instructions/profiles/storm-product-development.md](instructions/profiles/storm-product-development.md).
7. Для OpenAI Responses API, exact model/tier routing, persisted reasoning, Programmatic Tool Calling и Responses multi-agent использовать [instructions/governance/openai-responses-api.md](instructions/governance/openai-responses-api.md) только по соответствующему триггеру.

## Routing

Каноническая матрица маршрутизации и алгоритм выбора документов:

- [instructions/governance/routing-matrix.md](instructions/governance/routing-matrix.md)

Короткий порядок работы:

1. Прочитать `AGENTS.md` как entry point.
2. Открыть `instructions/governance/routing-matrix.md` и выбрать сценарий.
3. Собрать instruction stack, включая `model-behavior-baseline` и, для `tool-heavy` задач, `tool-execution-baseline`; зафиксировать фактическую surface/runtime конфигурацию, если она влияет на результат, и разрешать конфликты только по алгоритму матрицы.
4. Если в consumer-репозитории есть `AGENTS.override.md`, применить его после central stack как дополнительные локальные инструкции поверх него.
5. Если пользователь вызывает `/storm:*`, подключить профиль `storm-product-development`; команды с изменениями tests/code/behavior должны идти через обычный `delivery-task` и `QUEST`, включая `/storm:bdd-implement`.

## Подключение в другой репозиторий

Использовать quick start:

- [instructions/onboarding/quick-start.md](instructions/onboarding/quick-start.md)
- [instructions/onboarding/AGENTS.consumer.template.md](instructions/onboarding/AGENTS.consumer.template.md)
- [instructions/onboarding/AGENTS.override.template.md](instructions/onboarding/AGENTS.override.template.md)
- [instructions/profiles/storm-product-development.md](instructions/profiles/storm-product-development.md)

## Quality Gate каталога

Перед завершением изменений запускай:

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
```

## Документы управления

- [instructions/governance/document-contract.md](instructions/governance/document-contract.md)
- [instructions/governance/versioning-policy.md](instructions/governance/versioning-policy.md)
- [CHANGELOG.md](CHANGELOG.md)
