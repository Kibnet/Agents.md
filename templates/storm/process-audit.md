# Storm Process Audit

## Summary

- Audit date:
- Repository:
- Agent:
- Scope:
- Metrics version: 2 (`process_audit.metrics_version`)

## Metrics

| Metric | Value | Target | Status |
|---|---:|---:|---|
| Total stories |  |  |  |
| Stories with tests ratio |  | >= 0.80 |  |
| AC critical/full ratio |  | >= 0.70 |  |
| Orphan tests |  | 0 or explained |  |
| Stories without needs |  | 0 or explained |  |
| Needs without support |  | 0 or proposed |  |
| Constraints without verification |  | 0 or accepted risk |  |
| Unresolved mandatory conflicts |  | 0 |  |
| Dependency cycles |  | 0 |  |
| Behavior coverage ratio |  | agreed target |  |
| Rule coverage ratio |  | agreed target |  |
| Automation coverage ratio |  | agreed target |  |
| Constraint scenario coverage ratio |  | agreed target |  |
| Executable specification ratio |  | agreed target |  |
| Orphan scenarios |  | 0 or explained |  |
| Deprecated drift |  | 0 or explained |  |
| resolved_step_reference_ratio |  | 1 or explained |  |
| step_reuse_ratio |  | contextual |  |

`resolved_step_reference_ratio` = resolved SD references / all SD references in active scenarios. `step_reuse_ratio` = SD used in >=2 distinct active scenarios / all used SD. Duplicates within one scenario do not count as reuse; deprecated/superseded scenarios are excluded. Empty denominator: n/a in report, null in machine value; numeric counts stay 0. Update legacy audit only when audit refresh was requested.

## Scorecard

| Area | Score 0-5 | Notes |
|---|---:|---|
| Traceability completeness |  |  |
| Requirement coverage quality |  |  |
| Need/Goal coherence |  |  |
| Conflict analysis usefulness |  |  |
| Backlog ranking explainability |  |  |
| Spec-code synchronization |  |  |
| Automation readiness |  |  |
| Behavior example quality |  |  |

## Top findings

1.
2.
3.

## Top-5 process improvements

| ID | Improvement | Expected effect | Success metric | Priority |
|---|---|---|---|---|
| PI-0001 |  |  |  |  |

## Open questions

-
