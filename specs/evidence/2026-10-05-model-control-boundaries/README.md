# Model control boundary clarification — 2026-10-05

[Approved SPEC and clarification](../../2026-10-04-gpt61-contracts.md). Candidate final semantic3/3; baseline/initial candidate2/3. HIGH/R01 source-attribution error and original FAIL retained. No automatic router or user settings changes.

- [Verdicts](verdicts.json): per-case oracle review and reviewer sandbox disclosure.
- [Paired responses](paired-responses.json): all9 executed prompts/answers, actions and runtime metadata. Repeated catalog read content represented by hashes; full observations stay in local raw tool-trace files.
- [Final provenance](pair-audit.json):3cases/6 paired executions/0failures, baseline traces reused unchanged.
- [Initial provenance](initial-pair-audit.json): captured before metadata fix; historical snapshot, not current candidate acceptance.
- [Activation manifest](activation-manifest.json):13files and exact rollback preimages.
- [Actual activation](activation-result.json):13/13 canonical matches;9/13 byte matches,4 EOL-only. Rollback uses actual raw postimages.
- [Validation](validation.json): full candidate suite exit0/319 operational assertions, installer96/telemetry136, static guards, runtime14/STORM37, and activation state.
- [Command proof](command-proof.txt): actual log excerpts for full suite, three new negative mutations and active static validation.

Runtime: CLI0.160.0/Astra/high/readOnly/noNetwork, environments empty. Virtual model names are scenario data, distinct from actual smoke model. This verifies instruction behavior and virtual actions; it does not establish live root/child routing or API execution. Procedural read-only reviewer had danger-full-access; no technical independent isolation claim.

Raw local archive: candidate `.artifacts/evals/agent-operations-model-boundaries-20261005/` (gitignored). The mixed-validator baseline full-suite attempt is discarded as comparison; exact three-guard before-negative check is valid. Current candidate full operational suite passed without a hooks exception.
