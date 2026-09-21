# Governance: Review Loops

## Когда применять

- Для задач, проходящих через `QUEST MODE` на фазах `SPEC` и `EXEC`.
- Когда после черновика спеки или после реализации нужен обязательный quality pass перед показом результата пользователю.

## Когда не применять

- Для задач без `SPEC gate`.
- Для чисто справочных ответов без изменения файлов и без фазы исполнения.

## MUST

- Использовать этот документ как единственный owner severity и disposition review-находок; linter, rubric и templates не вводят собственные severity gates. Классифицировать находки как `BLOCKER` / `HIGH` / `MEDIUM` / `LOW`.
- Использовать статусы review `PASS` / `NEEDS-FIX` / `ASK-HUMAN`.
- Для каждой находки фиксировать `Area`, `Finding`, `Required action` и `Status`.
- Делать findings actionable: указывать проверяемый риск, нарушение контракта или улучшение, а не только личное предпочтение reviewer.
- `BLOCKER` / `HIGH` и любое невыполненное обязательное AC, authorization или validation условие текущей фазы блокируют `PASS` независимо от severity label. Понижение severity, `accepted-risk`, `follow-up`, объективная причина отсутствия проверки или next-best evidence не заменяют обязательное условие.
- Для `MEDIUM` фиксировать disposition по влиянию на контракт: исправить in-scope нарушение; обосновать отсутствие нарушения обязательного условия и оставить follow-up/residual risk; либо запросить существенное user-owned решение. Невыполненное обязательное условие нельзя скрыть такой disposition.
- Личные предпочтения и `LOW` без нарушения обязательного контракта оформлять как follow-up и не блокировать продолжение. Out-of-scope улучшение не расширяет diff автоматически; обнаруженный обязательный blocker остаётся blocker и требует явного разрешения противоречия, а не скрытой реализации вне scope.
- Исправлять необходимые in-scope нарушения с однозначным решением, затем выполнять `Fix and re-review` только по затронутой поверхности. Успешные проверки и review не повторять без нового изменения, failure или конкретного незакрытого риска.
- Если findings отсутствуют, явно писать `Нет находок` с проверяемым основанием; для expanded использовать findings table и `No-findings justification`.
- До запроса exact approval выполнить `post-SPEC review-loop`; после реализации и обязательных проверок — `post-EXEC review-loop` до финального отчёта. Глубина зависит от формы SPEC, определённой `quest-governance.md`.
- Для short SPEC выполнять один компактный evidence-based pass на каждой фазе по пяти содержательным проверкам `spec-linter.md`. В общей записи фиксировать просмотренное evidence, существенный counterexample/риск, findings/disposition, затронутые повторные проверки и stop decision. Не требовать 20 отдельных оценок, числовой rubric, раздельных passes или перечисления неприменимых ролей.
- Для expanded SPEC выполнять full `post-SPEC review-loop` и full `post-EXEC review-loop`, а не single-pass summary. Full review-loop обязан включать минимум:
  - `Scope/Evidence pass`: перечислить spec, diff, files, commands, artifacts, tests и owner-documents, которые реально были просмотрены;
  - `Contract pass`: сверить результат с spec, `Non-Goals`, acceptance criteria, owner-documents, profile requirements и validation requirements;
  - `Adversarial risk pass`: попытаться найти counterexample, скрытую регрессию, пропущенный edge case, неподтверждённый claim, missing test/evidence, unrelated change или поверхностное допущение;
  - `Role-Based pass`: проверить релевантные роли для типа задачи, чтобы manual-review challenge был прикладным, а не общим вопросом;
  - `Fix and re-review`: если review привёл к исправлениям, повторить relevant passes по затронутой поверхности;
  - `Stop decision`: выбрать `PASS`, `NEEDS-FIX` или `ASK-HUMAN` только после фиксации evidence и residual risks.
- В expanded `Role-Based pass` обязан включать применимые роли:
  - `Business analyst / domain workflow` для business workflow, payments, bot behavior, domain rules, config/state behavior;
  - `UX / designer` для UI-facing, artifact-facing, layout, visual state, interaction, copy или generated visual output задач;
  - `Tester / validation` для всех задач с behavior, instruction, template, script или delivery changes;
  - `Developer / architect` для public API, data/model contracts, architecture, migration, performance или maintainability risks;
  - `Delivery / operations / security` для git, CI, deploy, config, secrets, environment, release, PR или runtime access changes.
