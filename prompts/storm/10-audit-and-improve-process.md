# Prompt: /storm:audit

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:audit`.

Цель: оценить качество первого прогона процесса и предложить улучшения.

Действия:

1. Запусти логическую проверку `storm.json`.
2. Посчитай process, quality, outcome и BDD metrics: behavior/rule/automation/constraint coverage, executable specification, orphan scenarios, deprecated drift.
   - `resolved_step_reference_ratio`: resolved SD references / все SD references в active scenarios.
   - `step_reuse_ratio`: SD, используемые в >=2 distinct active scenarios / все используемые SD; повтор внутри одного scenario не reuse. Retired scenarios исключены.
   - Пустой denominator: n/a в report, null в machine value, numeric counts остаются 0.
   - Для этого запрошенного audit запиши `process_audit.metrics_version = 2` и обнови audit metrics; другие команды не переписывают legacy audit.
3. Сформируй scorecard 0–5 по направлениям:
   - traceability completeness;
   - requirement coverage quality;
   - need/goal coherence;
   - conflict analysis usefulness;
   - backlog ranking explainability;
   - spec-code synchronization;
   - automation readiness;
   - behavior example quality.
4. Найди top-5 слабых мест процесса.
5. Предложи изменения в профиле/templates/schema/scripts, не меняя canonical catalog в artifact-only audit; реализация таких изменений требует отдельного delivery/QUEST scope.
6. Обнови `docs/product/reports/process-audit.md` по canonical template и `storm.json.process_audit`; не подменяй поведением metrics сведения о фактически запущенных tests.

Можно использовать:

```bash
python <AGENTS_ROOT>/scripts/storm/validate-artifacts.py docs/product/storm.json
```
