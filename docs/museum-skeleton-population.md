# Museum skeletons and Rat — live encounter slice (2026-10-03)

The thirteen L3_DH creature placements 20–32 (twelve `skel`, definitions 0/2, and Rat 22) are live in the Museum (`museum_skeleton_population.gd`), saved in the Museum checkpoint as `skeletons` (`museum_skeleton_population_state.gd`, validated by `museum_save.gd`).

## Source-bound

- Positions, headings, health (100/150, Rat 40), behaviour bytes, definition reward scales (def0 = 4, def2 = 2, Rat = 3) and placement item identity fields (`tools/prepare_museum_skeleton_population.py`). These fields are not proof of possessed loot: the constructor initializes the separate item-list head to zero; see [identity audit](act-one-actor-item-identities.json).
- Wake commands: region35 entry runs property13/7 on 24–26; region346 on 27/28/31/32; actors 24–26 wake each other when hit (event5 groups). Actors20,21,30 are addressed by the now-integrated control92, prop107 and control96 handlers. Control92 uses aimed E interaction, prop107 uses the sword-skeleton hit/animation sequence below, and control96 uses visible-world admission and saved movie endpoints. Actor29 has a region1057 wake binding in the source contract. These bindings do not establish native scheduling parity. Rat 22 and skeleton 23 have no wake command and use ordinary perception.
- Counter: each death of 23–32 runs `op207` = native `local[23] += 1` (dispatcher at 0x64770 decoded); predicate58 is `local23 == 10`; its handler runs `op210` sub-op 8 (audio level word = 0) and enables prop93’s timer only when the pre-increment counter is10. Ten unique deaths from0 do not enable it; see the correction below.
- Clips from the original indexed frames (`tools/prepare_museum_creature_sprites.py`, 833 frames): idle, walk (8 views), rise (action9), three attack variants (action5: 50% at frame6; 100% at frame8/9; two 50% hits at frames6/11), death (action14), corpse (action15).
- Native attack base from `global\ai\skel\stat.csv` and `Rat\stat.csv`: total81 = 30, minimum82 = 3, fresh base15.

## Playable adapters (shared with Roach/DINO/Hive warriors)

Native hit amounts are requests that precede the unresolved damage calculation. Player-facing damage = request × 0.4 (`creature_live_rules.PLAYABLE_DAMAGE_SCALE`, the Hive warrior "base6" scale): 3 for 50%, 6 for 100%. 0.8 s recovery after each clip (Hive warrior adapter). Woken perception 600 with line of sight, reach 50, speed 48, 8 fps clocks, attack-variant rotation per clip, skeleton pixel scale 0.29 (opaque height ≈ human 46 units), Rat 0.218.

## Checks

- `museum_skeleton_population_state_test` and `museum_skeleton_live_test` (headless Museum scene; only the world gate replaced): dormancy, actual region35 wake, rise and pursuit across the room, hits, disk rollback, production melee XP, Spark, ten-death counter persistence without an invented prop state, retry.
- Earned Museum→Jungle walk (`museum_earned_walk_test.gd`) passes from the new earned cave save, defeating 27, 28, 31, 32, 29 and 20 with production strikes and spell-key healing; see `museum-earned-jungle-walk-checks.json`.

## Sword skeleton → skeleton 21 (2026-10-03)

Prop107 (template39) is the skeleton that carries the Fine Longsword to the table. Source chain (`verify_museum_gate_triggers.py`: predicates207–210 = byte25 1–4, kind6/event3 selects1950 at state3 and2022 at state4, kind9 record1998 at state3): group1950 at the selector3 endpoint selects idle selector2 and opens the gate; kind9 hit record1998 moves it to state4; the next event3 (selector2 endpoint) runs group2022: actor21 op9 property3 (spawn), prop107 op9 property2 (removed), state5. Actor21 is absent at load (flag0x1000) and placed at (-4232,-957), prop107's end position.

Live: once the sequence completes, an armed melee strike (same reach/aim/line-of-sight gate as the other Museum strikes) sets `sword.struck`; at the end of the current idle cycle the sprite is removed (`sword.replaced`) and skeleton 21 spawns, rises and fights through the shared owner. Both flags are saved; `museum_save.gd` rejects replaced-without-struck, struck before completion, and any mismatch between `replaced` and skeleton 21's presence. Older saves load as state3.
Adapters: hit admission (melee only; Spark and other hit sources not admitted, because native kind9 hit acceptance is not replayed); group2022 has no wake command, so 21 rises and fights like other spawned actors. Check: `museum_sword_skeleton_test`.

## Source interpretation and historical counter correction

- The tenth-death command `0e035d0003000000` is opcode14 operation3 on prop93's kind2 timer record (B485C clears the record's disable bit0; argument0 keeps the countdown word8 = 300). It does NOT write prop93 state3; only opcode16 writes byte25. The saved `prop93: 3` field is therefore a label, not native state. Timer record `0a02a006300105002c01`: expiry group1696 = opcode14 operation4 (disable) plus opcode210 sound commands.
- Opcode210 (dispatcher 0x64770 → 0x65954, 12-way table at 0xc900) writes music/ambient sound globals (0x26d14…0x26d2a) and calls the sound driver. The tenth death (sub8=0) and the timer expiry (sub0=11, sub4=200) are music changes, not treasure logic.
- Prop93's 12 player grants are its kind5 value19 record (group1498): 92-Sk key, 130-Pyra pod, 66-Ancients stn, 3×108-Cave aloe, 2×121-Champion st, 41-Mail shirt, 38-Guard shield, 29-Lt crosbow, 3-Halberd, then player properties 0x0d=3 and 0x0e=3. It is blocked on the same kind5 producer question as control96.

## Open

Creature item-list/drop producers remain unresolved. Placement identities resolve to "92-Sk key", "68-SS1" and "12-Tho Broken", but do not establish possession or a death drop. Actor32’s event8 case-clearing behavior does not by itself prove a grant. The earned Broken Thohan case pickup is implemented and covered by the R4 campaign. Prop93’s kind5/value19 grant producer, music, representative rendering/audio and Bob’s playtest remain open. Control92 and control96 now have live/save regression coverage in the passed full256 suite; they are no longer missing implementations.

Original creature audio is now live through the shared data-driven audio owner, including paused/partial saved playback and legacy restoration; see [audio implementation](museum-creature-audio.md). Headless integration passes; audible desktop review is still required.

## Counter correction, 2026-10-03

Independent replay of `AI_COMMS/grok_control_events/grok_prop93_local23.py` proves predicate58 reads local23 before the queued increment. Local9/event11 queues only the increment; local10/event11 queues the timer command as well. The previous immediate prop93 state3 after ten deaths was unsupported and has been removed. Old counter10/prop93=3 saves are accepted as legacy receipts and normalized to prop93=0. No treasure grant is inferred: kind5 value19 still lacks a verified producer. Ten unique counted defeats retain local23=10. Repeated native death dispatch and the separate timer/startup chain remain to be classified.
