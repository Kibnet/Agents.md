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
- После первичного черновика спецификации выполнять `post-SPEC review` до запроса пользовательского подтверждения.
- В `post-SPEC review` фиксировать `Scope reviewed`: путь spec, instruction stack, selected profile, open questions и planned changed files.
- В `post-SPEC review` проверять как минимум: полноту границ, противоречия, пропущенные acceptance criteria, скрытые риски, альтернативы, недоопределённые решения, outcome-first contract, output/evidence contract, stop rules и отсутствие лишних абсолютных правил для judgement calls.
- Для UI-facing задач в `post-SPEC review` проверять, что spec содержит доступный reviewer visual planning artifact (wireframe, render, storyboard, annotated screenshot или эквивалент) либо явное `Не применимо` с причиной и fallback layout/state description.
- Если `post-SPEC review` выявил finding с однозначным исправлением, агент обязан сам обновить спецификацию и повторить затронутые quality gate проверки.
- `BLOCKER` и `HIGH` в `post-SPEC review` блокируют запрос подтверждения, пока не исправлены или не переведены в `ASK-HUMAN`.
- После реализации и обязательных проверок выполнять `post-EXEC review` до финального отчёта.
- В `post-EXEC review` фиксировать `Scope reviewed`: approved spec, `git status --short`, `git diff --stat`, relevant diff, tests/validation evidence и docs/changelog impact.
- В `post-EXEC review` проверять как минимум: отклонения от спеки, регрессии, пропущенные тесты, критичные edge cases, небезопасные допущения, устаревшие или ложные комментарии, скрытые функциональные изменения под видом refactor, неподтверждённые performance tradeoff, неподдержанные factual claims, отсутствие нужной validation evidence и незавершённые follow-up, которые на самом деле нужно исправить сейчас.
- В `post-EXEC review` проверять отсутствие unrelated changes в `git status --short` и relevant diff; если unrelated changes есть, явно отделить их от текущей задачи.
- Для задач, где применялся `ui-automation-testing`, в `post-EXEC review` проверять наличие `до`/`после` video evidence из автоматизированных UI test runs либо явный fallback с объективной причиной, командой проверки и next-best evidence.
- Если `post-EXEC review` выявил finding с однозначным исправлением, агент обязан исправить его, повторить затронутые проверки и только затем завершать задачу.
- `BLOCKER` и `HIGH` в `post-EXEC review` блокируют финальный отчёт, пока не исправлены или не переведены в `ASK-HUMAN`.
- Если review требует выбора между несколькими жизнеспособными и materially different вариантами, агент обязан:
  - перечислить варианты;
  - сравнить tradeoff;
  - самостоятельно выбрать uniquely best option, если он объективно доминирует по ограничениям задачи, рискам, совместимости и стоимости изменения.
- Спрашивать пользователя нужно только если единственного оптимального варианта нет или выбор меняет продуктовые, UX, API, операционные либо организационные договорённости.

## SHOULD

- Кратко фиксировать результат `post-SPEC review` в самой спецификации.
- Проверять design, correctness, tests, docs, comments, style/consistency и context как отдельные areas там, где они применимы к change set.
- Для значимых repository changes явно указывать validation/build evidence и повторные проверки после исправлений.
- Если задача включала рефакторинг или cleanup комментариев, явно отражать это в `post-EXEC review`.
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
