# Thieves' Den room chain (TEXT, TCEL, TDOOR, TINT)

The village's optional guild chain: the yard of the abandoned house (TEXT_, room 44), its cellar (TCEL_, 16), the slot
door with the password (TDOOR_, 17) and Mauri's den (TINT_, 18). Decoded from the original room DLLs by fable on
2026-10-27 (AI_COMMS `THIEVES_DEN_DECODE_20261027.md`, roadmap chunk 7 fix V2); built as V3 + V5.

`tools/verify_thieves_den_sources.py --game GAME` pins the facts below and writes
[thieves-den-checks.json](thieves-den-checks.json) and `scripts/lol2/thieves_den_source.json` (numbers and names
only). `tools/prepare_thieves_den_media.py --game GAME --re-root RE --source scripts/lol2/thieves_den_source.json
--output-root FRESH` stages the media into `assets/lol2/generated/thieves_den/` (local original media, never
published): the four backgrounds, the CELLAR and TINTTRAN walk-ins, 70 TDOOR/TINT requests, 22 Luther replies, three
sound-bank cues and the two THFSHAPE sprites.

## Source

**Entry.** L4_HJ region 3642, event 2, no predicate, group 7338 ends in `0c1086002c00`: op12 control134 selects room
44 `text_` (VILLAGE_INTENDED_FLOW §1). Every other room change is a DLL `room(...)` + `exit_room` call.

**Host slots.** Bound by each DLL's initializer and resolved through the LOLG.DAT fixups (file offset = documented
address + 0x37000): 0x18 hotspot, 0x10 shape_hotspot, 0x20 actor, 0x28 idle, 0x40 give_item, 0x44 take_held_item,
0x48/0x4C/0x50 set/clear/get_flag, 0x54 movie, 0x11C movie_flags, 0x5C damage, 0x68 exit_room, 0x70 get_global,
0x74 holding_item, 0x80/0x84 arm/cancel_timer, 0x88 room, 0xA4 held_item_state, 0xA8 held_item_is_magic, 0xB4/0xB8
set/get_local, 0xBC load_room, 0xE0 place, 0xE8 random(0..n), 0xF0 heading, 0x114/0x118 cursor show/hide, 0x120
add_fighting_xp, 0x134 sfx, 0x138/0x13C ambient. Callbacks: 1 setup, 2 teardown, 3 sprite click, 4 hotspot click, 5
actor click with the hand item, 6 spell, 7 weapon, 8 exit request, 9 first update, 10 timer expiry, 11 event sound.

**TEXT (yard).** Hotspot 0 (294,218)-(554,344) → `room("tcel_")`. Exit: `place(-2377, 5337)`, heading 288 (region
3362). First update: ambient 351.

**TCEL (cellar).** Setup: `load_room("CELLAR")` while flag 17 is clear, then `clear_flag(17)` on both paths (17 marks a
return from the door; a second entry from the yard replays the walk-in). Seven hotspots; 2 (250,170)-(381,302) is the
door → `room("tdoor_")`, 0 plays cue (2,26,24). Exit: `clear_flag(270)`, `room("text_")`.

**TDOOR (slot door).** Hotspot 0 (147,109)-(471,399); actor 0 = speaker 31 in a 5×5 rect at (0,0); flags 131..133
cleared (dead). Click (0x4EA), in order: `Met_Confidant` is read; flag 270 → nothing; flag 63 without 271 → sfx 394;
`GV_KELSRICK_DEAD` without flag 28 → sfx 394. Then: **no password** (Met_Confidant 0): set 131 and 270, sfx 388,
(31,475,6), `random(3)`: 0 → (1,509,6), 1 → (1,510,6), else (1,511,6), (31,476,6); the door is dead until the cellar
is left. **Password** (Met_Confidant 1): while 271 is clear sfx 388, (31,475,6), (1,476,6); then set 271,
`room("TINT_")`. Exit: set 17, `room("TCEL_")`. The walkthroughs' "ankhman" is never typed.

