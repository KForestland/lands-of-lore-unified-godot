# Dark Halls P3: Spy Slider build record

Status: implementation in progress; component proof and slide1015 earned traversal passed; remaining traversal and original visual comparison pending. Owner playtest has not cleared this puzzle.

## Meta duck

1. Problem: r17 leaves six metal wall slides inert (controls 236, 890, 891, 1013, 1015, 1041; owner reports listed in Kimi K35). This slice started 2026-11-07.
2. Main chain: the Dark Halls is optional, but these are functional interactions explicitly assigned by the owner, rather than an unsolicited presentation refinement.
3. Intent: reward exploration by letting the player open a peephole and see the room beyond. Evidence: L7 native kind-4 pairs and Brady metal-slide description cited in K35.
4. Contract: approach/aim/use the closed metal panel; opening requests sound 631 and state 1; use again requests sound 630 and state 0. Control236 additionally links/unlinks prop465 with opcode9 arms17/18. Control890 additionally invokes opcode6 arms1/2 on prop416. Native script records are the direct evidence; no new longplay observation is claimed.
5. Exact: control IDs, native event kind, toggling, sound requests, prop command dispatch, persistence. Approximate: E within 110 units and a facing cone in place of a native object click; lifting the panel by its exported height to uncover the slit. Sound playback is still unhosted.
6. Smallest faithful option: shared native host for events, dedicated meshes for the six panels, explicit boolean state in quests.dark_halls_slides. Do not decode unrelated motion systems. The movement direction still needs original-footage comparison; this is an adapter, not decoded animation.
7. Proof: dark_halls_slides_test covers all six native toggle pairs, poses, sound IDs, invalid saved values, and actual disk rollback. dark_halls_slides_earned_test begins at the hash-pinned r17 repaired-monastery save and uses cellar clicks, W/Shift/mouse, active enemies, E and F5. Its first route targets slide1015; it must pass before claiming that approach. The other five require their own earned approaches. No teleport, enemy disabling, supplied health, or quest injection is permitted.
8. Record: this document, the deviation piece and a board checkpoint retain the implementation boundary for lead review.

## Fact versus interpretation

The K35 phrase "switch prop416's selector" is too strong. native_script_host.gd::_op_six stages record operations for opcode6 arms1/2; it is not _op_selector (opcode5). The current adapter dispatches those native operations but does not invent a candle-selector mapping. Prop465's link bit is likewise staged by the host; rendering that linkage remains open. These visible side effects must be resolved before P3 is handed over as complete.

Builder read: use the existing native event machine, with presentation owned by the area adapter. Self-critique risks: a panel lifted in the wrong direction; a solid wall still hiding the intended view; a staged prop command mistaken for a rendered effect. Flip point: original open/closed footage would settle the visual contract. Next check: inspect the earned slide1015 closed/open captures and compare the aperture to the original before extending the same mesh adapter to acceptance for all six.

## Reproduction

Run tools/prepare_dark_halls_slides.py against the staged original-script/geometry exports, then tools/build_dark_halls_slides_walk.py. These generators contain no original media. Run the registered component test with the private tmp/godot_host.sh. The earned test uses the r17 qualification repaired-monastery save copied individually into private user://tests/act1_broken_repaired_monastery.json, with LOL2_DH_INPUT_SHA=f5f323a57faa22ec914fa25484466e80177421cabf8148d5d9dbb7379633df4f. Original save is read-only; no lead userdata directory is copied.

First earned run: tmp/sol_slides_earned_first/report.json PASS, source_stable=true, 129.49 seconds. Captures slides_slide1015_closed.png/open.png visually inspected: opening reveals the adjoining room. No original-footage match claimed. godot_check: 5 scripts, zero errors. Affected selection: 676/949 registered tests; execution pending.

Original local frames inspected: ~/lol2_original_screens/longplay_frames/f_00941.jpg and f_00943.jpg show a small framed wall aperture and a view into the shelves beyond. The earned1015 open capture reproduces that basic through-view contract; frame-to-control identity and animation direction are not established, so this is not a frame-exact comparison. A contact sheet of f_00900..f_01028 was inspected locally for context.

## Source geometry refinement (follow-up worktree)

The original metadata template22 has child184 mask1 bounds(-15,15,-1,0,1,13), surfaces259/259/367/367/367/367, and child186 mask2 with identical bounds and surfaces259/259/368/368/367/367. Child185 mask0 never renders. Materials367/368 are already staged and have original transparent cutouts: the visible shutter moves from one half of the framed opening to the other. This supersedes the upward panel translation described above. The runtime now keeps the mesh anchored, swaps the two front/back materials, and honors their alpha. Mapping the native use-state to template mode remains an explicit adapter; the variant shapes/textures themselves are source facts.

The component test was changed because this new source evidence invalidates the earlier vertical-motion assertion. It now verifies the original368 versus367 texture data, cutout material mode, unchanged mesh position, native toggles and disk rollback. First refinement run failed because JSON variant-face numbers were floats and the membership check used ints; explicit conversion fixed the runtime selection. Second component run PASS7.37s. Earlier walks still prove their input approach, but current visual acceptance requires the refreshed earned captures.

Source extraction now requires tools/prepare_dark_halls_slides.py --game ~/lol2_runtime_root. It pins the original L7 archive hash and validates both complete template child surface lists before writing the portable adapter contract. No original media is committed.
