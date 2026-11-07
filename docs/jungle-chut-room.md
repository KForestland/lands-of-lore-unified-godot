# Jungle: the chief's-hut room CHUT

Owner r12c report #22 (2026-10-24 18:12, "the chectan point and click do not start just back yard here"). In the
original, stepping onto Kelsrick's gate line after his first talk shuts the inner gate and opens the chief's-hut room,
a 2D room like the tavern: the hut approach (HUT-APR), then Kelsrick and the Huline chief on the throne (longplay
61:35-62:52). Afterwards Luther stands outside the shut gate, facing Kelsrick (62:56).

## Source chain

- L4_HJ region2750 event2 group5084 (predicate20, local6 == 0) ends with `0c1064000e00` (op12: control100 selects
  room14) and `091064001500` (op9: control100 property21 fires it). The same pair opens VILLAGE (Bacatta57) and RUNES
  (Hive pit). LOLG.DAT room names in table order give 14 = `chut_` (anchors 3 ment_, 10 runecl_, 11 runes_,
  12 village_).
- `WOMS\CHUT_.WOM` (static disassembly, `tools/verify_chut_room_sources.py` → `scripts/lol2/chut_room_source.json`):
  - setup 0x47C: `load_room("hut-apr",1,1)` on every load, background `chut`, idle 29/999/06 (29/995/06 with
    GV_KELSRICK_DEAD);
  - callback9 0x890: first visit (flag153 clear, Kelsrick alive, Kelsrick_Attacked clear, flags 152/150 clear): set
    flag152, lines 29/350..364, flag151 after 358, `Met_Kelsrick` (L4_HJ local30) = 1 after 362, then
    `place(-1769, 5464)`, host 0xF0(150), exit_room;
  - callback8 0x866 (Back): the same placement and exit.
- Host offset 0xE0 is the placement MCEL uses for the cellar passage. Native y is Godot -z: (-1769,-5464) lies in
  region3791, north of the gate, the region the owner's own save shows after the gate shut.

## Port

- `jungle_walkthrough.gd _kelsrick_effects` consumes the op12/op9 pair and opens CHUT in `monastery_rooms.gd`.
- `monastery_conversation.gd` sequences CHUT (intro) and CHUT_FIRST (the fifteen lines and their writes);
  `monastery_rooms.gd chut_first_update()` admits the first visit after the intro; `_chut_leave()` places and exits.
- Media: `tools/prepare_chut_room_media.py` → `assets/lol2/generated/chut_room/` (local original media).
- Deviations and the unhosted branches: `docs/DEVIATIONS.md` (2026-10-25 Jungle row).

## The owner's save

The reported save (talk1 done, g5084 receipts, gate shut, Luther in region3791) cannot replay the room: with the gate
shut, the gate line is out of reach, as in the original after CHUT. The room plays on the next playthrough that reaches
Kelsrick's gate. The chief's-hut fire is reached through the jungle to the watergate pool (longplay 67:08-67:48);
the walk tests now take that way (`tests/fixtures/chut_pool_route.json`).

## Tests

`jungle_chut_room_test` (headless, red on the old consumer); updated: `jungle_inner_gate_live_test`,
`jungle_kelsrick_live_test`, `hive_quest_walk_test` / `kelsrick_inner_gate_walk_test` (earned crossing now opens CHUT),
`jungle_chief_hut_walk_test` (CHUT exit to the pool).

## Kelsrick-dead branch (private implementation, 2026-10-25)

Callback9 first refuses flag153. With Kelsrick dead and flag150 clear, the original raises `GV_HULINE_ALERT`, sets
flag153, and plays 29/375..379/06. It returns to the dead idle in CHUT, without the peaceful branch's automatic exit.
The shared village gate owns the alert. `CHUT_DEAD` saves its line cursor and elapsed time, and retains flag153 after
completion to prevent replay. Eight original callback executions verify admission and call order; original clip
frames/audio samples are verified by the media preparer. Movie flags0x60/0xC0 remain the existing plain-line adapter.
Rendered earned entry and final candidate qualification remain pending. Attack branches and stone hotspots remain open.

## The remaining branches (fable, 2026-10-27; AI_COMMS CHUT_BRANCHES_DECODE_20261027.md)

Read from the DLL with the den/poison method (listing in the decode note). Media through
`tools/prepare_chut_branch_media.py` → `assets/lol2/generated/chut_branches/` (local only): Anyar's 365/366/367/998,
the two CHUT.SHP stone piles, cues 100:17 and 2:30.

- **Setup 0x47C** also decides who is in the hut: flag 150 → the two stone piles at (274,169)/(374,169) and no actor;
  flag 153 without 150 → nobody (`[0xD78] = 0`, the empty hut after the Kelsrick-dead speech); else Anyar's idle.
  The port saves `[0xD78]` as `anyar_present`, decided at entry only: in the visit that plays the dead speech Anyar
  stays in her idle (nothing clears the static inside a visit); the hut is empty from the next entry on.
- **Callback 9 (0x986)**: Kelsrick alive and `Kelsrick_Attacked` (local 52) → the per-load mode `[0xD74]` and
  **branch A at once**: `Anyar_Attacked` (local 33) = 1, the alert, line 365, `place(−1749, 5457)`, heading 286, exit.
- **Callbacks 6/7 (0x6E8)**: nothing while flag 150, or 153 without 150; the mode set → branch A; else **branch B**:
  `Anyar_Attacked`, the alert, Soul −1, flag 150, Anyar's death 998, the piles, cue 100:17 (slots 0x30/0xEC not hosted).
- **Callback 3 (0x594)**: while flag 150, either pile gives the first clear of flags 154..159 ("66-Ancients stn",
  cue 2:30 on the first): six stones, the piles stay.
- **Callback 5 (0x68B)**: a held item answers 366/367 only in the mode; natively the mode's own first update throws
  Luther out before any click, so the refusal has no reachable window (hosted as data, `CHUT_REFUSE`).
- **Flag 150** has no writer outside this DLL: no level-script opcode reaches the host flag routines, so the fire route
  (which also closes the gate line through `Has_Luther_smoked_the_Cheifs_hut`) never shows these stones.

Port: `monastery_quest_state` flags 154..159 and `chut_attacked`; sequences `CHUT_ATTACK`, `CHUT_KILL`, `CHUT_REFUSE`,
`CHUT_STONE`; `monastery_rooms.chut_attack`/`take_stone`/`_anyar_attacked`; six carried ids
`jungle:chut:Ancients_Stone_1..6` (use `ancient`). Journal hints: `CHUT_JOURNAL_HINTS` (data only). Deviations:
docs/DEVIATIONS.md 2026-10-27 (CHUT). Test: `chut_branches_test` (headless, real Jungle host).
