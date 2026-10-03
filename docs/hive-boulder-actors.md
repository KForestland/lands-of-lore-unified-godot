# Boulder actor integration evidence

The Hive's moving surfaces and earned approach/exit work locally. Subsequent work now attaches saved path motion and live presentation for actors30/31; see [live movement](hive-boulders-live.md). Contact effect and sound remain pending. This page records the prerequisite checkpoint. The following checks establish inputs for that integration; they do not make the encounter complete.

`verify_hive_boulder_pair.py` passes4,352 bounded native B276C cases. The original WORM definition and native getters establish radius20 and height40. The pair routine uses a strict distance threshold:20 for two type2 actors, otherwise candidate radius plus mover radius. Vertical classes2/4/5 and a clear suppression byte admit the pair and write penetration/bearing outputs. Equality at the radius threshold rejects. The Euclidean distance result, vertical-class calculation/global setup and bearing result are supplied boundaries, with helper arguments checked. Contact cadence and final damage are not established.

`verify_hive_boulder_selection.py` passes6,144 native A7D4C/A1E44 selections over all mask bytes, four modes and three supplied RNG values. The actual source table maps action0 to selector0 and action1 to selector1. This does not establish when path movement requests action1.

`verify_hive_boulder_idle.py` passes1,024 ordinary-mode terminal/busy/lookup branches and pins the action9 dispatch to A459C. With terminal context and B5bit0 clear, it requests action0 and starts the returned selector. The source selection above resolves that selector to0. Nonordinary modes, queue scheduling and the animation setter remain outside this bounded replay.

The existing WORM animation replay independently establishes terminal event3, and the source event-list replay admits groups10304/10384 only in owner state5. Those groups request action9. This is a verified chain of separate boundaries; it is not yet a composed live scheduler. Opus's path read identified A9720(actor,3,0) before path-index advancement. Lead disassembly shows this goes through6EE80; the literal3 is not evidence of a direct event3 emission. Grok's bounded globals review reached its limit without substantive findings.

The shared sprite presenter now accepts an explicit source canvas while retaining the default320×200 contract. All11 original95×78 boulder frames pass atlas selection, dimensions, bottom-anchor and invalid-frame rollback checks. Source world size/anchoring remains a presentation adapter. The presenter uses the existing shared numeric validator, so its portable test needs no game assets or native clock module.

Final focused Godot run:4/4 pass (boulder sprite, warrior attack, warrior death, Executioner sprite). The isolated publication checkout also passes synthetic320×200 and95×78 canvas tests. The newly registered Hive suite has97 tests; it has not been run in full after this presentation change. The previous surface checkpoint remains full95/96 plus corrected small-route pass.

Next: bind path action admission and pair globals, then connect the original frames and saved actor motion/contact to the already-tested surface callbacks. Preserve source spawn height−1207; do not silently ground actors150 units lower without establishing or explicitly adapting vertical movement.
