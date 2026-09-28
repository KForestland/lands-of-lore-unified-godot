# Cave Roach population gap

The source has **23 definition4 `Roach` placements**, separate from definition5 actors0/23. The earlier coverage note incorrectly said24. Only actor23 currently has a reviewed playable cave encounter binding.

`verify_cave_roach_population.py` pins the original cave archive and geometry, records all23 placements and10HP values, and executes the original constructor initialization slice. All23 begin with behavior14, action9 and B5=0. The slice does not reproduce allocation, spatial admission or later initialization.

Two region event4 groups (region1140/group996 and region1358/group1738) each address the same twelve actors:25–35 and43. Both issue property13 to all twelve, then property7 to all twelve. The original setter was executed for1,536 combinations of property, prior B5 and behavior. Property13 sets bits0C; property7 clears bit01; both clear7C. Behavior15 bypasses these changes. These are verified flag mutations, **not spawn or enable commands**.

The other eleven placements have no direct literal actor command references in either scanned stream. That does not establish inactivity or optionality. Runtime selectors, general AI and indirect effects are outside this scan.

Next implementation prerequisite: bind behavior14/action9 and B5 bits0C to their observable actor behavior, then determine which placements are reached on the ordinary cave route. Reuse existing cave animation/combat infrastructure when appropriate, preserving source positions and saved individual identities. Do not turn the region flag mutations into an invented spawn trigger or count the existing single duel as coverage of this population.

Reproduce locally:

```sh
PYTHONPATH=/home/bob/lol2_out/native_codec_deps:tools python3 tools/verify_cave_roach_population.py
```

The verifier depends on the local reverse-engineering toolchain and original files; neither original game media nor a standalone game build is published with the numeric report. ActOne acceptance remains open.
