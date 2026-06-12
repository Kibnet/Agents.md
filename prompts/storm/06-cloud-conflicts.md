# Prompt: /storm:conflicts

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:conflicts`.

Цель: найти конфликты текущих/proposed stories относительно needs и Product Goal через cloud-структуру.

Для каждой active/proposed story:

1. Определи supported needs.
2. Определи threatened needs/constraints.
3. Если угроза есть, создай conflict record:
   - common objective;
   - need A;
   - need B;
   - want A;
   - want B;
   - assumptions;
   - injections;
   - decision.
4. Предложи rewrite/split/add constraint/deprecate/supersede/accept risk.
5. Обнови stories, acceptance criteria и constraints.
6. Обнови `docs/product/reports/conflicts.md`.

Не удаляй код на этом шаге.
