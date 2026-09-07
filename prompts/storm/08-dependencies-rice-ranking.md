# Prompt: /storm:rank

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:rank`.

Цель: построить dependency-aware backlog ranking.

Действия:

1. Проверь schema/types/refs/numbers, затем общий ST/CN/EN graph: top-level `from -> to` и embedded `dependencies=[X]` означают `X -> item`. EN supports — только traceability, без edge.
2. Проверь dangling refs, self-loops и cycles до status filtering. Implemented ST/EN удовлетворяют prerequisites без cost/value; blocked/retired ST/EN/CN и CN dependency_state=blocked блокируют closure. CN open не означает выполнение constraint.
3. Для каждого candidate оцени RICE:
   - reach;
   - impact;
   - confidence;
   - effort как cost of change.
4. Effort разложи на:
   - architecture_blast_radius;
   - verification_complexity;
   - dependency_overhead;
   - scenario_automation_cost;
   - step_reuse_penalty;
   - migration_or_rollout_risk.
5. Посчитай closure кандидата с уникальными неоплаченными ST/EN; CN передаёт порядок без cost/value и executable row. EN own value = 0. Сохраняй нулевые RICE множители; defaults только при отсутствии полей. Explicit effort > 0 приоритетнее decomposition; total floor = 0.1 указывай в explanation.
6. Посчитай `priority* = value* / cost*`.
7. Сформируй ranked backlog с объяснениями и `unranked_items` с ID/reason/blockers. Supports-only EN получает support_without_dependency; EN→…→ST включает стоимость один раз. Складывать можно own_effort, но не повторяющийся package cost_star. При равных priority/value/cost выбирай ascending ID.
8. Обнови `docs/product/reports/ranking.md`.

Можно использовать:

```bash
python <AGENTS_ROOT>/scripts/storm/rank-backlog.py docs/product/storm.json --out docs/product/reports/ranking.md
```

`--write-json` обновляет только ranking после полной проверки; сохраняй extension fields, порядок коллекций и прежний process audit. Ошибки контракта не должны менять input или существующий report.
