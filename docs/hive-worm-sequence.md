# Hive worm sequence: verified source behavior

WORM actors30/31 are an unresolved scripted encounter, not an ordinary HIVEW population. Both source placements request1000 health and generic construction preserves flags0x582/state0. This does not establish their complete derived startup or playable behavior. No worm gameplay has been added yet.

The source sequence is now bounded more precisely:

1. Region1216's kind12/event2 record names stream0 group6778, with no attached predicate. That group requests region794 ceiling target−1387 (flags1, speed50) and a prop234 sound command. The record and command bytes are pinned; full event2 admission is not replayed by the new verifier.
2. Native surface completion emits event7 for a completed ceiling movement whose supplied direction is nonpositive. The actual kind11 record targets region794 and dispatches group6250. Region793 shares descriptor68 but does not match that record. This resolves the apparent descriptor/region mismatch in Opus's static report.
3. Group6250 requests floors1217/1218→−1670 and1216→−1700, then actor31/30 operation3 and operation21. Operation21 is verified to request actor event20 through the virtual event-list getter. The two original worm event lists each queue two groups on event20.
4. Native nonpositive floor completion emits event5. Region1216's kind11 record dispatches group6806, which writes worm state5 and requests region801 target100 with flags9, plus a prop77 sound command. Full flag9 movement semantics remain outside this new proof.
5. With state5, worm event3 queues its follow-up group; other states reject it. Separate kind5 records attach predicate206 (owner state0) and command19. The native command builder forms a direct-amount10 request with mask256, flags28, kind4 and tag255. Target resolution, that record's producer and actual health loss remain unverified; do not label10 as final player damage.

`verify_hive_worm_events.py` passes4,568 native event-list cases,512 predicate cases,65,536 operation11/6 flag-prefix cases,512 direct-amount packet cases,512 state writes, two generic constructors and two operation21 dispatches. Operation11 sets flag0x2000; operation6 additionally sets0x10000 and reaches the registry-removal call. Its full lifecycle is not replayed, so these flags are not described as death/removal from the game.

`verify_hive_worm_surface_triggers.py` passes768 native kind11 dispatches and4,608 surface-completion cases. It verifies all input event bytes for regions793/794/1216, both surfaces, signed direction/remaining cases and all flag bytes. Runtime addresses, descriptor event-offset mapping, enqueue and movement inputs are supplied boundaries; obstruction, timing and actual queued effects remain open. Numerical evidence is in the two adjacent checks JSON files. Original archives stay local.

Opus5.5 identified the kind11 records that the existing kind12-only ownership helper omitted. The lead independently replayed their dispatch and found the movement-completion producer. Grok's separate actors21/22 review reached its turn limit without findings; no evidence was promoted from it. Actors21/22 remain unclassified, and the earlier source AI witness is not startup proof.

Next: verify the worm kind5 producer and action/property callbacks, stage original worm presentation, and integrate the complete surface/actor sequence with saved state and earned reachability. Do not add arbitrary region-entry worm combat or use the source census as a completion percentage. Full Act One remains open.
