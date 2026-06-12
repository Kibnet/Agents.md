# Prompt: /storm:audit

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:audit`.

Цель: оценить качество первого прогона процесса и предложить улучшения.

Действия:

1. Запусти логическую проверку `storm.json`.
2. Посчитай process metrics, quality metrics и outcome metrics.
3. Сформируй scorecard 0–5 по направлениям:
   - traceability completeness;
   - requirement coverage quality;
   - need/goal coherence;
   - conflict analysis usefulness;
   - backlog ranking explainability;
   - spec-code synchronization;
   - automation readiness.
4. Найди top-5 слабых мест процесса.
5. Предложи изменения в `instructions/profiles/storm-product-development.md`, templates, schema или scripts.
6. Обнови `docs/product/reports/process-audit.md`.

Можно использовать:

```bash
python <AGENTS_ROOT>/scripts/storm/validate-artifacts.py docs/product/storm.json
```
