# Prompt: /storm:cleanup

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:cleanup`.

Цель: удалить код и тесты, которые относятся только к deprecated/superseded stories или constraints.

Изменение tests/code/step definitions выполняется только как `delivery-task` через QUEST.

Действия:

1. Найди deprecated/superseded элементы.
2. Найди их linked tests и linked code.
3. Проверь, что эти tests/code/step definitions и связанные scenarios не поддерживают active/implemented/proposed story, active constraint или enabler; учти общие step definitions.
4. Если активных связей нет, удали или упрости код/тесты.
5. Если тест всё ещё проверяет актуальный constraint, пере-привяжи его.
6. Запусти полный тестовый набор или максимально близкий доступный набор.
7. Обнови `storm.json`, `.feature` specs и traceability reports; retired scenarios не включай в active reuse/coverage metrics.

Не удаляй ничего, если есть сомнение в активной связи. Пометь как `needs_review`.
