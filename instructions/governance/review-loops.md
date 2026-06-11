# Governance: Review Loops

## Когда применять

- Для задач, проходящих через `QUEST MODE` на фазах `SPEC` и `EXEC`.
- Когда после черновика спеки или после реализации нужен обязательный quality pass перед показом результата пользователю.

## Когда не применять

- Для задач без `SPEC gate`.
- Для чисто справочных ответов без изменения файлов и без фазы исполнения.

## MUST

- Классифицировать review-находки по severity `BLOCKER` / `HIGH` / `MEDIUM` / `LOW`.
- Использовать статусы review `PASS` / `NEEDS-FIX` / `ASK-HUMAN`.
- Для каждой находки фиксировать `Area`, `Finding`, `Required action` и `Status`.
- Делать findings actionable: указывать проверяемый риск, нарушение контракта или улучшение, а не только личное предпочтение reviewer.
- Личные предпочтения без contract, style или design основания оформлять как `LOW` / follow-up и не блокировать продолжение.
- Если findings отсутствуют, явно писать строку `Нет находок` в findings table.
- Выполнять каждый full `post-SPEC review-loop` и full `post-EXEC review-loop` как full review-loop, а не как single-pass summary.
- Full review-loop обязан включать минимум:
  - `Scope/Evidence pass`: перечислить spec, diff, files, commands, artifacts, tests и owner-documents, которые реально были просмотрены;
  - `Contract pass`: сверить результат с spec, `Non-Goals`, acceptance criteria, owner-documents, profile requirements и validation requirements;
  - `Adversarial risk pass`: попытаться найти counterexample, скрытую регрессию, пропущенный edge case, неподтверждённый claim, missing test/evidence, unrelated change или поверхностное допущение;
  - `Role-Based pass`: проверить релевантные роли для типа задачи, чтобы manual-review challenge был прикладным, а не общим вопросом;
  - `Fix and re-review`: если review привёл к исправлениям, повторить relevant passes по затронутой поверхности;
  - `Stop decision`: выбрать `PASS`, `NEEDS-FIX` или `ASK-HUMAN` только после фиксации evidence и residual risks.
- `Role-Based pass` обязан включать применимые роли:
  - `Business analyst / domain workflow` для business workflow, payments, bot behavior, domain rules, config/state behavior;
  - `UX / designer` для UI-facing, artifact-facing, layout, visual state, interaction, copy или generated visual output задач;
  - `Tester / validation` для всех задач с behavior, instruction, template, script или delivery changes;
  - `Developer / architect` для public API, data/model contracts, architecture, migration, performance или maintainability risks;
  - `Delivery / operations / security` для git, CI, deploy, config, secrets, environment, release, PR или runtime access changes.