**TINT (Mauri's den).** Hotspots 0 doorway (72,63)-(207,246), 1 weapon crate, 2/3 table and shelf objects, 4 nothing,
5 coins, 6 purse, 7 sacks. THFSHAPE sprites: 0 Poison Paint at (528,145) while flag 21 is clear, 1 Skull Key at
(588,100) while 22 is clear. Actor 0 = speaker 31 at (340,114) 120×110, idle (31,999,6).

- Sprite 0: set 21, 502, `give_item("123-Pois paint")`, 503. Sprite 1: set 22, cue (2,29,24), `give_item("93-Skull key")`.
- Hotspots 2/3: cue (2,32,24); 6/7: cue (2,26,24); 1: 993, 506, 992; 5: first click per visit (flag 20) the same
  warning, second click 993, 994, `exit_room` (out of the den, no placement); 0: flag 18 → cancel timer, clear 18,
  `load_room("TINTTRAN")`, `place(-2576, 5154)`, heading 180, `exit_room`; else alert → 554, 556 (0xA0), 557, set 19,
  `arm_timer(300)`; else flag 23 → 519.
- Actor click (callback 5, argument = actor id 0) with the hand: no item → 504; non-magic item → nothing (504 only if
  the runtime state bit is set); magic item (definition byte +0x43 bit 0, 24 items) → `take_held_item`, then flag 19
  → cancel timer, clear 19, 558, 560 (0x80), TINTTRAN, `place(-2576, 5154)`, heading 180, `exit_room`; else 505.
- Spell/weapon (6/7): while 27 is clear: set 27, 993, 994, `damage(-1)` (hit points 0, death routine), `exit_room`.
- First update: clear 20, 19, 18. First visit (28 clear): set 28, (1,401,10), 477 (0xE0), 478 (0x80), 479, 480, set 29,
  481..483, 484..486 (0x80), 487..490, set 30, 491 (0xA0), 492, 495 (0x80), 496, 497, set 31, if `Met_Kelsrick` 498
  (0xE0) and 499 (0xA0), 500, 501 (493/494 are never requested). Flag 25 (fourth visit) → nothing. Flag 24 (third):
  alive and quiet → 525..527, set 17, `room("TCEL_")`; alive under alert → 575 (0x80), 576 (0x80), 577; Kelsrick dead
  and 308 clear → the Firestorm scene. Flag 23 (second): alive and quiet → 515, 516 (0x80), 517 (0x80), 518; alive
  under alert → 550, 551, 552 (0x80), 553 (0x80); dead and 308 clear → the Firestorm scene.
- Firestorm scene: 600 (0x80); while 63 is clear: 601, `give_item("9-Firestorm")`, `Luther_has_firestorm = 1`, under
  alert 603 (0xA0); under alert: 604 (0x80), 605 unless 63, 606, `arm_timer(600)`, set 18; then set 63,
  `add_fighting_xp(100)`, set 308.
- Exit request: set the first clear of 23/24/25; flag 19 → clear 19, 561 (0x80), 562 (0x80), 563; else flag 18 → clear
  18, the same three; else 24 clear → 507, 508; always set 17, `room("TCEL_")`.
- Timer expiry (callback 10) only cancels the timer: the two timers have no effect.

**Journal hints.** `thieves_den_state.JOURNAL_HINTS` (owner rule 2026-10-27, data only): six vague Luther lines for the
den-side stuck points of VILLAGE_INTENDED_FLOW s7 (no Confidante yet, hut smoked before the password, den unfound,
the quiet kill, the hostile village, Firestorm), each with its Enhanced guard candidate; Classic shows nothing.

**Flags.** 17 return-from-door marker; 18 tunnel free (this visit); 19 price asked; 20 coins touched; 21/22 items
taken; 23/24/25 visits; 27 attacked; 28 Mauri met; 29/30/31 dead markers; 63 Luther has Firestorm (also set by WPN);
131..133 dead; 270 door dead until the cellar is left; 271 admitted; 308 Firestorm scene done. Globals read:
GV_HULINE_ALERT, GV_KELSRICK_DEAD. Locals: Met_Confidant (read), Met_Kelsrick (read), Luther_has_firestorm (set).
MAGIC never reads GV_KELSRICK_DEAD.

**Region 386** (the tunnel's landing, floor −30) is outside the palisade: removing the gate cluster 3804..3813 cuts it
from every village-interior region while it still reaches the monastery-side jungle (decode §9).

## Port

- `scripts/lol2/thieves_den.gd`: one function per DLL callback → ordered host effects (the Rashar `magic_shop.gd`
  shape), the click router (actor rect, sprites, hotspots), geometry and placements.
- `scripts/lol2/thieves_den_state.gd`: the saved bank `quest_state.thieves_den` = {room, flags, script, next_room,
  rng_seed, reward_seed, pending_items}. Handlers run as saved scripts whose effects are re-derived from the handler
  name and its snapshot inputs; movies hold the clock by their staged durations; `room` + `exit_room` opens the next
  room's setup + first update inside the same clock. Older saves load the bank as zero.
- `scripts/lol2/thieves_den_rooms.gd`: the CanvasLayer on the monastery compositor. Region 3642 (edge-triggered, as
  Rashar's 2636) opens TEXT where Luther stands; TEXT's exit places him at (−2377, −5337) facing 288; the tunnel
  places him at (−2576, −5154) facing 180 on region 386's floor. Hand selector + Back button + F/Q attacks + F5/F9 +
  Enter skip. Host effects: items (new Act 1 ids `jungle:thieves_den:Pois_paint` / `Skull_key`, Firestorm reuses
  `jungle:weapon_shop:Firestorm`), +100 fighting XP through the shared reward checkpoint, flag 63 and
  `Luther_has_firestorm` mirrored into Kit'yara's shop bank (her orb offer then refuses, as native), the held item
  destroyed, `damage(-1)` = health 0 with the host's R/F9 recovery.
- Catalog: the two den items are carried-only with their original icons; `item_definitions.raw_byte` exposes record
  byte +0x43 for the payment test.

## Adapters (docs/DEVIATIONS.md, 2026-10-27)

Capacity refusal before the shelf pickups (Firestorm waits in `pending_items`); Luther's reply AUD after each
0x80-flagged line (22 lines: 19 by their own name hash, 486/498/556 under a hash a requested Mauri line also matches,
where Mauri's line has its own VQA); the held-item state bit always clear; the two timers not hosted; the hand
selector, Back, F/Q bindings; a saved LCG for the wrong answer and the XP draws; sfx 388/394, walk sounds, ambient 351
and cursor calls not hosted; the two evictions without placement.

## Unknown

Line texts (speech only); the exact meaning of the 0x80/0xA0/0xE0 bits; the state bit's writers (host 0xA4); the
unrequested clips 3199106E (TDOOR) and 3199506E (TINT); callback 12; readers of `Luther_has_firestorm` outside the
room DLLs.

## Tests

- `thieves_den_state_test` (headless): the planner against the four DLL call lists (every request, flag, item, room,
  hotspot, sprite, actor rect, placement and heading; the reply set equals the flagged lines), then the chain without
  the scene: the quiet route, the walk-in replay from the yard, the negative door (all three wrong answers, dead until
  the cellar is left), both refusals, the Firestorm scene, the fourth-visit silence, both alert escapes and their
  lapses, the price (non-magic kept, magic taken), the coin eviction, Damon's death, save validation (round trip,
  mid-line, forged, legacy).
- `thieves_den_room_test` (headless, actual Jungle host): region 3642 entry, yard placement, the quiet route through the
  host click router with both items in the pack (saved and reloaded, catalog labels/icons), a mid-line disk resume,
  the stranger, the Firestorm scene (+item once, +100 XP, shared flag 63/local, Kit'yara's offer refusal), the free
  tunnel landing, the price with the Power Orb, F → health 0 and R recovery, the full-pack refusal and retry.
- `thieves_den_live_test` (rendered): real GUI clicks through the chain, backgrounds/patches/audio on screen, Mauri's
  talking head at its source position and his idle, sprites until taken, the Back button, a mid-line disk resume at
  the same frame, TINTTRAN and standing on region 386's floor after physics.
