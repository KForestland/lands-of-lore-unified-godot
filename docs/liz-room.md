# Village LIZ room (Wax)

`tools/verify_liz_room_sources.py` pins the facts below and writes [liz-room-checks.json](liz-room-checks.json) and
`scripts/lol2/liz_room_source.json` (numbers and names only). It was written independently of Grok's
`grok/liz_room_review_20261010/verify_liz_room.py`, and the two agree.

`tools/prepare_liz_room_media.py` stages the following into `assets/lol2/generated/liz_room/`. These are local
original media and are never published:

- the `LIZ_.VQA` background;
- the `LIZTRAN.VQA` intro (160 frames);
- the two sound-bank cues `0100224e` and `0120224e`.

## Source

**Entry.** `VILLAGE_.WOM` hotspot 3, at (425,211)–(576,310), runs `room("liz_")` with **no** flag test (0x591). Only
hotspot 2 (CAN) is gated by flag 267.

**Host slots.** `LIZ_.WOM` binds its host slots in the DLL initializer, and the targets come from the LOLG.DAT
fixups: hotspot, give_item, set/get_flag, movie, room, exit_room, load_room, quip, ambient.

**Room setup (0x47C).**

- `get_flag(268)`; if it is clear, `load_room("LIZTRAN", 1, 0)`.
- `set_flag(268)` on both paths.
- Five hotspots.

**Hotspot 0 (0x5A7), while flag 162 is clear,** in this order:

1. `set_flag(162)`;
2. `movie(100, 2, 24)` (cue);
3. `give_item("71-Wax", 0)` (identity 0xAE5ADACF).

A second click does nothing.

**Hotspots 1–4** call `quip(0x100 / 0x200 / 0x400 / 0x800)`. They are quips, not exits. The lines are unknown.

**Callbacks.**

| Callback | Address | Effect |
| --- | --- | --- |
| 8 (leave) | 0x63D | `room("VILLAGE_")`, `exit_room` |
| 9 (first update) | 0x654 | `ambient_start(367, 90)`, `movie(2, 59, 24)` |

**Cues.** `movie(100, …)` and `movie(2, line, 24)` are sound-bank requests. The speaker biases, 268 and 141, are the
replayed rule in `tools/prepare_hive_rune_speech.py`.

| Call | Request | Bank record | sha256 prefix |
| --- | --- | --- | --- |
| 100:2 | 221 | `0100224e.aud` | 449f860e… |
| 2:59 | 247 | `0120224e.aud` | d8f5a86c… |

## Port

- **Entry.** `monastery_rooms.gd` adds VILLAGE hotspot 3 → room `LIZ` with no flag-267 test. CAN keeps its gate.
- **Sequences.** `monastery_conversation.gd` adds three:
  - `LIZ`: the intro;
  - `LIZ_ENTRY`: cue 2:59;
  - `LIZ_WAX`: cue 100:2.
- **Flag 268.** It is written at the intro start. A mid-intro save therefore resumes the clip, and a reload never
  replays it. A later entry starts directly with the first-update cue.
- **Wax pickup.**
  - Success sets flag 162, grants the next free id from the existing beehive wax pool (`jungle_beehive_wax.gd`,
    source name "71-Wax", accepted by `hive_rune_transaction.is_wax`), and plays cue 100:2.
  - **Adapter:** a full inventory or an exhausted pool refuses ("You cannot carry more.") and leaves flag 162 clear,
    so the pickup can be retried. The source sets the flag first and never checks capacity.
- **Leave.** Back/Escape (callback 8) returns to VILLAGE.
- **Saves.** Flags 162 and 268 live in the existing monastery bank. Older saves load them as 0. A `LIZ_WAX` partial
  save requires flag 162.

## Not hosted / adapters

- **Not hosted:**
  - hotspots 1–4 quips (lines unknown; they neither grant nor leave);
  - callback 11 (host 0xE8 and 0x134);
  - ambient 367;
  - the extra `load_room` arguments 1 and 0.
- **Adapters:**
  - no caption text;
  - the intro is presented like the TAVERN intro;
  - the cues are audio over the room background.

## Tests

`tests/liz_room_live_test.gd` (rendered, actual Jungle host) covers:

- **Entry:** real GUI clicks on VILLAGE hotspot 3 with flag 267 set, while CAN is refused.
- **Intro:**
  - it plays once;
  - a mid-intro disk resume, and a pause that freezes it;
  - the first-update cue follows;
  - no leftover intro frame.
- **Wax pickup:**
  - refusal with a full pool and with a full inventory, then a retry;
  - one wax plus the cue;
  - a second click does nothing.
- **Hotspots 1–4:** not hosted.
- **Leaving and re-entry:** callback 8 returns to VILLAGE; a re-entry plays no intro.
- **Saves:** disk round-trips, a legacy save, a forged save.
- **Consumer:** the granted wax, carried by the real Jungle→Hive handoff, becomes runes at the production RUNECL
  hotspot.
