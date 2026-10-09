# Unlimotion outcomes: virtual paired smoke

S1 covers multiparent/shared/cycle/missing context, S2 read-only artifact, S3 authorized done and unfinished lifecycle, S4 semantic parent proposal, S5 consultation and unavailable source. Inputs are sanitized; separate oracles are excluded from model snapshots. Static guards do not prove model behavior. A virtual action observation does not prove a real CLI mutation. Run the installed CLI suite separately.

Use run-outcome-behavioral-smoke.ps1 with this FixtureRoot. Runtime case filter uses expanded keys S1-base,S2-base,S3-done,S3-unfinished,S4-base,S5-consultation,S5-source-failure. Review answers, operation params, traces and artifacts, not successful execution alone.

S3 uses stateful virtual `writeFiles` and `resultFile` observations. Before claim, authoritative readback is Prepared without a lease; claim makes it InProgress with lease-demo, result preserves InProgress, complete makes it Completed. All state changes are recorded as virtual mutations. This optional backend extension has boundary tests; host files remain inaccessible. Old S3 static/two-state runs are superseded evidence, not passing lifecycle coverage.
