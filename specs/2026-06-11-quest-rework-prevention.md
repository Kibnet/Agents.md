# QUEST Rework Prevention Improvements

## 0. Метаданные
- Тип (профиль): `catalog-governance` + `product-system-design` overlay + `session-insights-context`
- Владелец: пользователь + центральный каталог агентских инструкций
- Масштаб: medium
- Целевая модель: gpt-5.5
- Целевой релиз / ветка: `2.11.0`, текущая рабочая ветка репозитория инструкций
- Ограничения:
  - Фаза `SPEC`: менять только этот файл.
  - Переход к `EXEC` только после точной фразы `Спеку подтверждаю`.
  - Улучшения должны снижать вероятность поздних доработок, но не превращать каждую small-задачу в непропорциональный аудит.
  - Session-derived статистика является эвристикой по локальным логам, а не абсолютной метрикой качества.
  - Новые правила не должны ослаблять `QUEST` gate, central `AGENTS.md`, routing matrix, developer/system instructions и явный запрос пользователя.
  - Изменения каталога требуют обновления `CHANGELOG.md`.
- Связанные ссылки:
  - `AGENTS.md`
  - `instructions/governance/routing-matrix.md`
  - `instructions/core/model-behavior-baseline.md`
  - `instructions/core/quest-governance.md`
  - `instructions/core/quest-mode.md`
  - `instructions/core/quest-prompt-spec.md`
  - `instructions/core/quest-prompt-exec.md`
  - `instructions/governance/review-loops.md`
  - `instructions/governance/spec-linter.md`
  - `instructions/governance/spec-rubric.md`
  - `instructions/governance/document-contract.md`
  - `instructions/governance/versioning-policy.md`
  - `instructions/contexts/session-insights-context.md`
  - `templates/specs/_template.md`
  - `session-insights/README.md`
  - `session-insights/AGENTS_IMPROVEMENT_BACKLOG.md`
  - `session-insights/AGENT_SESSION_LESSONS.md`
  - `session-insights/UI_QUALITY_RUBRIC_FROM_SESSIONS.md`
  - `session-insights/VALIDATION_COOKBOOK_FROM_SESSIONS.md`
  - `session-insights/DO_NOT_REPEAT.md`
  - `session-insights/USER_WORKFLOW_PREFERENCES.md`

Если секция не применима, это указано явно внутри секции.

## 1. Overview / Цель
Нужно обновить `QUEST`-инструкции и canonical spec template так, чтобы агент чаще находил типовые причины будущих доработок до подтверждения спеки и до финального отчёта EXEC.

Outcome contract:
- Success means:
  - `QUEST` SPEC phase содержит обязательный preventive challenge перед запросом подтверждения.
  - Canonical template заставляет фиксировать пользовательски видимые сценарии, decision ledger, role-based review и acceptance-to-test mapping.
  - `review-loops.md` проверяет не только generic depth, но и role-specific риски по типу задачи.
  - EXEC phase сверяет реализацию с user-observable scenarios и likely user objections перед финалом.
  - Новые правила остаются компактными для small-задач и масштабируются только по релевантным триггерам.
  - Validator, validator tests и semantic marker checks подтверждают, что новые обязательные маркеры присутствуют в owner-документах и template.
- Итоговый артефакт / output:
  - утверждённая спека;
  - после EXEC: обновлённые QUEST governance/template/prompt docs, changelog entry и validation evidence.
- Stop rules:
  - Остановиться до EXEC, если пользователь не подтвердил эту spec.
  - В EXEC остановиться и спросить пользователя, если внедрение требует выбора между materially different policy вариантами без uniquely best default.
  - Не завершать EXEC без full post-EXEC review-loop, validator, validator tests и semantic checks.

## 2. Текущее состояние (AS-IS)
- Текущий `QUEST` stack уже обеспечивает строгий порядок:
  - spec создаётся до реализации;
  - до `Спеку подтверждаю` нельзя менять файлы вне текущей spec;
  - post-SPEC и post-EXEC review-loop обязательны;
  - template содержит linter/rubric/review/journal sections.
- `review-loops.md` уже хорошо закрывает проблему поверхностного `PASS`:
  - требует `Scope/Evidence pass`, `Contract pass`, `Adversarial risk pass`, `Fix and re-review`, `Stop decision`;
  - запрещает `PASS` без evidence;
  - требует manual-review challenge.
- `templates/specs/_template.md` структурно полный, но всё ещё не вынуждает агента явно зафиксировать:
  - пользовательски видимые сценарии и expected UI/output;
  - decision ledger: что агент решил сам, что должен решить пользователь;
  - acceptance criterion -> test/evidence mapping;
  - likely future user objections;
  - role-specific review passes;
  - state/interaction matrix для UI/workflow задач;
  - runtime/config/data contract matrix для backend, bot, CI, deploy и integration задач.
- `quest-mode.md` и prompt wrappers требуют full review-loop, но не требуют отдельного preventive checkpoint перед approval.
- `session-insights` уже содержит полезные материалы:
  - UI quality rubric;
  - validation cookbook;
  - anti-pattern checklist;
  - agents improvement backlog.
  Однако `QUEST` template не превращает эти источники в конкретные секции спеки.

Дополнительный анализ текущей сессии по локальным JSONL логам:

