# Regression progress and live logs

The existing tools/run_regressions.py now writes each test log as subprocess output arrives. During a test, report.json exposes current_test with name, index, headless/rendered mode, UTC start, timeout_seconds and relative log path. Completed tests remain in tests; current_test becomes null after completion. Atomic report replacement remains unchanged.

Use the active log to investigate a slow check without waiting for its timeout. No output is not proof of a hang: the game may be doing work without printing. If the runner is interrupted, current_test identifies its last active test; it is not a process-liveness guarantee.

Pass/fail, error classification, process-group timeouts and source-stability semantics are unchanged. Existing direct run_one callers need no change; the optional fourth argument enables live output. A child must flush its own output for prompt delivery. Final logs retain the existing decoded text format.

Validation: nine Python runner/source tests, including output visible before child exit and timeout preservation; real Godot portable smoke PASS/source-stable. This is a tooling-only change after R16; R16 artifacts and personal saves are unchanged.
