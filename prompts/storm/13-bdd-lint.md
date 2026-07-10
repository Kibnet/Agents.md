# Prompt: /storm:bdd-lint

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:bdd-lint`.

Цель: проверить качество Gherkin как executable product behavior specification, а не как процедурных UI/test scripts.

Проверки:

1. У каждого scenario есть stable `SC-*` ID, `@scenario`, `@story` или contract/constraint основание, минимум один `@need` или объяснение исключения.
2. У каждого scenario есть `coverage_role` и `automation_status`.
3. Один scenario описывает один пример поведения.
4. `Given` описывает исходное состояние, `When` событие, `Then` наблюдаемый outcome.
5. Шаги написаны декларативным языком предметной области.
6. Scenario не описывает UI selectors, HTTP methods, SQL, классы, internal methods или infrastructure details, если это не публичный contract.
7. Нет orphan scenarios без active Story, Need или Constraint.
8. Нет active scenarios для deprecated/superseded story без другого active основания.
9. Нет дублирующихся step texts с расходящимся meaning.
10. Behavior coverage включает happy path; negative/constraint paths присутствуют для risk-sensitive stories.

В результате выдай lint report с severity, file/line если возможно, и конкретными правками.

