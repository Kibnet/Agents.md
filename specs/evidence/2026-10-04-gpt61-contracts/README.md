# GPT-6.1 contract migration evidence

Активировано29files; canonical postimages29/29 совпали, byte19/29 (остальные EOL-only). Пользователь явно разрешил «Активировать с исключением для hooks»; общий governance не изменён. Active static/runtime14/test-validate(-SkipAgentOperations)/diffcheck PASS; STORM37, Analyzer77 и installer remediation96 PASS. Полный operational suite остаётся FAIL и не объявляется green.

- [SPEC](../../2026-10-04-gpt61-contracts.md)
- [Per-case verdicts](verdicts.json): candidate8/8 PASS, baseline1/8 coverage, N07partial.
- [Full paired inputs/answers/runtime](paired-responses.json):16slots, exact final_answer, observations hashes; no credentials.
- [Provenance audit](pair-audit.json): valid8cases/16executions/0failures; semantic grading separate.
- [Snapshot sources](snapshot-sources.json): immutable baseline/candidate SHA-256.
- [Checks and blocker](validation.json): static/runtime/STORM PASS; operational FAIL и canonicalLF equality источников.
- [Prepared activation](activation-manifest.json):29file pre/postimages.
- [Actual activation](activation-result.json): canonical/raw matches и фактические byte postimages для безопасного rollback.
- [Baseline metadata characterization](baseline-characterization.json): expected red перед authoring.

Runtime: CLI0.160.0, gpt-6-astra/high/default, readOnly/noNetwork, пустые environments в обеих фазах. Model отвечает только через inert virtual tools; реальные API requests/плановые account switches этим smoke не проверены.

Raw local archive: `.artifacts/evals/agent-operations-gpt61-20261004/`, gitignored по существующему правилу. После16executions архив перенесён из прежнего имени без изменения bytes, затем audit выполнен успешно. Исторический recorded cwd не переписан. Raw account/transport data не включены в durable JSON; сохранены только их hashes и relevant runtime.

Отдельный reviewer работал procedural read-only при danger-full-access; technical independent isolation не утверждается. Audit также фиксирует отсутствие per-process backend source hash: frozen runner source и review дополняют provenance, но не являются cryptographic proof каждого процесса.

PowerShell: empty process4993ms; child-only telemetry-optout experiment7282ms не помог, global env не изменён. Baseline Hooks воспроизводит hook timeout/dedup/native failures. Installer missing telemetry наблюдался в candidate All runs после запуска installed hook (test479) и чтения его telemetry (481); baseline Hooks проверяет только hooks. Privacy остановился после такого же telemetry prerequisite (1374). Последующие общие Installer/Privacy assertions не исполнены. Standalone installer remediation96 PASS восстанавливает только собственное покрытие. Hooks не менялись логически:4 canonicalLF hashes совпадают,3 raw files отличаются CRLF/LF. Полный operational gate остаётся FAIL; для этой активации принят явный task-scoped user exception. Корректный installer supplementary run использовал system TEMP; worktree-root запуск был отвергнут SimulationCommitReadyPath guard.