| Метрика | Значение | Комментарий |
| --- | ---: | --- |
| JSONL files scanned | 464 | `sessions` + `archived_sessions` |
| QUEST/spec related clean sessions | 188 | после фильтрации approval-assessment transcript noise |
| Strict QUEST sessions | 161 | `Спеку подтверждаю`, `Post-SPEC`, `Post-EXEC`, linter/rubric или journal markers |
| Strict sessions with explicit confirm | 120 | содержат `Спеку подтверждаю` |
| Strict sessions with any rework marker | 122 | эвристика по пользовательским сообщениям |
| Sessions with pre-confirm rework | 60 | замечания к спекам до approval |
| Sessions with post-confirm rework | 63 | доработки/замечания после approval/EXEC |
| Sessions with no-confirm spec-review loop | 31 | spec/review цикл без явного перехода в EXEC |

Top strict QUEST repos по эвристике:

| Repo / context | Sessions |
| --- | ---: |
| `Unlimotion` | 46 |
| `Agents` | 44 |
| `TopLunchBot` | 29 |
| `AppAutomation` | 16 |
| Other / unknown | 9 |
| `UTEP` | 6 |
| `ArduinoAndRaspberry` | 4 |
| `Arm.Srv` | 4 |
| `DotnetDebug` | 3 |

Фазовые категории rework по session-count эвристике:

| Phase | Top categories |
| --- | --- |
| Pre-confirm / spec-stage | scope/spec/decisions 29; generic review-fix 25; acceptance/test/evidence 21; delivery/repo/config hygiene 16; domain/workflow/config 13; UI/UX 11 |
| Post-confirm / exec-stage | generic review-fix 46; acceptance/test/evidence 21; scope/spec/decisions 17; UI/UX 10; delivery/repo/config hygiene 10; domain/workflow/config 9 |
| No-confirm / spec-review-only | generic review-fix 21; acceptance/test/evidence 19; UI/UX 12; scope/spec/decisions 10; domain/workflow/config 10 |

Ограничения анализа:
- Категории пересекаются.
- Generic `сделай ревью` / `исправь` часто скрывает конкретную причину, поэтому нужны не только keyword counts, но и preventive workflow.
- Часть старых сессий содержит служебные approval transcripts; они фильтровались, но статистика всё равно остаётся эвристикой.

## 3. Проблема
Корневая проблема: `QUEST` гарантирует наличие спеки и review-loop, но не заставляет агента до approval смоделировать типовые будущие замечания пользователя и привязать каждое пользовательски видимое ожидание к проверяемому evidence. Из-за этого часть решений выглядит формально готовой, но пользователь затем просит доработать UX, domain behavior, config/runtime contract, тесты или саму спеку.

## 4. Цели дизайна
- Разделение ответственности:
  - `quest-mode.md` задаёт phase stop rules и preventive checkpoint.
  - `review-loops.md` задаёт role-based review semantics.
  - `templates/specs/_template.md` задаёт audit-friendly поля, которые агент обязан заполнить.
  - prompt wrappers направляют агента использовать новые поля без дублирования полного алгоритма.
- Повторное использование:
  - Один набор секций должен работать для UI, backend, bot, CI, docs и instruction changes.
- Тестируемость:
  - Новые обязательные маркеры проверяются semantic `rg` checks.
  - Standard validators продолжают проверять структуру каталога.
- Консистентность:
  - Новые поля расширяют текущий template, а не заменяют linter/rubric/review-loop.
  - Existing `QUEST` approval phrase and mutation boundary remain unchanged.
- Обратная совместимость:
  - Старые spec-файлы не мигрируются.
  - Новые требования применяются к будущим спекам.
- Пропорциональность:
  - Для small-задач допускается компактное заполнение, но нельзя пропускать preventive challenge, decision ledger и acceptance-to-test mapping полностью.

## 5. Non-Goals (чего НЕ делаем)
- Не меняем фразу перехода `Спеку подтверждаю`.
- Не ослабляем запрет на изменения вне spec до approval.
- Не строим автоматический анализ всех прошлых сессий при каждой QUEST-задаче.
- Не добавляем RAG/MCP/embedding index.
- Не требуем внешнего sub-agent reviewer.
- Не делаем role-based review обязательным exhaustive audit для нерелевантных ролей.
- Не мигрируем исторические specs.
- Не коммитим raw session logs или приватные user profile artifacts.
- Не заменяем `session-insights-context`; используем его как источник эвристик.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
| Файл | Новая ответственность |
| --- | --- |
| `instructions/core/quest-mode.md` | Добавить `Pre-Approval Rework Prevention Gate` на SPEC и `User-Observable Completion Gate` на EXEC. |
| `instructions/core/quest-governance.md` | Требовать preventive challenge как часть `QUEST` quality gate. |
| `instructions/core/quest-prompt-spec.md` | В prompt contract добавить likely objections, decision ledger, user-observable scenarios и acceptance-to-test mapping. |
| `instructions/core/quest-prompt-exec.md` | Перед финалом требовать сверку реализации с user-observable scenarios, acceptance-to-test matrix и unresolved likely objections. |
| `instructions/governance/review-loops.md` | Добавить role-based review passes и правило: generic manual-review challenge должен включать релевантные роли. |
| `templates/specs/_template.md` | Добавить новые секции/таблицы для preventive design и evidence mapping. |
| `scripts/validate-instructions.ps1` | При необходимости добавить semantic marker checks для новых mandatory markers. |
| `scripts/test-validate-instructions.ps1` | Проверить validator changes, если semantic checks добавляются в script. |
| `CHANGELOG.md` | Добавить `2.11.0` с описанием strengthened QUEST rework prevention. |

### 6.2 Детальный дизайн
Добавить в template новые блоки внутри существующих секций, чтобы не ломать нумерацию:

1. В `## 6. Предлагаемое решение (TO-BE)` добавить:
   - `### 6.3 User-Observable Scenarios`
   - `### 6.4 State / Interaction Matrix`
   - `### 6.5 Decision Ledger`
   - `### 6.6 Runtime / Config / Data Contract Matrix`

