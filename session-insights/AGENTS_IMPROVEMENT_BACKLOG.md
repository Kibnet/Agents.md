# Agents Improvement Backlog

Дата подготовки: 2026-06-05.

Источник: повторяющиеся проблемы и ожидания пользователя из Codex-сессий. Это backlog предложений, а не уже утверждённые изменения `instructions/*`. Перед внесением в центральные инструкции нужен обычный governance flow.

## P0 - Highest ROI

### 1. Add Windows PowerShell Command Safety Profile

Problem:

- Повторялись Bash heredoc, `$file:$line`, `Select-Object -Index 200..245`, broken regex quoting.

Proposal:

- Добавить профиль или контекст `windows-powershell-tooling`.
- Включить examples: Python here-string, format strings, range materialization, `rg -e` patterns.

Acceptance:

- Агент перед inline Python в PowerShell использует `@' ... '@ | python -`.
- Агент не генерирует `$file:$line`.

### 2. Add .NET/TUnit Validation Profile

Problem:

- Агент часто угадывал VSTest filters или запускал слишком широкие TUnit suites.

Proposal:

- Добавить `testing-tunit` или расширить `testing-dotnet`.
- Explicit rules:
  - detect runner first;
  - prefer repo-proven commands;
  - use `--treenode-filter` for TUnit;
  - full suite only after targeted or explicit requirement.

Acceptance:

- В TUnit repos агент сначала ищет runner model и existing commands.
- Финал явно говорит targeted/full validation scope.

### 3. Add UI Visual Evidence Gate

Problem:

- Пользователь часто возвращал UI-задачи из-за визуального качества после формально успешной сборки.

Proposal:

- Ужесточить UI-facing flow:
  - screenshot/render required unless impossible;
  - wide/narrow if responsive;
  - self-review screenshot before final;
  - final includes visual evidence.

Acceptance:

- UI-финалы содержат screenshot/render evidence или explicit blocker.

### 4. Add Repo Runbook Discovery Rule

Problem:

- Повторные ошибки в одних и тех же repo: wrong tests, wrong paths, slow suites.

Proposal:

- Перед значимыми задачами в известных repo проверять `session-insights/REPO_RUNBOOKS_FROM_SESSIONS.md` или repo-local runbook if present.

Acceptance:

- Agent uses runbook as hint, then verifies current repo state.

## P1 - Strong Improvements

### 5. GitHub Delivery Preflight

Problem:

- Duplicate PR, `gh` unauthenticated, branch/ref lock, remote permission issues.

Proposal:

- Add explicit preflight:
  - `git status --short`;
  - branch/current worktree;
  - remote access/auth;
  - existing PR check;
  - CI status check after push.

Acceptance:

- PR workflow starts with state/auth and ends with PR URL + validation.

### 6. Environment Blocker Classification

Problem:

- NuGet SSL/auth, SSH host key permission, API fetch failed were sometimes treated like code bugs.

Proposal:

- Add rule: network/auth/SSL/permission failures are environment blockers until reproduced independently.

Acceptance:

- Agent reports blocker category and next-best evidence.

### 7. Stale Patch Prevention

Problem:

- `apply_patch` failed often due stale hunks.

Proposal:

- Before patching changed/large files, read nearby context.
- After patch failure, re-read and use smaller hunk.

Acceptance:

- No repeated identical failed patch hunk.

### 8. Editable Artifact Requirement

Problem:

- Presentation/PDF tasks can accidentally drift into raster-only shortcuts.

Proposal:

- Add artifact requirement checklist:
  - editable vs raster target;
  - visual fidelity;
  - target language;
  - render verification.

Acceptance:

- Presentation/document final states whether artifact is editable and how verified.

## P2 - Useful Follow-ups

### 9. Slow Test Registry Integration

Problem:

- Agent repeatedly paid timeout costs for known slow suites.

Proposal:

- Maintain repo-local or central slow/flaky registry.
- Agent consults it before broad test runs.

Acceptance:

- For known slow suite, agent starts targeted and reports why.

### 10. Secret Diff Guard

Problem:

- Many bot/API/deploy tasks involve tokens/configs.

Proposal:

- Before commit/PR in repos with bots/API/config, run secret heuristic over staged diff.

Acceptance:

- Final says secret-sensitive diff was checked when applicable.

### 11. Russian Language Consistency Rule

Problem:

- User repeatedly asked for Russian docs/UI/comment consistency.

Proposal:

- Strengthen instruction to detect repo language for comments/docs/UI and keep it consistent.

Acceptance:

- Agent does not introduce mixed Russian/English prose unless term is technical.

### 12. Session-Derived Command Cookbook

Problem:

- Useful commands are hidden in session history.

Proposal:

- Consolidate successful commands into repo-local runbooks or central session insights.

Acceptance:

- Known repo tasks reuse proven commands after current-state verification.

## Candidate Instruction Locations

Potential owner docs to update, depending on final design:

- `instructions/contexts/testing-dotnet.md` - TUnit/VSTest detection and command strategy.
- `instructions/contexts/testing-frontend.md` or UI profile - visual evidence gate.
- `instructions/profiles/dotnet-desktop-client.md` - Avalonia UI/headless/screenshot expectations.
- `instructions/governance/github-delivery-policy.md` - delivery preflight.
- `instructions/core/model-behavior-baseline.md` - environment blocker classification and visual evidence wording.
- New profile/context for Windows PowerShell command safety, if central stack supports it cleanly.

## Risks

- Do not overfit central instructions to one repo.
- Avoid duplicating existing owner docs.
- Treat session-derived insights as heuristics, not mandatory rules unless promoted through governance.
- Keep central instructions concise; detailed examples can live in profiles/runbooks.
