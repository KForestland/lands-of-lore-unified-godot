# One-command project verification

Run from the project root:

```sh
python3 tools/verify_project.py --profile quick
python3 tools/verify_project.py --profile diagnostics
python3 tools/verify_project.py --profile continuity
python3 tools/verify_project.py --profile all
```

`quick` checks portable combat plus the player-continuity contract. `diagnostics` checks the component and four real hosts. `continuity` runs the contract, Cave→Museum→Jungle chain, new-process restart, Cave transfer gate and Hive route. `all` runs every registered source regression. These profiles reuse the existing runner and private-display behavior. They do not build exports, run the earned campaign or certify a release.

Each invocation gets a fresh timestamped `tmp/verification/` directory. `--out PATH` selects a fresh directory; existing directories are refused to preserve prior evidence. `--list` lists profile tests without running them. `--timeout SECONDS` controls the existing per-test deadline.

Read progress without starting or repeating tests:

```sh
python3 tools/verify_project.py --status tmp/verification/RUN_DIRECTORY
```

The status command reports completed tests, the last recorded active test, elapsed time, timeout, live log and failures. It reads saved evidence; it does not establish whether an interrupted process is still alive. Existing `LOL2_EARNED_SAVES` configuration is forwarded for archived-save coverage; checkpoints remain supplied fixtures where documented by each test.

`verification.json` records running/passed/failed/interrupted status and links implicitly to `regressions/report.json` and per-test logs. A successful exit requires the expected ordered test list, complete successful results, and stable source snapshots matching the wrapper's starting source. Runner failure, absent/incomplete reports and source drift fail the command. Regression/source snapshot scope remains defined by `regression_source.py`; it is not a hash of original media or personal saves.

Validation: four wrapper tests (including fail-closed evidence checks, read-only status and old-output preservation), quick2 and rendered diagnostics2 PASS on unchanged source. Existing runner behavior is reused without changing game code or R16 binaries.
