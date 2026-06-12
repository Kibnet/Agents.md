# Prompt: /storm:rank

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:rank`.

Цель: построить dependency-aware backlog ranking.

Действия:

1. Построй dependency graph: `from` должен быть сделан до `to`.
2. Проверь DAG на cycles.
3. Для каждого candidate оцени RICE:
   - reach;
   - impact;
   - confidence;
   - effort как cost of change.
4. Effort разложи на:
   - architecture_blast_radius;
   - verification_complexity;
   - dependency_overhead;
   - migration_or_rollout_risk.
5. Посчитай closure для каждого candidate.
6. Посчитай `priority* = value* / cost*`.
7. Сформируй ranked backlog с объяснениями.
8. Обнови `docs/product/reports/ranking.md`.

Можно использовать:

```bash
python <AGENTS_ROOT>/scripts/storm/rank-backlog.py docs/product/storm.json --out docs/product/reports/ranking.md
```