2. В `## 11. Тестирование и критерии приёмки` добавить:
   - `Acceptance-to-Test Matrix`;
   - explicit wording: `Definition of Done` describes how to verify completed work, not preparation steps;
   - `Evidence required before final`.

3. В `## 12. Риски и edge cases` добавить:
   - `Expected User Review Objections`;
   - `Rework Prevention Checklist`.

4. В `## 19. Результат quality gate и review` добавить:
   - `Role-Based Review Result`;
   - role passes:
     - Business analyst / domain workflow;
     - UX / designer for UI-facing or artifact-facing tasks;
     - Tester / validation;
     - Developer / architect;
     - Delivery / operations / security when repo, config, deploy, secret or PR risk exists.

New template tables:

```markdown
### 6.3 User-Observable Scenarios
| Scenario | User action / trigger | Expected visible result / output | Evidence required | Covered by AC |
| --- | --- | --- | --- | --- |

### 6.4 State / Interaction Matrix
| Current state | Trigger | Expected transition/result | Empty/error/disabled/concurrent case | Notes |
| --- | --- | --- | --- | --- |

### 6.5 Decision Ledger
| Decision | Owner | Default / chosen option | Confidence | Risk if assumed | Needs user before EXEC |
| --- | --- | --- | ---: | --- | --- |

### 6.6 Runtime / Config / Data Contract Matrix
| Contract area | Current source of truth | Expected change | Compatibility / migration | Verification |
| --- | --- | --- | --- | --- |
```

Acceptance-to-test table:

```markdown
### Acceptance-to-Test Matrix
| Acceptance criterion | Automated test | Manual / visual / log check | Evidence artifact | If not tested, why |
| --- | --- | --- | --- | --- |
```

Expected objections table:

```markdown
### Expected User Review Objections
| Likely objection | Why likely | Mitigation in spec/code plan | Status |
| --- | --- | --- | --- |
```

Role review table:

```markdown
### Role-Based Review Result
| Role | Applicability | Review question | Verdict | Required spec changes |
| --- | --- | --- | --- | --- |
```

### 6.3 Pre-Approval Rework Prevention Gate
Перед запросом `Спеку подтверждаю` агент обязан:

1. Заполнить `Decision Ledger`.
2. Заполнить `User-Observable Scenarios` для всех user-facing, output-facing, workflow-facing или delivery-facing изменений.
3. Заполнить `Acceptance-to-Test Matrix`.
4. Заполнить `Expected User Review Objections` минимум 3 строками для medium/large задач и минимум 1 строкой для small задач.
5. Выполнить role-based post-SPEC review по релевантным ролям.
6. Все однозначные findings закрыть в spec и повторить affected review/linter/rubric checks.
7. Если decision ledger содержит `Needs user before EXEC = Да`, не запрашивать approval как готовую spec; вместо этого задать точный вопрос.

### 6.4 EXEC User-Observable Completion Gate
Перед финальным отчётом EXEC агент обязан:

1. Сверить diff and behavior с `User-Observable Scenarios`.
2. Сверить проверки с `Acceptance-to-Test Matrix`.
3. Проверить, что `Expected User Review Objections` закрыты либо явно остались accepted risk/follow-up из approved spec.
4. В post-EXEC review указать, какие user-observable scenarios реально проверены.

Output contract / evidence rules:
- `PASS` в post-SPEC запрещён, если новые mandatory tables пустые без `Не применимо` и причины.
- `PASS` в post-EXEC запрещён, если changed behavior не связан с acceptance evidence.
- Для UI-facing изменений role `UX / designer` применима всегда, даже если изменение кажется техническим.
- Для config/deploy/bot/payment/CI задач role `Delivery / operations / security` применима всегда.
- Для spec-only/instruction changes user-observable scenario = как будущий агент будет применять правило.

Visual planning artifact для UI-facing изменений:
- В этой spec не применимо как UI artifact, потому что меняется instruction workflow.
- Для будущих UI specs UX role должен проверять наличие visual planning artifact или explicit fallback по existing `model-behavior-baseline`.

UI test video evidence для UI automation задач:
- В этой spec не применимо.
- Для будущих UI automation specs matrix должна указывать video/screenshot evidence согласно существующим `ui-automation-testing` and delivery policy rules.

Границы сохранения поведения:
- Approval phrase не меняется.
- `QUEST` остаётся SPEC-first.
- Full review-loop остаётся owner-договором `review-loops.md`; новая role-based часть расширяет manual-review challenge.

Обработка ошибок:
- Если role applicability спорная, агент выбирает более строгую роль, но может заполнить компактно.
- Если нет доступного evidence для acceptance criterion, spec должна назвать blocker or next-best check.
- Если user-observable scenario невозможно проверить локально, это фиксируется как risk/follow-up only if approved.

Производительность:
- Для small задач таблицы могут иметь 1-2 строки.
- Для medium/large задач заполнять все релевантные роли и минимум 3 likely objections.
- Deep session-insights lookup не обязателен для каждой QUEST-задачи; использовать `session-insights-context` по триггерам.

## 7. Бизнес-правила / Алгоритмы (если есть)
### 7.1 Role Applicability Matrix
| Триггер задачи | Обязательные роли review |
| --- | --- |
| UI layout, visual state, interaction, generated artifact | UX / designer; Tester; Developer |
| Business workflow, payments, bot behavior, domain state | Business analyst; Tester; Developer |
| Config, deploy, CI, GitHub delivery, secrets, runtime environment | Delivery / operations / security; Tester; Developer |
| Public API, model/data contract, architecture, performance | Developer / architect; Tester; Business analyst if behavior changes |
| Instruction/template/prompt changes | Future-agent user-observable reviewer; Developer / architect; Tester / validator |
| Small docs-only wording change | Tester / validation; Developer / architect compact pass |

