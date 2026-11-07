# One-command project verification

Run from the project root:

```sh
python3 tools/verify_project.py --profile quick
python3 tools/verify_project.py --profile diagnostics
python3 tools/verify_project.py --profile continuity
python3 tools/verify_project.py --profile recovery
python3 tools/verify_project.py --profile all
```

`quick` checks portable combat plus the player-continuity contract. `diagnostics` checks the component and four real hosts. `continuity` runs 12 checks: contracts, Cave→Museum→Jungle chain and restart, Cave transfer gate, Hive route/return/restart, room return/restart, doorway loading and read-only observation. Restart checks run after their matching save-producing checks in the existing runner order. `all` runs every registered source regression. These profiles reuse the existing runner and private-display behavior. By default they run source checks only; no profile runs the earned campaign or certifies a release.

Each invocation gets a fresh timestamped `tmp/verification/` directory. `--out PATH` selects a fresh directory; existing directories are refused to preserve prior evidence. `--list` lists profile tests without running them. `--timeout SECONDS` controls the existing per-test deadline.

`recovery` checks production F5/death/R/F9 behavior in all four areas. It requires `LOL2_ORIGINAL_GAME_EXE` pointing to the supported original executable and `LOL2_RECOVERY_SAVES` pointing to an earned save archive (`LOL2_EARNED_SAVES` is the fallback). Use a disposable project with isolated userdata: these checks replace its per-area quicksaves. The `all` profile includes these cases and needs the same inputs. See [death/recovery scope](death-recovery.md) for required save names, supplied death triggers and comparison limits. The lead's four-host run used R16 saves; compatibility tests can independently use R13 via `LOL2_EARNED_SAVES`.

For a separately run fresh campaign in an isolated project, set `LOL2_CHAIN_SAVES` to that run's actual userdata `tests/` directory when invoking either chain auditor. Both auditors use this override; an explicitly empty value is rejected. Without it, historical local audit behavior is retained. This selects evidence to audit; it does not move saves or alter the game's userdata. Keep compatibility input archives (`LOL2_EARNED_SAVES`/`LOL2_RECOVERY_SAVES`) separate from the newly produced campaign saves.

Read progress without starting or repeating tests:

```sh
python3 tools/verify_project.py --status tmp/verification/RUN_DIRECTORY
```

The status command reports completed tests, the last recorded active test, elapsed time, timeout, live log and failures. It reads saved evidence; it does not establish whether an interrupted process is still alive. Existing `LOL2_EARNED_SAVES` configuration is forwarded for archived-save coverage; checkpoints remain supplied fixtures where documented by each test.

`verification.json` records running/passed/failed/interrupted status and links implicitly to `regressions/report.json` and per-test logs. A successful exit requires the expected ordered test list, complete successful results, and stable source snapshots matching the wrapper's starting source. Runner failure, absent/incomplete reports and source drift fail the command. Regression/source snapshot scope remains defined by `regression_source.py`; it is not a hash of original media or personal saves.

Validation: four wrapper tests (including fail-closed evidence checks, read-only status and old-output preservation), quick2 and rendered diagnostics2 PASS on unchanged source. Existing runner behavior is reused without changing game code or R16 binaries.

## Optional development build

```sh
python3 tools/verify_project.py --profile quick --build --templates /path/to/export/templates
```

Supply the existing `linux_release.x86_64` and `windows_release_x86_64.exe` templates. Prepared original media must already be present. After all selected tests pass, the command reuses `prepare_standalone_demo.py` and `verify_demo_stage.py`, then invokes the existing Linux and Windows Godot export presets through Flatpak. It creates a fresh `build/` inside that verification run, keeping every prior candidate intact.

Staging includes `PLAYER_GUIDE.md` with controls, save locations and named limitations. Its source and packaged hashes are checked along with the build inputs and recorded in the stage manifest's `package_docs`. Candidate-specific build identifiers and qualification results still belong in the candidate README; the guide does not certify a release.

Build inputs are hashed before tests, checked again before and after staging, and checked after exports. This includes prepared media, templates, regression source and the build orchestration tools. The staged project and export presets are independently rechecked after export. Both executables and nonempty PCKs are required; the platform packs must have identical hashes. `build/SHA256SUMS` records the four outputs. A nonzero command exit, an engine error, missing output or input drift fails the command. A failed regression never starts staging.

`--status` also lists each build step and its log. `build_logs/` retains complete command output, including failures. `--build-timeout SECONDS` bounds each staging/export command (default 900 seconds); the owned process group is killed on timeout or interruption. Failed output is retained and must not be reused as a fresh run.

A passed development build proves only the selected tests, staged input linkage and exports. Packed-asset auditing, actual packaged gameplay/save checks, the earned campaign, native Windows execution and owner acceptance are separate release requirements. A quick-profile build does not imply the full regression suite passed.


## Archived boulder-branch input

The earned boulder-contact regression loads the existing encounter checkpoint described by `docs/hive-unfold-earned-fight-checks.json`. In disposable userdata, set `LOL2_BOULDER_EARNED_SAVE` to an archived copy of `act1_unfold_earned_defeated.json`. The test still requires the exact `output_sha256` in that proof before loading; an empty override or mismatched file fails. Without the override, the historical `user://tests/...` path remains for existing local runs. This is a reused earned branch checkpoint, not a fresh campaign leg. Preserve its proof and file together; do not substitute generated state or disable the hash check.

The scenic-guard, monastery and weapon-shop capture checks now create their own output directories, so they can run in a fresh workspace. Errors remain test failures.