- Для large/high-risk QUEST (`config`, `security`, `deploy`, migration, multi-module или public behavior) post-SPEC и post-EXEC должны включать independent reviewer, когда subagent facility доступна.
- Independent review считать технически read-only только при evidence фактического child sandbox `read-only`; custom-agent default без проверки effective runtime недостаточен, потому что parent live overrides могут иметь приоритет.
- Использовать personal/project custom agent из `templates/codex/agents/independent-reviewer.toml`, когда он доступен. Reviewer возвращает findings и не меняет файлы.
- Если independent reviewer или read-only sandbox недоступны, выполнять отдельный adversarial fallback, явно фиксировать причину и residual risk; self/writable pass не называть независимым.
- В expanded `PASS` в full `post-SPEC review-loop` запрещён, если `Decision Ledger`, `User-Observable Scenarios`, `Acceptance-to-Test Matrix`, `Expected User Review Objections` или `Role-Based Review Result` пустые без `Не применимо` и проверяемой причины.
- В expanded `PASS` в full `post-EXEC review-loop` запрещён, если изменённое поведение, docs/template behavior или delivery behavior не сверены с `User-Observable Scenarios`, `Acceptance-to-Test Matrix` и незакрытыми `Expected User Review Objections`.
- В expanded `PASS` запрещён, если `Scope reviewed`, `Review passes`, `Evidence inspected`, `Depth checklist` или `Stop decision` пустые, общие или не подтверждают реальную инспекцию. В short эту доказательную связь обеспечивает компактная запись пяти проверок.
- Если validation evidence отсутствует, указать объективную причину и next-best check; не выдавать частичный результат за выполненную обязательную проверку.
- `PASS` запрещён после исправлений по review, пока не выполнен `Fix and re-review` по затронутым областям.
- Это no-evidence/no-pass rule: отсутствие concrete evidence не может завершаться `PASS`.
- В expanded `Нет находок` допустимо только если заполнены `Depth checklist` и `No-findings justification`.
- В full `post-SPEC review-loop` фиксировать `Scope reviewed`: путь spec, instruction stack, selected profile, open questions и planned changed files.
- В full `post-SPEC review-loop` проверять как минимум: полноту границ, противоречия, пропущенные acceptance criteria, скрытые риски, альтернативы, недоопределённые решения, outcome-first contract, output/evidence contract, stop rules и отсутствие лишних абсолютных правил для judgement calls.
- Для model/prompt/instruction migration в full `post-SPEC review-loop` отдельно проверять: смешение standard ChatGPT, Work/Codex и API contracts; неподтверждённую availability; дублирование owner-правил; broad brevity rules; необоснованные `max` / Pro / Ultra; потерю обязательной полноты final answer; отсутствие representative before/after behavioral smoke.
- В full `post-SPEC review-loop` проверять `Pre-Approval Rework Prevention Gate`: user-observable scenarios, decision ledger, acceptance-to-test mapping, expected user objections и применимость role-based review.
- Для UI-facing задач в full `post-SPEC review-loop` проверять, что spec содержит доступный reviewer visual planning artifact (wireframe, render, storyboard, annotated screenshot или эквивалент) либо явное `Не применимо` с причиной и fallback layout/state description.
- Нерешённый blocker текущей фазы не позволяет запрашивать утверждение SPEC как готовой или завершать EXEC как выполненный. `ASK-HUMAN` означает точный вопрос о существенном решении, а не `PASS` и не разрешение зависимого действия.
- В full `post-EXEC review-loop` фиксировать `Scope reviewed`: approved spec, `git status --short`, `git diff --stat`, relevant diff, tests/validation evidence и docs/changelog impact.
- В full `post-EXEC review-loop` проверять как минимум: отклонения от спеки, регрессии, пропущенные тесты, критичные edge cases, небезопасные допущения, устаревшие или ложные комментарии, скрытые функциональные изменения под видом refactor, неподтверждённые performance tradeoff, неподдержанные factual claims, отсутствие нужной validation evidence и незавершённые follow-up, которые на самом деле нужно исправить сейчас.
- Для semantic model/prompt/instruction changes и migration требовать before/after behavioral smoke на одинаковой effective model, surface, reasoning и sandbox конфигурации с одними representative scenarios. Static validator, semantic scan и cross-model benchmark дополняют, но не заменяют этот smoke. Для механической правки ссылки/опечатки без изменения смысла достаточно релевантных static checks, если отдельный обязательный контракт не требует большего; основание классификации фиксировать.
- Если изменяемый каталог или конфигурация подключены к активной agent session через junction, symlink или global pointer, выполнять authoring и candidate validation из изолированного checkout; перед активацией сверять drift active checkout, применять один подготовленный change set, иметь проверяемый rollback и повторять critical checks уже на активном пути.
- В `post-EXEC review-loop` любой формы сверять evidence с контрактом `model-behavior-baseline.md`: исходный пользовательский сценарий и обычный путь, реально просмотренное визуальное состояние и reference fidelity, подтверждённый уровень persistence/install готовности. Несоответствующее evidence не закрывает обязательный AC.
- В full `post-EXEC review-loop` проверять `User-Observable Completion Gate`: implementation/diff соответствует user-observable scenarios, validation соответствует acceptance-to-test matrix, а expected user objections закрыты или имеют disposition без нарушения обязательного контракта.
- В full `post-EXEC review-loop` проверять отсутствие unrelated changes в `git status --short` и relevant diff; если unrelated changes есть, явно отделить их от текущей задачи.
- Для задач, где применялся `ui-automation-testing`, в full `post-EXEC review-loop` проверять наличие `до`/`после` video evidence из автоматизированных UI test runs либо явный fallback с объективной причиной, командой проверки и next-best evidence.
- Для решения о вопросе пользователю применять `collaboration-baseline.md`: отсутствие единственного оптимального обратимого внутреннего варианта само по себе не требует передачи решения человеку.

