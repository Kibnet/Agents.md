# Единый каталог агентских инструкций

Этот репозиторий является единым `source of truth` для агентских инструкций в инфраструктуре с несколькими репозиториями.

## Область применения

- Поддержка единых правил для работы агента в разных репозиториях.
- Маршрутизация по ситуациям: базовые правила, контекст выполнения, проектный профиль.
- Подключение внешних репозиториев без копирования больших наборов инструкций.

## Порядок приоритета правил

При конфликте применяется следующий порядок:

1. Более строгий `MUST` имеет приоритет.
2. [instructions/core/quest-governance.md](instructions/core/quest-governance.md)
3. `instructions/core/*`
4. `instructions/contexts/*`
5. `instructions/profiles/*`
6. Локальный `AGENTS.override.md` в репозитории-потребителе (только ужесточение, без ослабления MUST).

## Routing

Каноническая матрица маршрутизации и алгоритм выбора документов:

- [instructions/governance/routing-matrix.md](instructions/governance/routing-matrix.md)

Короткий порядок работы:

1. Прочитать `AGENTS.md` и определить приоритет правил.
2. Открыть `instructions/governance/routing-matrix.md` и выбрать сценарий.
3. Подключить `core -> context -> profile -> governance` по алгоритму матрицы.

## Подключение в другой репозиторий

Использовать quick start:

- [instructions/onboarding/quick-start.md](instructions/onboarding/quick-start.md)
- [instructions/onboarding/AGENTS.consumer.template.md](instructions/onboarding/AGENTS.consumer.template.md)
- [instructions/onboarding/AGENTS.override.template.md](instructions/onboarding/AGENTS.override.template.md)

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
