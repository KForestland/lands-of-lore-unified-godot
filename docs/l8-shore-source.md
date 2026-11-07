# L8 shore return source (STORY-027)

`tools/prepare_l8_shore_source.py --game ~/lol2_runtime_root` checks original L8 archive bytes and writes `tmp/l8_shore_source.json`. It pins five objects,47 command groups, event predicates and arrival5. The source extract is independent of the modern arrival/closure owner described below.

Arrival5 is source(-4292,1623), region66, heading30037, original record `3cef57065575420005000000` at archive offset13550213. Existing travel exports label the selector interpretation LIKELY. Its production landing convention is(-4292,48,-1623), distinct from the original record's two-dimensional coordinates.

Actor20 is original definition13 `DAWNL8`, positioned(-4252,0,-1515), initially absent. Prop630's kind6/value20/extra05 callback is stream1/group7888. It schedules prop437 event4, requests player commands, arms props630/1121/117, applies opcode9/property27 to item25, and links actor20 with `090214000300`. The extract preserves those exact commands; it does not guess their unhosted semantics. In particular, it does not grant a duplicate pair of bracers merely because item25 is mentioned.

Actor20's first callback uses predicate `0604c604bf` and group13416. Additional callbacks select conversation branches and include bracer-offer handling. Their condition meanings and original dialogue presentation are not yet qualified. Prop117's group5486 contains71 floor requests (mainly target−25); calling it the ruins flooding would be unsupported. Permanent ruin closure still needs its exact source link or an explicitly documented modern adapter and earned witness.

The predecessor flood exit is independently pinned in `docs/l9-flood-source.md`: control82 -> prop104 -> L8selector5. No saved campaign inventory has been merged, and no arrival save has been seeded for this research.

Production owner `l8_shore.gd` now binds the earned raft receipt plus actual selector5 level change to the original Dawn20 presence consequence. The shared travel owner refuses destination9 after the saved shore receipt. DEVIATIONS0247 distinguishes these adapters from unhosted native wake/dialogue/flood commands. `l8_shore_earned_test` starts with the actual completed raft save and exercises original exit timers, scene handoff, Dawn, unchanged inventory, reload, and Ruins selectors0–3 through the shared refusal gate (the gate checks destination level, independent of selector). This verifies closure at the travel boundary, not rebuilt physical pit/mirror geometry.