## SHOULD

- Кратко фиксировать результаты `post-SPEC review-loop` и `post-EXEC review-loop` выбранной глубины в самой спецификации без дублирования evidence; в чате достаточно outcome, validation, существенных ограничений и ссылки на audit.
- Проверять design, correctness, tests, docs, comments, style/consistency и context как отдельные areas там, где они применимы к change set.
- Для значимых repository changes явно указывать validation/build evidence и повторные проверки после исправлений.
- В expanded `Depth checklist` покрывать минимум: scope drift / unrelated changes, acceptance criteria, validation evidence, unsupported claims, regression / edge case risk, comments/docs/changelog, hidden behavior/API/UX/operations contract change и manual-review challenge.
- Если задача включала рефакторинг или cleanup комментариев, явно отражать это в full `post-EXEC review-loop`.
- В итоговом отчёте `EXEC` явно отделять исправленные review-находки от остаточных рисков.
- Включать sanity-check значимых исправлений в `Fix and re-review` затронутой поверхности, не создавать дополнительный обязательный цикл после его успешного завершения.

## MAY

- Использовать компактный checklist для review, если он помогает не пропустить типовые дефекты.
- Объединять несколько мелких однотипных review-находок в один блок, если это улучшает читаемость отчёта.

## Команды

Short использует общую таблицу пяти проверок из `templates/specs/_template-small.md`; отдельные таблицы ролей и passes ниже к short не применяются. Следующий образец предназначен для expanded SPEC.

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
- [instructions/governance/openai-responses-api.md](./openai-responses-api.md)
- [instructions/governance/refactoring-policy.md](./refactoring-policy.md)
- [instructions/core/model-behavior-baseline.md](../core/model-behavior-baseline.md)
- [instructions/core/tool-execution-baseline.md](../core/tool-execution-baseline.md)
- [instructions/core/quest-mode.md](../core/quest-mode.md)
- [instructions/core/quest-governance.md](../core/quest-governance.md)
- [instructions/governance/spec-linter.md](./spec-linter.md)
- [instructions/core/quest-prompt-spec.md](../core/quest-prompt-spec.md)
- [instructions/core/quest-prompt-exec.md](../core/quest-prompt-exec.md)
