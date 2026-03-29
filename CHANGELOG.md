# Changelog

All notable changes to this instruction catalog are documented in this file.

## [1.1.1] - 2026-03-29

### Changed

- Уточнен [quest-governance.md](instructions/core/quest-governance.md):
  - `SPEC gate` больше не применяется к исполнению существующего guided workflow с пользовательскими артефактами, если агент не меняет код, инфраструктуру и канонические файлы проекта.
- Обновлена [routing-matrix.md](instructions/governance/routing-matrix.md):
  - добавлен тип задачи `guided-artifact-workflow`;
  - для guided workflow базовым стеком стал `collaboration-baseline` без `quest-governance`.
- Уточнен [business-process-automation.md](instructions/profiles/business-process-automation.md):
  - выполнение workflow теперь явно идет без spec;
  - пошаговые артефакты должны отдаваться отдельными файлами и ждать подтверждения пользователя.

## [1.1.0] - 2026-03-29

### Added

- Добавлен новый профиль [business-process-automation](instructions/profiles/business-process-automation.md) для задач анализа и проектирования автоматизации бизнес-процессов.
- Добавлен каталог prompt templates `prompts/business-process-automation/` для канонической цепочки:
  - интервью с экспертом;
  - моделирование `AS-IS`;
  - анализ точек автоматизации;
  - проектирование `TO-BE`;
  - построение skill graph ИИ-агента.

### Changed

- Обновлена [routing-matrix.md](instructions/governance/routing-matrix.md):
  - добавлен маршрут `business-process-automation`;
  - разрешен сценарный профиль без `stack profile` для аналитических задач без технологической привязки.
- Обновлен `scripts/validate-instructions.ps1`:
  - новые профиль и prompt templates включены в обязательный quality gate.

## [1.0.1] - 2026-03-05

### Changed

- Актуализирован [README.md](README.md):
  - синхронизирован с текущей маршрутизацией через `AGENTS.md` и `instructions/governance/routing-matrix.md`;
  - обновлено описание структуры каталога;
  - уточнены секции quick start, quality gate и CI.
