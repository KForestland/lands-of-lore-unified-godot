# G02 rendered input staging (R109)

The reviewed head 2600e70 remains unchanged. The integration candidate commits `tests/fixtures/generic_l10_inputs_manifest.json`. It lists all 24 ignored `tmp/*.json` inputs, their SHA-256 digests, byte sizes, consumers and canonical published paths under this handoff's `test_inputs/`. These are unchanged game-written saves or a read-only planning graph; the manifest does not turn a continuation into a fresh sitting. The per-test registry retains source-site aid disclosures.

Use the destination branch's normal stager, from any prepared donor (including lol2_r18); its donor need not contain the Sol input files:

```sh
python3 tools/prepare_lane_worktree.py /absolute/path/to/new-worktree --from ~/opus_work/lol2_r18
python3 tools/stage_worktree.py /absolute/path/to/new-worktree --check
```

Required pins are checked before any copying, take precedence over mutable donor outputs of the same name, and are included as `pinned_test_input` in `tmp/staged_inputs/manifest.json`. A missing/changed published artifact fails staging clearly. A conflicting destination save is preserved and staging refuses it.

Public archive: `G02_TEST_INPUTS.tar.gz`, SHA-256 `086e557263839e6ea30e983e74deddd57baf9cebfd6b5a2592251d4fd17b37ee`. `G02_INPUTS_MANIFEST.json` is the external copy of the committed fixture. Keep the canonical paths in the manifest when restoring the archive elsewhere on this machine. No original media or generated graphics are added to Git. Existing static assembly/map media continues through the normal prepared-media staging path. The standard r19 donor predates the pilot selector export: if `assets/lol2/generated/generic_props/manifest.json` is absent, run this existing producer from the destination worktree before the gates:

```sh
python3 tools/prepare_generic_prop_media.py --game ~/lol2_runtime_root --output assets/lol2/generated/generic_props
```

The producer requires a fresh output folder and the player's original game; do not replace existing media blindly. `SELECTOR_PRODUCER_PROOF.json` records a fresh regeneration of all356outputs, each hash-identical to the qualified selector media. Alternatively use the qualified integration candidate as donor, which stages these ordinary generated files too.

Proof: 12 Python staging tests PASS; `PUBLIC_INPUTS_PROOF.txt` proves actual copy and hash verification of all 24 public inputs into a temporary project with no lane-specific donor inputs. This is staging proof, not a claim that all rendered tests ran. Runtime gate reports are listed separately.


## Targeted runtime gates

From the prepared destination, set `LOL2_ORIGINAL_GAME_EXE` to the original `LOLG.EXE`. Use the private Xvfb/guarded launcher already supplied by the lane. Keep Dummy audio, at most two Sol engines/six globally and at least10GiB MemAvailable before each launch. Never edit/checkout a gate's worktree while it runs.

- `generic_mover_contact_test`: physics-only support/crush/sweep admission.
- `generic_l10_table_input_test`: rendered supplied-vantage components, including pit52carry, lids85/109/117, cover5zero-life art and Emperor E boxes. Its aids are declared; not earned walking.
- `generic_l10_supply_sitting_test`: realF9 continuation, walking to67, actualE contact pause/look-away label, same blocked-motion F5/F9, actual heldC and E56/8.
- `generic_l10_lid117_earned_test`: earned continuation via socket99/door100, realWto east stand and realE117.
- `generic_l10_shelf_earned_test`: run once with `LOL2_SHELF_GROUP=gold91`, once with `LOL2_SHELF_GROUP=supply87`. These are unchanged earnedF5continuations; all new walking/strikes/pickups are input. Gold91 includes heldC for the dagger below a height20ceiling; all16requested pickups must be collected.
- `generic_l10_saved_bounds_test`: rendered larger-old-table compatibility fixture and realF5/freshF9; explicit state/pose aids, not an earned route.
- `generic_l10_full_sitting_test`: fresh actualF2start and the full original v4 route. No external checkpoint installation in its main. Ordinary1/60clock, same-sitting F5/F9, Emperor125/126/127 each realW/E with occupied-slot assertions. Allow the long timeout used by the qualification report; do not substitute a continuation result.

Use `tools/run_isolated_regressions.py --suite core --test NAME --timeout SECONDS --out NEW_ABSOLUTE_EVIDENCE_DIR --godot python3 ~/AI_COMMS/sol_lane/task3_20261109/guarded_godot.py`, supplying `--xvfb` if needed. The runner records exact selected tests, inputs, timing and source stability. Component screenshots and actual walk traces are in each worktree's private staged `user://tests`; archive them after the report closes and before a repeat overwrites that test's output.


## Owner r19f follow-up (13 November)

Two new rendered gates use committed, SHA-pinned game-written fixtures, so they add no ignored input dependency:

- `generic_l10_owner_rail_test`: the exact owner rail174 F10, then an unchanged F5 from the qualified fresh v4 at the blue charger. Actual W+Space, without Shift/Ctrl, clears74/174; the unchanged stairs, blue154, priest and urn follow. Normal walking approaches the rail before takeoff; the old sprint stand80away is not a walking-speed takeoff. Allow1800seconds.
- `generic_l10_owner_grounded_approach_test`: actualF9 from the owner's `ok here` bundle01:26:02, then his recorded keys and mouse motion from the fall recording. Report UI keys are omitted. The player stays on valid ground with named source walls9150/9179. An8-high read-only component query verifies the preserved35..45 aperture and solid45..100 upper band. Allow300seconds.

