# Model control boundaries

R01–R03 separate a fixed chat model, an authorized child selector with requested/effective mismatch, and an authorized API request model. Cases and reviewer oracles are separate; run both snapshots on the identical pinned runtime through [runtime.py](../outcome-contracts/runtime.py) and verify provenance with [audit_pairs.py](../outcome-contracts/audit_pairs.py).

Virtual case model metadata is distinct from actual smoke model gpt-6-astra/high. Inert launch_child does not spawn a real child or contact an API. PASS covers instruction behavior and virtual artifacts only. Real routing needs actual launch metadata and separate evidence.