- Для small-задач role-based review может быть компактным, но применимость ролей и stop decision должны быть явно указаны.
- `PASS` в full `post-SPEC review-loop` запрещён, если `Decision Ledger`, `User-Observable Scenarios`, `Acceptance-to-Test Matrix`, `Expected User Review Objections` или `Role-Based Review Result` пустые без `Не применимо` и проверяемой причины.
- `PASS` в full `post-EXEC review-loop` запрещён, если изменённое поведение, docs/template behavior или delivery behavior не сверены с `User-Observable Scenarios`, `Acceptance-to-Test Matrix` и незакрытыми `Expected User Review Objections`.
- `PASS` запрещён, если `Scope reviewed`, `Review passes`, `Evidence inspected`, `Depth checklist` или `Stop decision` пустые, общие или не подтверждают реальную инспекцию.
- `PASS` запрещён, если validation evidence отсутствует без объективной причины и next-best check.
- `PASS` запрещён после исправлений по review, пока не выполнен `Fix and re-review` по затронутым областям.
- Это no-evidence/no-pass rule: отсутствие concrete evidence не может завершаться `PASS`.
- `Нет находок` допустимо только если заполнены `Depth checklist` и `No-findings justification`.
- Для small-задач full review-loop может быть компактным, но всё равно обязан фиксировать `Scope/Evidence pass`, `Contract pass`, `Adversarial risk pass` и `Stop decision`; `Fix and re-review` обязателен при любых исправлениях по review.
- После первичного черновика спецификации выполнять full `post-SPEC review-loop` до запроса пользовательского подтверждения.
- В full `post-SPEC review-loop` фиксировать `Scope reviewed`: путь spec, instruction stack, selected profile, open questions и planned changed files.
- В full `post-SPEC review-loop` проверять как минимум: полноту границ, противоречия, пропущенные acceptance criteria, скрытые риски, альтернативы, недоопределённые решения, outcome-first contract, output/evidence contract, stop rules и отсутствие лишних абсолютных правил для judgement calls.
- В full `post-SPEC review-loop` проверять `Pre-Approval Rework Prevention Gate`: user-observable scenarios, decision ledger, acceptance-to-test mapping, expected user objections и применимость role-based review.
- Для UI-facing задач в full `post-SPEC review-loop` проверять, что spec содержит доступный reviewer visual planning artifact (wireframe, render, storyboard, annotated screenshot или эквивалент) либо явное `Не применимо` с причиной и fallback layout/state description.
- Если full `post-SPEC review-loop` выявил finding с однозначным исправлением, агент обязан сам обновить спецификацию и повторить затронутые quality gate проверки.
- `BLOCKER` и `HIGH` в full `post-SPEC review-loop` блокируют запрос подтверждения, пока не исправлены или не переведены в `ASK-HUMAN`.
- После реализации и обязательных проверок выполнять full `post-EXEC review-loop` до финального отчёта.
- В full `post-EXEC review-loop` фиксировать `Scope reviewed`: approved spec, `git status --short`, `git diff --stat`, relevant diff, tests/validation evidence и docs/changelog impact.
- В full `post-EXEC review-loop` проверять как минимум: отклонения от спеки, регрессии, пропущенные тесты, критичные edge cases, небезопасные допущения, устаревшие или ложные комментарии, скрытые функциональные изменения под видом refactor, неподтверждённые performance tradeoff, неподдержанные factual claims, отсутствие нужной validation evidence и незавершённые follow-up, которые на самом деле нужно исправить сейчас.
- В full `post-EXEC review-loop` проверять `User-Observable Completion Gate`: implementation/diff соответствует user-observable scenarios, validation соответствует acceptance-to-test matrix, а expected user objections закрыты или явно оставлены approved residual risk.
- В full `post-EXEC review-loop` проверять отсутствие unrelated changes в `git status --short` и relevant diff; если unrelated changes есть, явно отделить их от текущей задачи.
- Для задач, где применялся `ui-automation-testing`, в full `post-EXEC review-loop` проверять наличие `до`/`после` video evidence из автоматизированных UI test runs либо явный fallback с объективной причиной, командой проверки и next-best evidence.
- Если full `post-EXEC review-loop` выявил finding с однозначным исправлением, агент обязан исправить его, повторить затронутые проверки и только затем завершать задачу.
- `BLOCKER` и `HIGH` в full `post-EXEC review-loop` блокируют финальный отчёт, пока не исправлены или не переведены в `ASK-HUMAN`.
- Если review требует выбора между несколькими жизнеспособными и materially different вариантами, агент обязан:
  - перечислить варианты;
  - сравнить tradeoff;
  - самостоятельно выбрать uniquely best option, если он объективно доминирует по ограничениям задачи, рискам, совместимости и стоимости изменения.
- Спрашивать пользователя нужно только если единственного оптимального варианта нет или выбор меняет продуктовые, UX, API, операционные либо организационные договорённости.

## SHOULD

- Кратко фиксировать результат full `post-SPEC review-loop` в самой спецификации.
- Проверять design, correctness, tests, docs, comments, style/consistency и context как отдельные areas там, где они применимы к change set.
- Для значимых repository changes явно указывать validation/build evidence и повторные проверки после исправлений.
- В `Depth checklist` покрывать минимум: scope drift / unrelated changes, acceptance criteria, validation evidence, unsupported claims, regression / edge case risk, comments/docs/changelog, hidden behavior/API/UX/operations contract change и manual-review challenge.
- Если задача включала рефакторинг или cleanup комментариев, явно отражать это в full `post-EXEC review-loop`.
- В итоговом отчёте `EXEC` явно отделять исправленные review-находки от остаточных рисков.
- После значимых правок по результатам review делать ещё один короткий sanity-pass перед завершением.