The earlier pre-fall snapshot is already above the native ceiling and beyond the new wall. The lead explicitly excludes it as a recovery target; no saved position is reseated. The current complete boundary packet contains3532keys, with exactly these two additions to the previously qualified3530. `tools/prepare_l10_boundary_packet.py --check` enforces the named face/key/map pins. Original362selection, geometry and terrain bytes remain unchanged. The shared packet and map gates assert the complete count and one body.

The new owner fixtures retain their original `adapter_exit_seeds=true` option; this is disclosed continuation evidence, distinct from the fresh-v4 main that installs no external checkpoint. Old full-sitting results and targeted follow-up results remain separate reports.


## Rail75 follow-up

`generic_l10_rail75_input_test` walks from the unchanged pinned fresh-v4 two-blue F5 up the original source stairs to the third reachable lower rail at(-408,-3434). W+Space clears it without sprint or crouch; the reverse plain jump remains refused and actual F5/F9 clears transient passage. All three lower rails now use this ordinary high-to-low jump rule. Return through the existing stairs/loop, not a reverse jump. This is a disclosed earned-checkpoint continuation, not a new whole sitting; normal aura casts on the approach remain real input. Allow900seconds. Run beside `l10_fence_earned_test` and `act2_journal_hints_test`.


## Whole-suite reproducibility (13 November)

The24published inputs now install under `tmp/generic_l10_inputs/`. Their bytes/SHA256 pins and public source artifacts are unchanged. Legacy earned tests write the old `tmp/*_earned_save.json` names; those outputs must not overwrite the pilot's immutable component/continuation inputs. New worktrees use the normal stager. Existing prepared worktrees may copy only these private aliases from the committed pinned-input manifest after their gate closes; preserve any different existing alias rather than overwrite it.

The committed `tests/fixtures/generic_prop_media_manifest.json` pins the original producer's356outputs plus its manifest SHA256945eaf8a887f63f80b67874089c772ebdd46c5ce65d18887221b0fda8c9597d1. `stage_worktree` validates every output and, if the donor predates the pack, chains the existing `prepare_generic_prop_media.py` from the player's `LOL2_ORIGINAL_GAME_EXE` folder (workspace default `~/lol2_runtime_root/LOLG.EXE`). Partial or changed packs are preserved and refused. No original images are added to Git. The32Python checks include the actual runner budget wiring, immutable-alias survival and media refusal/producer cases; a fresh actual producer chain reproduced all356outputs and the manifest byte-for-byte. Source-only portable runner environments do not acquire a graphics dependency; full-worktree stage/check remains strict.

`start_from_f2` resets only its own private test gate configuration before opening the real F2 list. The stager copies private test settings but no personal player slots; a remembered executable could otherwise auto-start Cave before the test sentF2. The new setup is counted explicitly as a source-site context, with no game behavior or personal settings change.

Two registry budgets now override a shorter default: full sitting14400seconds (observed10214.44) and ashes/ankh5400(observed3372.88). The runner records each effective budget and rejects invalid metadata. The13November lead explicitly permits retaining the full3033c3dPASS when the L10 set and targeted fence/oil gates pass; no new full-sitting result is claimed by these harness fixes.

Legacy test pin reasons: L10 now hosts76hinges (20old +56decoded click-bit movers); its exact excluded-face union includes168generic-cover faces and534gargoyle/glow faces, for1616total. No terrain rule or source pin is loosened. The old crypt83 test assumed an empty event list meant no use; it now checks the decoded actualE movement. The old globe55 east ray hits its physical lid51; actualE opens51, and heldC plus E from the exposed south floor takes the globe without relaxing line-of-sight. That remains a disclosed component-vantage test, not an earned route.


### Area-owner and F-08 fixture closure (2026-11-13)

The follow-up to `92df963` changes tests and fixtures only. Each former failure has an explicit reason:

- `area_owner_catalog_test`: the captured legacy declaration list already contains OF6 `l10_globe_door.gd`. The 415 overlay must not insert a second copy before the pilot replaces exactly one with GenericObjects. The total remains 116, and duplicates or a differing existing declaration still fail.
- `area_owner_validation_test`: GenericObjects contributes the 77th distinct quest validator. Assert its `generic_objects` key explicitly while retaining every malformed-key refusal and legacy-save check.
- `item_grant_census_test`: the unchanged carried-item readers in chargers, Emperor sockets and tomb sockets moved from `_unhandled_input` into `try_use` for common E/left-click dispatch. Retain the input functions as empty-site readers and pin the moved sites. The new boundary admission callback and selector-media `node.pack` assignment are conservative geometry/media matches, explicitly classified and source-hashed; neither grants an item. All 24 history spellings and original golden-save pins remain unchanged. Runtime-baseline hash updates follow only reviewed fixture bytes; the pre-existing integration L14 `player.region` baseline change also needs its census hash synchronized.
- `item_grant_host_save_test`: the L10 writer and fresh loader now include initialized `generic_objects` world state. Reproduce that through the existing production grants/writer/loader; preserve every pre-existing inventory, history and owner value. Update the L10 post-grant packet and loaded records, including legacy loaded records, with their manifest and census pins. These are component saves, not earned playtest starts.

The Sol branch predates the F-08 integration. Its refreshed F-08 data files therefore appear as additions relative to that parent; on integration they update existing fixtures. Review the candidate-relative patch and change inventory supplied in the handoff. No F-08 gameplay module is imported into this branch.