### 7.2 Preventive Challenge Algorithm
| Step | Action | Stop condition |
| --- | --- | --- |
| 1 | Identify user-observable outputs and workflows | Stop if none can be named for behavior change |
| 2 | Convert each output/workflow into scenario row | Stop if expected result is ambiguous |
| 3 | Map every acceptance criterion to evidence | Stop if important AC has no test/check/fallback |
| 4 | Fill decision ledger | Stop if user-owned decision blocks EXEC |
| 5 | Predict likely objections | Stop if mitigation requires spec change |
| 6 | Run role-based review | Stop on BLOCKER/HIGH or ask-human |
| 7 | Re-review after fixes | Stop only when affected findings closed |

### 7.3 Definition of Done Rule
`Definition of Done`, acceptance criteria and completion evidence describe how to verify finished work. They must not be written as preparation steps such as "read files" or "think about design" unless the result of that preparation is itself an auditable artifact.

## 8. Точки интеграции и триггеры
- `quest-mode.md`:
  - SPEC: before asking approval, run `Pre-Approval Rework Prevention Gate`.
  - EXEC: before final report, run `User-Observable Completion Gate`.
- `quest-governance.md`:
  - Add preventive gate to mandatory quality gate list.
- `quest-prompt-spec.md`:
  - Add new success criteria and output expectations.
- `quest-prompt-exec.md`:
  - Add completion criteria tied to user-observable scenarios and acceptance-to-test matrix.
- `review-loops.md`:
  - Add role-based review pass requirements and compact applicability rules.
- `templates/specs/_template.md`:
  - Add new sections/tables.
- `scripts/*`:
  - Add semantic checks only if current validators do not catch missing markers reliably.
- `CHANGELOG.md`:
  - Add `2.11.0`.

## 9. Изменения модели данных / состояния
- Runtime данных нет.
- Persisted artifacts:
  - эта working spec;
  - after EXEC: updated Markdown instruction/template docs;
  - optional validator script changes;
  - changelog entry.

## 10. Миграция / Rollout / Rollback
- Rollout:
  1. Update `templates/specs/_template.md` with new tables.
  2. Update `review-loops.md` with role-based review contract.
  3. Update `quest-mode.md`, `quest-governance.md`, `quest-prompt-spec.md`, `quest-prompt-exec.md`.
  4. Add validator semantic checks if needed.
  5. Add `CHANGELOG.md` entry `2.11.0`.
  6. Run validators and semantic checks.
- Обратная совместимость:
  - Historical specs remain valid as historical artifacts.
  - New template applies to new specs.
  - Compact mode keeps small tasks practical.
- Rollback:
  - Revert affected instruction/template/script/changelog files.
  - Re-run validators.

## 11. Тестирование и критерии приёмки
Acceptance Criteria:
1. `templates/specs/_template.md` contains `User-Observable Scenarios`, `State / Interaction Matrix`, `Decision Ledger`, `Runtime / Config / Data Contract Matrix`, `Acceptance-to-Test Matrix`, `Expected User Review Objections`, `Role-Based Review Result`.
2. `quest-mode.md` requires `Pre-Approval Rework Prevention Gate` before asking for `Спеку подтверждаю`.
3. `quest-mode.md` requires `User-Observable Completion Gate` before final EXEC report.
4. `quest-governance.md` includes the preventive gate in mandatory QUEST quality gate.
5. `quest-prompt-spec.md` requires likely objections, decision ledger, user-observable scenarios and acceptance-to-test mapping.
6. `quest-prompt-exec.md` requires post-EXEC verification against user-observable scenarios, acceptance-to-test matrix and expected objections.
7. `review-loops.md` defines role-based review passes and role applicability without replacing existing full review-loop.
8. `review-loops.md` keeps compact mode possible for small tasks while preserving evidence and stop decision.
9. `CHANGELOG.md` contains `2.11.0`.
10. Standard validators pass.
11. Semantic marker checks pass.

Acceptance-to-Test Matrix for this change:

| Acceptance criterion | Automated test | Manual / semantic check | Evidence artifact | If not tested, why |
| --- | --- | --- | --- | --- |
| AC1 | `scripts/validate-instructions.ps1` if template checks are included | `rg -n "User-Observable Scenarios|Decision Ledger|Acceptance-to-Test Matrix|Expected User Review Objections|Role-Based Review Result" templates/specs/_template.md` | command output | N/A |
| AC2-AC4 | `scripts/validate-instructions.ps1` | `rg -n "Pre-Approval Rework Prevention Gate|User-Observable Completion Gate|preventive" instructions/core/quest-mode.md instructions/core/quest-governance.md` | command output | N/A |
| AC5-AC6 | `scripts/validate-instructions.ps1` | `rg -n "Decision Ledger|user-observable|likely objections|Acceptance-to-Test" instructions/core/quest-prompt-spec.md instructions/core/quest-prompt-exec.md` | command output | N/A |
| AC7-AC8 | `scripts/validate-instructions.ps1` | `rg -n "Role-Based|Business analyst|UX / designer|Delivery / operations / security|compact" instructions/governance/review-loops.md` | command output | N/A |
| AC9 | N/A | `rg -n "## \\[2\\.9\\.0\\]" CHANGELOG.md` | command output | N/A |
| AC10 | `pwsh -File scripts/validate-instructions.ps1` | N/A | command output | N/A |
| AC11 | `pwsh -File scripts/test-validate-instructions.ps1` if validator scripts changed; otherwise semantic checks above | N/A | command output | N/A |

