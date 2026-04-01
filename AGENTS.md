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

1. Для applicability и quality gate `QUEST` использовать [instructions/core/quest-governance.md](instructions/core/quest-governance.md).
2. Для фазового поведения `QUEST`, включая допустимые мутации файлов на `SPEC` и `EXEC`, использовать [instructions/core/quest-mode.md](instructions/core/quest-mode.md).
3. Локальный `AGENTS.override.md` в репозитории-потребителе может только ужесточать центральные MUST.

## Routing

Каноническая матрица маршрутизации и алгоритм выбора документов:

- [instructions/governance/routing-matrix.md](instructions/governance/routing-matrix.md)

Короткий порядок работы:

1. Прочитать `AGENTS.md` как entry point.
2. Открыть `instructions/governance/routing-matrix.md` и выбрать сценарий.
3. Собрать instruction stack и разрешать конфликты только по алгоритму матрицы.

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
