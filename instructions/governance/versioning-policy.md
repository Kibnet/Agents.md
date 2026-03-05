# Governance: Versioning Policy

## Когда применять

- Для любого изменения канонических инструкций в этом репозитории.
- Для подготовки релиза набора правил.

## Когда не применять

- Для локальных черновиков, которые не входят в основной каталог.

## MUST

- Вести `CHANGELOG.md` для всех значимых изменений.
- Использовать SemVer (`MAJOR.MINOR.PATCH`) для версий каталога.
- Любые изменения каталога проводить через Quest SPEC gate.
- Для breaking changes увеличивать `MAJOR`.

## SHOULD

- Отражать причину версии и влияние на потребителей в changelog.
- Группировать изменения по блокам: `Added`, `Changed`, `Removed`.

## MAY

- Добавлять ссылку на diff/ревизию при публикации версии.

## Команды

```powershell
# Проверка перед фиксацией версии
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1

# Просмотр изменений
git status --short
git diff --stat
```

## Семантика версий

- `MAJOR`: breaking изменения структуры, контрактов или приоритетов применения.
- `MINOR`: новые документы/правила без нарушения существующих контрактов.
- `PATCH`: исправления формулировок, ссылок, опечаток и мелкие улучшения.

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [CHANGELOG.md](../../CHANGELOG.md)
- [instructions/core/quest-governance.md](../core/quest-governance.md)
- [instructions/governance/commit-message-policy.md](./commit-message-policy.md)
