# GPT-6.1 contract migration fixtures

Восемь пар baseline/candidate проверяют exact IDs/efforts, совместимость старого Sol, schema-2 EU modes/tiers, Ultrafast, Responses multi-agent beta, product pins, sampling и retirement/vision reevaluation.

Cases доступны модели через inert virtual tools; oracles доступны только reviewer. Runtime — reviewed CLI 0.160.0, gpt-6-astra/high в обеих фазах, read-only/no-network, environments пусты. Адаптация каталога не меняет модель, которой выполняется smoke.

Пример из корня candidate:

```powershell
pwsh -File scripts/run-outcome-behavioral-smoke.ps1 -BaselineRoot <active> -CandidateRoot <candidate> -FixtureRoot scripts/fixtures/gpt61-contracts -OutputDirectory .artifacts/evals/agent-operations-gpt61-contracts -Preflight
pwsh -File scripts/run-outcome-behavioral-smoke.ps1 -BaselineRoot <active> -CandidateRoot <candidate> -FixtureRoot scripts/fixtures/gpt61-contracts -OutputDirectory .artifacts/evals/agent-operations-gpt61-contracts
python scripts/fixtures/outcome-contracts/audit_pairs.py --baseline <active> --candidate <candidate> --fixtures scripts/fixtures/gpt61-contracts --output .artifacts/evals/agent-operations-gpt61-contracts
```

Audit подтверждает snapshots/runtime/prompts/tool schemas/полноту 16 slots, но не semantic PASS. Reviewer читает expected и forbidden, exact ответы и tool traces. N08 имеет две обязательные части: product/API retirement boundary и отдельная visual reevaluation. Historical gpt6-family pack сохраняет прежние schema-1 ожидания.
