# Cave Roach population gap

The source has **23 definition4 `Roach` placements**, separate from definition5 actors0/23. The earlier coverage note incorrectly said24. Actor23 has the existing playable encounter; the23 smaller placements now have partial live presentation/damage/save bindings, with AI/movement and hostile attacks still open.

`verify_cave_roach_population.py` pins the original cave archive and geometry, records all23 placements and10HP values, and executes the original constructor initialization slice. All23 begin with behavior14, action9 and B5=0. The slice does not reproduce allocation, spatial admission or later initialization.

Two region event4 groups (region1140/group996 and region1358/group1738) each address the same twelve actors:25–35 and43. Both issue property13 to all twelve, then property7 to all twelve. The original setter was executed for1,536 combinations of property, prior B5 and behavior. Property13 sets bits0C; property7 clears bit01; both clear7C. Behavior15 bypasses these changes. These are verified flag mutations, **not spawn or enable commands**.

The other eleven placements have no direct literal actor command references in either scanned stream. That does not establish inactivity or optionality. Runtime selectors, general AI and indirect effects are outside this scan.

B5 bits04/08 request pending goal/action selection, with goal chosen first; bit01 blocks both. This caller order is already covered by the existing native Hive chooser verifier. The source Roach goals/actions/effector profiles have now been bound to the shared scoring implementation. The action9 dispatcher calls A459C, whose ordinary animation-completion path requests selector lookup for action0; this disassembly lead alone is not a full movement/AI classification.

The initial goal14 exposed a concrete shared-helper gap. Native loader arguments establish contiguous goals at profile+28 (46×14), actions at+2AC (46×15), and effectors at+55E (58×30). The chooser has no goal14 clamp: its bias row lands in the first row of the next table. New native replay checks480 supplied-stat choices, including32 with goal14. The Godot helper now accepts an explicitly supplied `initial_goal_bias` row, rejects goal14 without it, and preserves atomic validation/reconfiguration. No invented zero row or goal remapping. Three focused tests pass, including existing Hive goal/action suites. See `cave-roach-ai-choice.json` and the numeric fixture.

Next implementation prerequisite: bind the source stat/condition producers and decision commits to ordinary cave gameplay, then determine which placements are reached on the ordinary route. Reuse existing cave animation/combat infrastructure when appropriate, preserving source positions and saved individual identities. Do not turn the region flag mutations into an invented spawn trigger or count the existing single duel as coverage of this population.

Reproduce locally:

```sh
PYTHONPATH=/home/bob/lol2_out/native_codec_deps:tools python3 tools/verify_cave_roach_population.py
```

The verifier depends on the local reverse-engineering toolchain and original files; neither original game media nor a standalone game build is published with the numeric report. ActOne acceptance remains open.

The shared effective-stat engine now accepts a validated per-creature profile. The condition evaluator exposes that configuration while retaining the existing Executioner default. Original Roach `stat.csv` bytes decode to unsigned actor stats (for example −106→150 and −56→200); source base stats and initial goal14 choose goal6/wander then action0 in native replay with no world-condition adjustments. This is a controlled baseline, not a claim that the player is absent or that all live roaches always wander.

Reused `verify_hive_effective_stats.main("Roach")` verifies512 native goal/condition compositions,49 condition-row bindings and256 goal admissions. Six focused engine tests pass, covering existing Hive consumers as well as the Roach profile. Configuration copies the profile and rejects malformed updates atomically. Source perception/conditions and movement remain open; scene/save presentation integration is described below.

The local cave save path now stores all23 source identities, positions,10HP values, unsigned stat banks and separate current/pending decisions. Source regions1140/1358 update the exact twelve actors with the verified property13/7 effects. Grounded polygon/foot-height contact and saved first-contact history use the existing cave contact convention; this is a modern spatial/lifetime adapter. Defeated actors skip both commands, as the native setter does. Committing a pending decision uses the existing native-verified commit helper.

The population packet has a schema marker, whole-save validation and legacy initialization. The cave save cap increased from16KB to64KB to accommodate the bounded23 actor banks; oversize rejection remains tested. Four focused headless tests pass, including actual cave-scene save/load, partial decision rollback, malformed/missing packets and legacy migration. All67 existing save-validation checks pass. Source polygons can be regenerated with `tools/prepare_cave_roach_population.py`.

The23 actors are now instantiated with source-position bodies, original indexed animation, saved damage/defeat, selected melee, basic Spark and aura targeting. Source definition4 reward scale1 is independently pinned (entrance definition5 remains2). They are stationary: live perception, AI movement/attacks, melee XP, earned cave route and rendered acceptance remain open. See [live scope and checks](cave-roach-population-live.md). This is not completed encounter coverage. Publication contains portable state/numeric data; full scene wiring remains local.

2026-10-03: population pending choices now call the existing native-verified goal scorer followed by the action scorer with the same supplied effective bank. Both must succeed before any actor changes; committing remains separate. Five focused checks pass, including a goal-success/action-failure atomicity case, initial source-bank goal6/action0, blocked/unrequested/dead/unknown actors, JSON continuation and actual cave disk rollback. This replaces literal choices in the disk test. The source-bank case is controlled, not live perception or hostile admission. Runtime perception remains open; partial visible/damageable actors are now integrated as described above. See `cave-roach-population-choice-checks.json`.
