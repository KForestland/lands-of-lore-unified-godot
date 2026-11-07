# Cave entrance death (control135)

Owner report 2026-10-17 10:45:34 ("the death animation as human does not play"), pose (-1137, 113, -3084) at the cave mouth.

## Source

- L1_DC control135 is a template21 zero-height support plate (the template of plates 89/104/109) at native (-1453, 83, -3144), heading 19114, spanning the cave mouth just west of arrival 2 (-1288, 129, -3118).
- Three descriptor-type-5 records, predicate206 `0005000000` (owner state == 0):

| event | form (ADA30) | group | commands | movie |
|---|---|---|---|---|
| 8 | human (0) | 10656 | op16 state1, op2 player 0x39, op21 74 | luthrdie (48 frames) |
| 9 | beast (1) | 10632 | op16 state1, op2 player 0x39, op21 11 | bst-die (322 frames) |
| 7 | lizard (2) | 10608 | op2 player 0x39, op21 35, op16 state1 | liz-die (100 frames) |

- **ADA30.** D26B0 calls ADA30 when the player's support owner changes. Its jump table at 0x549E8 is decoded from nine relocation records, and gives these admissions:
  - event 4: always;
  - event 7: form == 2;
  - event 8: form == 0;
  - event 9: form == 1;
  - event 10: form != 2;
  - event 11: form != 0;
  - event 12: form != 1.
- **op2 sub0x39 (D7893).** Unless the global at 0x223D4 is set, it marks the player and calls D8D48(player, 1): immediate death with no 30-tick countdown.
- **op21.** 64770 → CF2B4 plays the movie-name table entry (ds+0xE568) as `%s.vqa`. The clips are L1_DCI entries 1/35/16, `SPHERE1\L1_DC\<NAME>.VQA`. They show Luther leaving by the front mouth and being shot by the archer guards (human), or fighting them (beast).
- The movie table is reached only from op21 and from the intro (index 0). D8D48, the generic death, plays no movie, so death elsewhere has no movie in the original either.

## Runtime

- **`tools/prepare_cave_entrance_death.py`** writes `scripts/lol2/cave_entrance_death_source.json` and three Theora clips in `assets/lol2/generated/cave_entrance_death/`.
  - It asserts all native bytes above. It recomputes the published plate89 polygon and refuses if that differs.
  - It is bit-exact across runs.
  - Missing or unsupported game files exit 1 with no output.
- **`scripts/lol2/cave_entrance_death.gd`** handles the plate:
  - grounded entry onto the plate, using the shared `source_control_contact.gd` adapter (foot ±4);
  - the per-form record, which sets owner state 1 for that life;
  - killing the player, as the lava does;
  - the full-screen movie, with the tree paused. Escape or Space skips it.
- **Host:** `cave_walkthrough.gd`.

## Adapters and disclosures

- Owner state is not saved. In the original, recovery is a save reload with state 0, so R recovery, checkpoint resets and loads re-arm the plate.
- R recovery is a modern adapter. Anchors inside the plate are removed from the safe trail, so recovery never lands back on the plate.
- Movie audio is decoded mono 22050 Hz. bst-die has 0.5 s more audio than video.
- The death check uses the host's existing `mouse captured` gate, as the lava does.
