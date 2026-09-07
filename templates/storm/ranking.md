# Dependency-aware Ranking

## Ranked backlog

| Rank | Item | Chosen for | Closure | Value* | Cost* | Priority* | Own value | Own effort | Explanation |
|---:|---|---|---|---:|---:|---:|---:|---:|---|
|  |  |  |  |  |  |  |  |  |  |

CN передаёт порядок с нулевым cost/value без executable row. Shared ST/EN prerequisite оплачивается один раз; складывать own_effort, не повторяющийся package cost_star. Implemented ST/EN не добавляет стоимость или value. Отмечать effort floor 0.1 в explanation.

## unranked_items

| ID | Reason | Blockers |
|---|---|---|
|  |  |  |

Supports-only EN: support_without_dependency. Blocked/retired prerequisite: показать ID/status blocker. EN supports не создаёт dependency edge; этот раздел report не записывается как top-level поле в storm.json.

## Assumptions

Указать missing-field defaults, effort decomposition, применённые зависимости и неопределённости. Cycle/dangling/type/number error блокирует расчёт и запись отчёта; существующие output bytes сохраняются.
