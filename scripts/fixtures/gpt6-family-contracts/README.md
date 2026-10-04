# GPT-6 family behavioral fixtures

Одиннадцать парных синтетических сценариев проверяют model selection, legacy pins, API/Codex boundaries, conditional GPT-6 API contracts, инициативу и QUEST gate. Cases передаются модели; папка oracles доступна только reviewer.

Запуск из корня candidate после отдельного transport preflight описан в рабочей SPEC. Audit проверяет provenance и полноту, но не выставляет semantic PASS. Reviewer обязан прочитать outputs, tool traces, workspace-final и соответствующие oracle отдельно.

Исторический pack каталога 5.1.0/schema 1. G08/oracle сохраняет прежнее Standard-only EU ожидание для воспроизводимости старого evidence; для current schema-2 EU acceptance используйте `gpt61-contracts`. Старые результаты не объявляются проверкой обновлённого контракта.