Characterization tests / contract checks для текущего поведения:
- Before EXEC, inspect current owner docs to avoid duplicating existing full review-loop language.
- After EXEC, verify approval phrase still appears unchanged:
  - `rg -n "Спеку подтверждаю" instructions/core/quest-mode.md instructions/core/quest-governance.md instructions/core/quest-prompt-spec.md templates/specs/_template.md`

Visual acceptance для UI-facing изменений:
- Не применимо: instruction/template change.

UI video evidence для UI-facing фич/багфиксов:
- Не применимо.

Базовые замеры до/после для performance tradeoff:
- Не применимо.

Команды для проверки:

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
rg -n "User-Observable Scenarios|Decision Ledger|Acceptance-to-Test Matrix|Expected User Review Objections|Role-Based Review Result" templates/specs/_template.md
rg -n "Pre-Approval Rework Prevention Gate|User-Observable Completion Gate" instructions/core/quest-mode.md
rg -n "preventive|Pre-Approval Rework Prevention Gate" instructions/core/quest-governance.md
rg -n "Decision Ledger|user-observable|likely objections|Acceptance-to-Test" instructions/core/quest-prompt-spec.md instructions/core/quest-prompt-exec.md
rg -n "Role-Based|Business analyst|UX / designer|Delivery / operations / security|compact" instructions/governance/review-loops.md
rg -n "## \[2\.9\.0\]" CHANGELOG.md
rg -n "Спеку подтверждаю" instructions/core/quest-mode.md instructions/core/quest-governance.md instructions/core/quest-prompt-spec.md templates/specs/_template.md
```

Stop rules для test/retrieval/tool/validation loops:
- Не запускать broad searches по all sessions during EXEC; эта spec уже содержит analysis snapshot.
- Если validator fails, fix validator or docs before final.
- Если semantic marker missing, update relevant owner doc/template and rerun affected checks.

## 12. Риски и edge cases
| Риск | Смягчение |
| --- | --- |
| Template станет слишком тяжёлым | Разрешить compact rows for small tasks, but require explicit `Не применимо` with reason. |
| Агент будет формально заполнять новые таблицы | Role-based review and manual-review challenge must inspect table substance, not only presence. |
| Секции дублируют existing review-loop | Keep review-loop as owner semantics; template stores evidence. |
| Overfitting to UI sessions | Role matrix covers UI, domain, delivery, architecture and instructions separately. |
| Validator becomes brittle | Prefer semantic checks only for stable mandatory markers. |
| Future agents ignore session-insights | Route through existing `session-insights-context`, not raw session logs. |

Expected User Review Objections:

| Likely objection | Why likely | Mitigation in spec/code plan | Status |
| --- | --- | --- | --- |
| "Ты добавил слишком много бюрократии в каждую маленькую задачу" | QUEST already has large template; extra tables can feel heavy. | Compact mode for small tasks; role applicability by trigger; `Не применимо` allowed with reason. | mitigated |
| "Опять будет формальный PASS, только с новыми словами" | Past problem was superficial review, not missing headings only. | Role-based review must evaluate substance; no PASS if mandatory tables are empty/general. | mitigated |
| "SPEC должна ловить мои будущие замечания, а не просто описывать реализацию" | User explicitly asked to reduce follow-up rework. | Add likely objections, decision ledger, user-observable scenarios before approval. | mitigated |
| "Критерии готовности нужны для проверки, не для подготовки" | This was a concrete prior review correction. | Add Definition of Done verification-only rule. | mitigated |
| "UI и workflow замечания всё равно пропустят" | UI/domain categories were frequent in QUEST rework. | Mandatory UX role for UI-facing tasks and BA role for domain workflow tasks. | mitigated |

Rework Prevention Checklist:
- Does the spec name what the user will see or operate?
- Does every user-visible scenario have evidence?
- Did the agent list decisions it assumed?
- Did the agent predict likely objections and mitigate them?
- Did role-based review run for the relevant task type?
- Are acceptance criteria verifiers, not preparation steps?
- Does EXEC have a path to prove the scenarios before final?

## 13. План выполнения
1. Update canonical template with new tables and explanatory compact-use rules.
2. Update `review-loops.md` with role-based review pass and applicability matrix.
3. Update `quest-mode.md` with SPEC and EXEC gates.
4. Update `quest-governance.md` to include preventive gate in quality gate.
5. Update prompt wrappers.
6. Update validator scripts only if stable semantic checks belong there; otherwise run semantic checks manually and document them.
7. Update changelog.
8. Run validation commands.
9. Perform full post-EXEC review-loop and fix findings.

## 14. Открытые вопросы
Блокирующих вопросов нет. Default policy выбран так:

- Внедрять mandatory sections into template.
- Keep compact mode for small tasks.
- Do not add new standalone governance doc.
- Do not build session-analysis automation/RAG in this change.
- Add validator semantic checks only if they remain stable and low-noise.

Если пользователь хочет более строгий режим, это можно изменить до EXEC: make role-based tables mandatory full-size for all specs. Recommended default remains proportional compact mode.

## 15. Соответствие профилю
- Профиль: `catalog-governance` + `product-system-design` overlay + `session-insights-context`.
- Выполненные требования профиля:
  - Явно описаны цели и non-goals.
  - Описаны целевые owner-doc responsibilities and compatibility boundaries.
  - Учтены security/privacy limits around session-derived data.
  - Есть acceptance criteria and validation commands.
  - Есть alternatives and tradeoffs.
  - `session-insights` использованы как эвристика, текущие repo docs проверены.

## 16. Таблица изменений файлов
Планируемые изменения после утверждения:

| Файл | Изменения | Причина |
| --- | --- | --- |
| `specs/2026-06-11-quest-rework-prevention.md` | Working spec | Зафиксировать дизайн и approval gate. |
| `templates/specs/_template.md` | Add preventive tables and role-based review block | Чтобы будущие спеки заранее фиксировали scenarios, decisions, evidence and likely objections. |
| `instructions/governance/review-loops.md` | Add role-based review semantics | Чтобы manual-review challenge был прикладным по типу задачи. |
| `instructions/core/quest-mode.md` | Add pre-approval and pre-final gates | Чтобы phase owner enforce timing. |
| `instructions/core/quest-governance.md` | Add preventive gate to QUEST quality gate | Чтобы applicability/quality owner aligned. |
| `instructions/core/quest-prompt-spec.md` | Update prompt success criteria | Чтобы SPEC prompt создавал новые sections. |
| `instructions/core/quest-prompt-exec.md` | Update EXEC success criteria | Чтобы EXEC сверял реализацию с preventive sections. |
| `scripts/validate-instructions.ps1` | Optional semantic marker checks | Зафиксировать mandatory markers if stable. |
| `scripts/test-validate-instructions.ps1` | Optional validator regression updates | Проверить validator script changes. |
| `CHANGELOG.md` | Add `2.11.0` entry | Versioning policy. |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| Pre-approval readiness | Linter/rubric/full review-loop | Plus preventive rework challenge before asking approval |
| User-visible behavior | Может быть описано в TO-BE/AC, но не обязательно отдельно | Explicit user-observable scenarios |
| Decisions | Open questions only | Decision ledger with owner, default, confidence and risk |
| Acceptance evidence | Text list of tests/checks | Acceptance-to-test matrix |
| Future user objections | Generic manual-review challenge | Expected objections table plus role-based review |
| UI/task-type review | Existing visual artifact checks | UX/designer role always applies to UI-facing tasks |
| Domain/config/deploy review | Generic risk/edge cases | BA and delivery/security roles by trigger |
| EXEC final | Full post-EXEC review | Plus completion gate against scenarios/matrix/objections |

## 18. Альтернативы и компромиссы
### Вариант A: Только добавить больше пунктов в `review-loops.md`
- Плюсы:
  - Меньше изменений.
  - Не утяжеляет template.
- Минусы:
  - Агент может не принести findings into spec design.
  - Будущему reviewer сложнее увидеть decisions and evidence mapping.
- Почему не выбран:
  - Проблема возникает до approval; template должен заставлять думать заранее.

### Вариант B: Добавить новые template sections + role-based review
- Плюсы:
  - Повышает качество спеки до approval.
  - Делает будущие замечания видимыми как checklist.
  - Хорошо проверяется semantic markers.
- Минусы:
  - Template становится длиннее.
- Почему выбран:
  - Лучший баланс prevention vs implementation cost.

### Вариант C: Сделать обязательный внешний reviewer/sub-agent
- Плюсы:
  - Независимость выше.
- Минусы:
  - Не всегда доступно; дороже; требует дополнительных инструментов.
- Почему не выбран:
  - Можно получить большую часть пользы self-contained rules.

### Вариант D: Автоматически анализировать все прошлые QUEST-сессии перед каждой spec
- Плюсы:
  - Максимальный historical recall.
- Минусы:
  - Медленно, приватно, шумно, token-heavy.
- Почему не выбран:
  - Existing `session-insights-context` уже задаёт on-demand approach.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, design goals and non-goals зафиксированы. |
| B. Качество дизайна | 6-10 | PASS | Owner responsibilities, preventive gates, role matrix, rollout/rollback described. |
| C. Безопасность изменений | 11-13 | PASS | Approval phrase and SPEC mutation boundary preserved; session data treated as heuristic. |
| D. Проверяемость | 14-16 | PASS | Acceptance criteria, semantic checks, validators and file table defined. |
| E. Готовность к автономной реализации | 17-19 | PASS | Plan, alternatives, no blocking questions and quality gate present. |
| F. Соответствие профилю | 20 | PASS | Catalog-governance, product-system-design and session-insights constraints reflected. |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | 5 | Root problem and non-goals are explicit. |
| 2. Понимание текущего состояния | 5 | Current QUEST stack and session-derived evidence summarized with limits. |
| 3. Конкретность целевого дизайна | 5 | New sections, gates, role matrix and affected files specified. |
| 4. Безопасность (миграция, откат) | 5 | Approval gate, rollback and compatibility are preserved. |
| 5. Тестируемость | 5 | Validators and semantic marker checks are listed. |
| 6. Готовность к автономной реализации | 5 | No blocking questions; implementation plan and file table are complete. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

### Post-SPEC Review
- Статус: PASS
- Scope reviewed: `specs/2026-06-11-quest-rework-prevention.md`, central `catalog-governance` stack, `product-system-design` profile, `session-insights-context`, current `QUEST` owner docs, canonical template, session-insights operational docs, compact JSONL stats from current turn.
- Decision: можно запрашивать подтверждение.
- Review passes:
  - Scope/Evidence pass: checked central AGENTS pointer, routing matrix, quest-governance, quest-mode, prompt wrappers, review-loops, canonical template, existing session-insights spec, review-depth spec, session-insights README/backlog/lessons/UI/validation/do-not-repeat/workflow preferences and current JSONL aggregate stats.
  - Contract pass: spec preserves SPEC-only mutation boundary, exact approval phrase, versioning/changelog requirement, document-contract constraints and session-insights trust model.
  - Adversarial risk pass: checked for over-bureaucracy, formal table-filling without substance, overfitting to UI, duplicate owner responsibilities, missing validation, and hidden weakening of current full review-loop.
  - Re-review after fixes / Fix and re-review: no file edits outside this spec; spec was written with mitigations for identified risks before final review block.
  - Stop decision: `PASS`; no blocking open questions.
- Evidence inspected:
  - `instructions/core/quest-mode.md`
  - `instructions/core/quest-governance.md`
  - `instructions/core/quest-prompt-spec.md`
  - `instructions/core/quest-prompt-exec.md`
  - `instructions/governance/review-loops.md`
  - `templates/specs/_template.md`
  - `instructions/contexts/session-insights-context.md`
  - `session-insights/AGENTS_IMPROVEMENT_BACKLOG.md`
  - `session-insights/AGENT_SESSION_LESSONS.md`
  - `session-insights/UI_QUALITY_RUBRIC_FROM_SESSIONS.md`
  - `session-insights/VALIDATION_COOKBOOK_FROM_SESSIONS.md`
  - `session-insights/DO_NOT_REPEAT.md`
  - `session-insights/USER_WORKFLOW_PREFERENCES.md`
  - Current-turn JSONL aggregate analysis output.
- Depth checklist:
  - Scope drift / unrelated changes: PASS; only working spec is changed on SPEC phase.
  - Acceptance criteria: PASS; each affected owner/template surface has AC and semantic check.
  - Validation evidence: PASS for SPEC design; EXEC validation commands are defined.
  - Unsupported claims: PASS; session stats marked as heuristic and filtered-clean, not absolute.
  - Regression / edge case: PASS; compact mode avoids excessive burden for small tasks.
  - Comments/docs/changelog: PASS; changelog planned for EXEC.
  - Hidden contract change: PASS; approval phrase and mutation gate unchanged.
  - Manual-review challenge: likely user review would focus on over-bureaucracy and formal table filling; both are mitigated by compact mode and substance-based role review.
- No-findings justification: Findings were handled during spec drafting; remaining risks are documented and do not block approval.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| MEDIUM | proportionality | New tables could make small specs too heavy. | Add compact mode and `Не применимо` with reason. | fixed |
| MEDIUM | enforceability | Headings alone may create formal compliance without better reasoning. | Add substance-based role review and no PASS if mandatory tables are empty/general. | fixed |
| MEDIUM | scope | Session data could be overfit into global rules. | Treat stats as heuristic and route future lookup through `session-insights-context`. | fixed |
| LOW | validation | Semantic marker checks may be brittle if embedded in validator. | Make validator script changes optional; require manual semantic checks either way. | fixed |
| LOW | UX/domain coverage | Generic review could still miss UI/domain issues. | Add role applicability matrix with mandatory roles by trigger. | fixed |

- Fixed before continuing:
  - Added compact mode.
  - Added explicit Definition of Done verification-only rule.
  - Added role applicability matrix.
  - Added EXEC completion gate.
  - Added semantic checks and rollback.
- Checks rerun:
  - Manual SPEC linter: PASS.
  - Manual SPEC rubric: 30/30.
  - `pwsh -File scripts/validate-instructions.ps1`: PASS.
  - `pwsh -File scripts/test-validate-instructions.ps1`: PASS.
  - `git diff --check -- .\specs\2026-06-11-quest-rework-prevention.md`: PASS.
- Needs human:
  - Нет, кроме стандартного approval gate.
- Residual risks / follow-ups:
  - During EXEC, keep wording concise; do not duplicate the same rule across every owner doc more than needed.

### Post-EXEC Review
- Статус: PASS
- Scope reviewed: approved spec, `git status --short`, `git diff --stat`, relevant diff for `CHANGELOG.md`, `instructions/core/quest-governance.md`, `instructions/core/quest-mode.md`, `instructions/core/quest-prompt-exec.md`, `instructions/core/quest-prompt-spec.md`, `instructions/governance/review-loops.md`, `templates/specs/_template.md`, validation evidence and semantic marker checks.
- Decision: можно завершать.
- Review passes:
  - Scope/Evidence pass: PASS; changed files match approved file table, with no validator script changes because manual semantic checks remained stable and sufficient.
  - Contract pass: PASS; implementation adds the approved template sections, pre-approval gate, user-observable completion gate, role-based review semantics, prompt wrapper alignment and changelog entry while preserving approval phrase and SPEC mutation boundary.
  - Adversarial risk pass: PASS after fix; reviewed risks of over-bureaucracy, formal table filling, overfitting to UI, missing semantic markers, weakening current review-loop and mixed-language policy wording.
  - Role-Based pass: PASS; instruction/template change reviewed as future-agent user-observable workflow, tester/validator surface, developer/architect owner-doc alignment and delivery/changelog scope.
  - Re-review after fixes / Fix and re-review: PASS; after language consistency finding was fixed, validators and semantic checks were rerun.
  - Stop decision: PASS.
- Role-Based Review Result:
  - Business analyst / domain workflow: not applicable for runtime business logic; future-agent workflow behavior checked in user-observable completion gate.
  - UX / designer: not applicable as application UI; artifact-facing template ergonomics checked for compact mode and `Не применимо` escape.
  - Tester / validation: PASS; validator, validator tests, `git diff --check` and semantic markers passed.
  - Developer / architect: PASS; owner boundaries between template, quest-mode, quest-governance, prompts and review-loops remain coherent.
  - Delivery / operations / security: PASS; changelog added, no secrets/session raw data added, no PR/CI/deploy changes.
- Evidence inspected:
  - `pwsh -File scripts/validate-instructions.ps1` -> PASS.
  - `pwsh -File scripts/test-validate-instructions.ps1` -> PASS.
  - `git diff --check` -> PASS with CRLF normalization warnings only.
  - `rg` semantic checks for template markers, gates, prompt markers, role-based review markers, changelog `2.11.0`, and unchanged approval phrase -> PASS.
  - `git status --short` -> only approved files plus working spec are changed.
  - `git diff --stat` -> 7 tracked files changed; spec remains new untracked working artifact until staging/commit is requested.
- Depth checklist:
  - Scope drift / unrelated changes: PASS; affected files are within approved scope, and validator scripts were intentionally unchanged.
  - Acceptance criteria: PASS; AC1-AC11 covered by tracked file changes and semantic checks.
  - User-observable scenarios / Acceptance-to-test matrix / Expected objections: PASS; future-agent workflow now has required template fields, phase gates, prompt guidance and role-based review enforcement.
  - Validation evidence: PASS; standard validators and semantic checks passed after fixes.
  - Unsupported claims: PASS; session-derived analysis remains in spec only and is described as heuristic.
  - Regression / edge case: PASS; compact mode and `Не применимо` with reason mitigate excessive overhead for small specs.
  - Comments/docs/changelog: PASS; changelog `2.11.0` added, no comments/docstrings affected.
  - Hidden contract change: PASS; approval phrase `Спеку подтверждаю`, SPEC-only mutation boundary and existing full review-loop remain intact.
  - Manual-review challenge: likely manual review would question whether new headings alone prevent formal compliance; review-loops now blocks `PASS` when mandatory tables are empty/general without `Не применимо` and reason, and requires role-based substance review.
- No-findings justification: Not applicable; one low finding was fixed during review.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| LOW | docs/language | A few new lines mixed English and Russian more than necessary. | Rephrase to Russian while preserving stable marker names. | fixed |
| LOW | validator | Semantic marker checks were not embedded in `validate-instructions.ps1`. | Keep validator unchanged because checks are stable as manual EXEC evidence and script changes were optional in the approved spec. | accepted-risk |

- Fixed before final report:
  - Rephrased mixed-language review-loop and prompt/changelog lines.
- Checks rerun:
  - `pwsh -File scripts/validate-instructions.ps1` -> PASS.
  - `pwsh -File scripts/test-validate-instructions.ps1` -> PASS.
  - `git diff --check` -> PASS with CRLF normalization warnings only.
  - Semantic marker checks from section 11 -> PASS.
- Validation evidence:
  - Template contains all new preventive sections.
  - `quest-mode.md` contains `Pre-Approval Rework Prevention Gate` and `User-Observable Completion Gate`.
  - `quest-governance.md` references the preventive gate.
  - Prompt wrappers reference decision ledger, user-observable scenarios, likely objections and acceptance-to-test checks.
  - `review-loops.md` contains `Role-Based pass` and role applicability.
  - `CHANGELOG.md` contains `2.11.0`.
- Unrelated changes: none detected.
- Needs human: нет.
- Residual risks / follow-ups:
  - Future agents can still fill new tables superficially; this is mitigated but not eliminated by role-based review and no-pass wording.
  - Validator semantic checks can be promoted into script later if manual checks prove too easy to skip.

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Собрать central stack and current owner docs | 0.96 | Нет | Сформировать working spec | Нет | Нет | Задача меняет governance/template docs, поэтому применён `QUEST` SPEC gate and catalog-governance route. | `AGENTS.md`, `instructions/governance/routing-matrix.md`, `instructions/core/*`, `instructions/governance/*`, `templates/specs/_template.md` |
| SPEC | Учесть session-insights and prior QUEST analysis | 0.90 | Точные причины generic `исправь` не всегда восстановимы без deep manual read каждой сессии | Использовать агрегаты как heuristic evidence, не как абсолютный факт | Нет | Нет | Пользователь попросил анализ QUEST-сессий; session-derived context применим, но должен оставаться подсказкой. | `session-insights/*`, local JSONL aggregate analysis |
| SPEC | Создать preventive design spec | 0.94 | Нет | Запросить approval phrase | Да | Нет | Spec предлагает concrete template sections, role-based review and gates while preserving compact mode. | `specs/2026-06-11-quest-rework-prevention.md` |
| SPEC | Проверить рабочую spec стандартным quality gate | 0.98 | Нет | Передать spec пользователю на approval | Да | Нет | Validator, validator regression suite and diff whitespace check passed; no files outside working spec were changed. | `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1`, `specs/2026-06-11-quest-rework-prevention.md` |
| EXEC | Реализовать QUEST rework prevention gates | 0.95 | Нет | Запустить validators and semantic checks | Нет | Да: пользователь подтвердил spec фразой `Спеку подтверждаю` | Добавлены preventive template sections, phase gates, role-based review semantics, prompt wrapper alignment and changelog entry. | `templates/specs/_template.md`, `instructions/core/quest-mode.md`, `instructions/core/quest-governance.md`, `instructions/core/quest-prompt-spec.md`, `instructions/core/quest-prompt-exec.md`, `instructions/governance/review-loops.md`, `CHANGELOG.md` |
| EXEC | Validation and post-EXEC review | 0.98 | Нет | Завершить отчёт пользователю | Нет | Нет | Validator, validator regression suite, diff check and semantic markers passed; language finding fixed and rechecked. | `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1`, `specs/2026-06-11-quest-rework-prevention.md` |
