# Huline Jungle exit sequence — source leads (2026-10-03, not implemented)

Static decode of L4_HJ owners/groups. Likely the closing Act One encounter before the darker-jungle departure (region 3188, centre (6914,-3176)).

- prop552 (3592,-4145), template 85: event5 with predicate182 (raw `0604b204a8`, type 6 — not a plain local/shared/owner equality) runs group10720: local 0x38 = 1, global 0x25 write, controls 52–54 activate (op9 property3), **guards 58, 59, 60 spawn** (op9 property3), local 0x01 = 5, prop554 deactivated and prop552 animated (op5/op8).
- Guards 58–60 (GGuard, definition 9, 255 HP, behaviour 14, absent at load) stand at x≈5630–5690, z≈-3580…-3940, between the approach and the exit. Each has event handlers (event2 value304 with owner state 0, event6, event9 predicate54) that wake/step them (property13 0x0d/7, op8/op16 state changes) and share a prop4398/prop552 reset path.
- region4439 (4562,-3647), predicate67 (local 0x38 == 1): local 0x38 = 2; guards 58–60 operation 0x11; controls 52–54 deactivated.
- region4442 (5172,-3752), predicate29 (local 0x2a == 2): guard59 operation 0x15 (native operation21 → ADDE0 event20); local 0x2a = 3.
- prop4398 (5580,-4353), template 50: event6 value532 with predicates 51/52 (type 6) run a movie (op21 prop4398 0x38/0x39), shared writes, deactivate guards 58–61 (and Bacatta 61), reposition the player (op18 kind1) and finish.
- prop554 (5874,-3779): event6/9 groups activate actor0/66 (L4WW) and set state/flags.

Open before implementation: the event5 producer for prop552 and the type-6 predicates (182, 51, 52); guard 58–60 art (definition 9 GGuard); whether the existing departure movie already covers the prop4398 movie. Do not add a departure gate without this evidence.

## Predicate language decoded (2026-10-03, native evaluator 0x66AB0)

Five-byte records: operator, left kind, left index, right kind, right index. Operators (table 0xDA6C): 0 EQ, 1 NE, 2 LE, 3 GE, 4 GT, 5 LT, 6 AND, 7 OR. Operand kinds (tables 0xDA2C/0xDA4C): 0 immediate byte, 2 shared variable (0x26E58), 3 local variable (0x26E54), 4 sub-predicate (recursive), 5 owner state byte +0x25, 7 native callback table 0xBBB8; 1/6 fall through.

- predicate182 = (shared47 == 0 OR local41 == 1) AND (shared14 == 1 AND shared18 == 1). shared14 is `GV_RUNES_TRANSLATED` (Hive docs). So prop552's exit-guard spawn belongs to the post-translation endgame.
- predicate51 = (local48 < 3 AND owner == 0) AND local49 == 0; predicate52 = (local48 < 3 AND owner == 1) AND local49 == 0 (prop4398's two movie branches).
- predicate54 = local42 < 3 (operator 5 = LT); predicate67 = local56 == 1; predicate29 = local42 == 2.
