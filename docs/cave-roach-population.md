# Cave Roach population gap

The source has **23 definition4 `Roach` placements**, separate from definition5 actors0/23. The earlier coverage note incorrectly said24. Only actor23 currently has a reviewed playable cave encounter binding.

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

Reused `verify_hive_effective_stats.main("Roach")` verifies512 native goal/condition compositions,49 condition-row bindings and256 goal admissions. Six focused engine tests pass, covering existing Hive consumers as well as the Roach profile. Configuration copies the profile and rejects malformed updates atomically. Source perception/conditions, movement and the23-actor cave scene/save integration remain open.