## MAY

- Использовать компактный checklist для review, если он помогает не пропустить типовые дефекты.
- Объединять несколько мелких однотипных review-находок в один блок, если это улучшает читаемость отчёта.

## Команды

```markdown
### Post-SPEC Review
- Статус: PASS / NEEDS-FIX / ASK-HUMAN
- Scope reviewed: spec path, instruction stack, selected profile, open questions, planned changed files
- Decision: можно запрашивать подтверждение / нужно исправить / нужен выбор пользователя
- Review passes:
  - Scope/Evidence pass:
  - Contract pass:
  - Adversarial risk pass:
  - Role-Based pass:
  - Re-review after fixes / Fix and re-review:
  - Stop decision:
- Role-Based Review Result:
  - Business analyst / domain workflow:
  - UX / designer:
  - Tester / validation:
  - Developer / architect:
  - Delivery / operations / security:
- Evidence inspected:
- Depth checklist:
  - Scope drift / unrelated changes:
  - Acceptance criteria:
  - User-observable scenarios / Decision ledger / Expected objections:
  - Validation evidence:
  - Unsupported claims:
  - Regression / edge case:
  - Comments/docs/changelog:
  - Hidden contract change:
  - Manual-review challenge: что бы я нашёл, если пользователь после моего `PASS` попросит отдельное ручное ревью?
- No-findings justification:

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| BLOCKER/HIGH/MEDIUM/LOW | scope / design / acceptance / risk / evidence / profile / prompt-quality | ... или `Нет находок` | ... | fixed / accepted-risk / ask-human / follow-up |

- Fixed before continuing:
- Checks rerun:
- Needs human:
- Residual risks / follow-ups:

### Post-EXEC Review
- Статус: PASS / NEEDS-FIX / ASK-HUMAN
- Scope reviewed: approved spec, `git status --short`, `git diff --stat`, relevant diff, tests/validation evidence, docs/changelog impact
- Decision: можно завершать / нужно исправить / нужен выбор пользователя
- Review passes:
  - Scope/Evidence pass:
  - Contract pass:
  - Adversarial risk pass:
  - Role-Based pass:
  - Re-review after fixes / Fix and re-review:
  - Stop decision:
- Role-Based Review Result:
  - Business analyst / domain workflow:
  - UX / designer:
  - Tester / validation:
  - Developer / architect:
  - Delivery / operations / security:
- Evidence inspected:
- Depth checklist:
  - Scope drift / unrelated changes:
  - Acceptance criteria:
  - User-observable scenarios / Acceptance-to-test matrix / Expected objections:
  - Validation evidence:
  - Unsupported claims:
  - Regression / edge case:
  - Comments/docs/changelog:
  - Hidden contract change:
  - Manual-review challenge: что бы я нашёл, если пользователь после моего `PASS` попросит отдельное ручное ревью?
- No-findings justification:

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| BLOCKER/HIGH/MEDIUM/LOW | spec compliance / regression / tests / docs / comments / unrelated changes / evidence / follow-up | ... или `Нет находок` | ... | fixed / accepted-risk / ask-human / follow-up |

- Fixed before final report:
- Checks rerun:
- Validation evidence:
- Unrelated changes:
- Needs human:
- Residual risks / follow-ups:
```

## Связанные документы

- [instructions/governance/commenting-policy.md](./commenting-policy.md)
- [instructions/governance/document-contract.md](./document-contract.md)
- [instructions/governance/github-delivery-policy.md](./github-delivery-policy.md)
- [instructions/governance/refactoring-policy.md](./refactoring-policy.md)
- [instructions/core/model-behavior-baseline.md](../core/model-behavior-baseline.md)
- [instructions/core/quest-mode.md](../core/quest-mode.md)
- [instructions/core/quest-governance.md](../core/quest-governance.md)
- [instructions/core/quest-prompt-spec.md](../core/quest-prompt-spec.md)
- [instructions/core/quest-prompt-exec.md](../core/quest-prompt-exec.md)
