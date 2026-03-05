# Governance: Document Contract

## Когда применять

- При добавлении, изменении или ревью любого документа в `instructions/*`.
- При проверке соответствия каталога формальным требованиям.

## Когда не применять

- Для изменений вне каталога инструкций, где этот контракт не используется.

## MUST

- Каждый документ в `instructions/*` обязан содержать секции:
  - `## Когда применять`
  - `## Когда не применять`
  - `## MUST`
  - `## SHOULD`
  - `## MAY`
  - `## Связанные документы`
- Секция `## Команды` обязательна, если документ содержит операционные шаги/workflow.
- Язык контента: русский.
- Имена файлов и папок: английский, в основном `kebab-case`.
- Изменения структуры должны проходить validator и тесты validator.

## SHOULD

- Использовать краткие заголовки, без дублирования терминов между секциями.
- Поддерживать ссылки относительными путями внутри репозитория.

## MAY

- Использовать исключения нейминга для стабильных публичных шаблонов подключения.
- Использовать placeholder `<AGENTS_ROOT>` в onboarding-шаблонах вместо жестко прошитого абсолютного пути.

## Команды

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
```

## Именные исключения

Допустимы следующие исключения от `kebab-case` для совместимого контракта онбординга:

- `instructions/onboarding/AGENTS.consumer.template.md`
- `instructions/onboarding/AGENTS.override.template.md`

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/governance/routing-matrix.md](./routing-matrix.md)
- [instructions/onboarding/quick-start.md](../onboarding/quick-start.md)
