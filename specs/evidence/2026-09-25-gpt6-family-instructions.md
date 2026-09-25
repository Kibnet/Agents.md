# Evidence: GPT-6 family instruction update

Дата: 2026-09-25. Approved SPEC: `specs/2026-09-25-gpt6-family-instructions.md` в активном checkout. Candidate: isolated worktree от `9c63f4de6c2d7a54825e7fcf839a6046087f9fcb`.

## Официальные источники

- https://developers.openai.com/api/docs/guides/latest-model
- https://developers.openai.com/api/docs/models/gpt-6-sol
- https://developers.openai.com/api/docs/models/gpt-6-luna
- https://developers.openai.com/api/docs/guides/reasoning
- https://developers.openai.com/api/docs/guides/your-data
- https://learn.chatgpt.com/docs/models
- https://learn.chatgpt.com/docs/model-selection

Проверены факты: семейство Astra/Sol/Luna; Sol/Luna efforts `none,low,medium,high,xhigh,max` и default `medium`; Chat Completions function calling только при `none`; Responses для reasoning с tools; sampling/logprobs restrictions при effort != `none`; EU Standard processing; product availability не переносится из API без проверки поверхности.

## Static и regression evidence

| Проверка | Результат candidate |
| --- | --- |
| `scripts/validate-instructions.ps1` | PASS; 37 static outcome guards |
| `scripts/test-validate-instructions.ps1` | PASS после EU exact-tier изменения: 43 catalog assertions, 37/57 outcome guards/mutations, 319 operations assertions; checks 96, failures 0 |
| `scripts/fixtures/outcome-contracts/test_runtime.py` | PASS; 13 tests, включая JSON snapshot, traversal, unsafe `caseId` и symlink/reparse escape |
| STORM unittest | PASS; 15 tests |
| `git diff --check` | PASS; только line-ending warnings |

## Behavioral smoke

Privacy-safe durable evidence сохранено в `specs/evidence/2026-09-25-gpt6-family-instructions/behavioral-smoke.json`: полные prompts и final answers, bundle/case/tool hashes, sanitized effective runtime и verdict каждой пары. Raw protocol traces находятся в ignored `.artifacts/evals/agent-operations-gpt6-family-20260925/`; auth, thread IDs, абсолютные пользовательские пути и protocol noise в durable pack не копировались. Preflight подтвердил Codex App Server stdio `0.154.0`, `gpt-6-astra`, effort `high`, no fallback, read-only, no network, `environments=[]`, approval never и разрешённый virtual read/write read-back. User config и auth не копировались и не менялись.

Полный paired run: 11 baseline + 11 candidate executions. `audit_pairs.py` вернул `valid`, 11 cases, 0 provenance failures. Candidate во всех API cases G04–G10 читал `catalog/schemas/openai-api-model-contract.json` через virtual backend. Oracle модели не передавался.

| Case | Контракт | Baseline | Candidate | Evidence |
| --- | --- | --- | --- | --- |
| G01 | Astra для сложного исследования, availability/eval boundary | PASS | PASS | Ответы + tool trace |
| G02 | Luna для проверяемого batch, escalation/cost per success | PASS | PASS | Ответы + tool trace |
| G03 | Явный GPT-5.6 Terra pin | PASS | PASS | `router.json` неизменён |
| G04 | Sol high + Chat tools → Responses | FAIL: Sol отсутствует, предложена Astra | PASS | machine JSON read |
| G05 | Sol none Chat function exception | FAIL: контракт отсутствует | PASS | machine JSON read |
| G06 | Astra none и Luna minimal → low | FAIL: Luna контракт отсутствует | PASS | machine JSON read |
| G07 | API не доказывает Codex availability | PASS | PASS | Ответы |
| G08 | EU Standard для Astra/Sol/Luna | FAIL: Sol/Luna не подтверждены | PASS | machine JSON read |
| G09 | Conditional sampling/logprobs | FAIL: Luna контракт отсутствует | PASS | machine JSON read |
| G10 | GPT-6 configuration_update standard single-agent | FAIL: Astra-only | PASS | owner + machine JSON read |
| G11 | Инициатива сохраняется, exact QUEST gate сохраняется | PASS | PASS | Ответы + отсутствие mutations |

Baseline: 5 PASS / 6 FAIL. Candidate: 11 PASS / 0 FAIL по ручному oracle review основного агента. После уточнения `euRequiredServiceTier: "default"` адресно повторён G08 candidate: scoped provenance audit `valid`, 0 failures; ответ сохранил PASS и сослался на обновлённый JSON. Это уточнение не меняло остальные scenarios.

Ограничение: provenance audit проверяет request frames, hashes, runtime identity и полноту, но не выставляет semantic verdict. Semantic PASS основан на ручном сопоставлении raw ответов/tool traces/workspace-final с reviewer-only oracle. Отдельный adversarial reviewer подтвердил verdicts, но его sandbox был writable/unrestricted; он работал read-only по дисциплине, поэтому этот проход не считается технически независимым read-only evidence. Residual risk фиксируется в SPEC.

## Activation boundary

Active path `C:\Projects\My\Agents` и junction `C:\Users\Kibnet\.codex\agents` подтверждены после применения. HEAD перед активацией остался `9c63f4de6c2d7a54825e7fcf839a6046087f9fcb`; единственным прежним dirty-файлом была эта утверждённая SPEC. Allowlist содержит 39 candidate files. Canonical LF SHA-256 всех 39 postimages совпал; byte-level различие существующих файлов ограничено CRLF/LF и подтверждено `git diff --check` без ошибок.

Active validation: `validate-instructions.ps1` PASS; `test-validate-instructions.ps1` PASS, 43 catalog assertions, 37/57 guards/mutations, 318 operations assertions, 96 checks / 0 failures; runtime unit tests 13/13; JSON parse/exact conditional fields PASS; `git diff --check` PASS с line-ending warnings. Candidate post-EXEC re-review — PASS. Reviewer sandbox был writable/unrestricted и потому не считается технически независимым read-only evidence; основной агент выполнил adversarial fallback и сверку active scope/hashes.
