# Tavern return and the Huline alert (Bacatta's betrayal)

`tools/verify_tavern_return_sources.py` pins every fact below and writes
[tavern-return-checks.json](tavern-return-checks.json) and `scripts/lol2/tavern_return_source.json`. Both outputs are
numbers and names only. `tools/prepare_tavern_return_media.py` stages the 16 clips into
`assets/lol2/generated/bacatta_revisit/`. Those clips are local original media and are never published.

## Source

### L4_HJ: Left_Village

- **Name.** Local 36 is named `Left_Village` in the geometry name table.
- **Opcode.** Op `0xC6` writes a level local. This is anchored on the alarm's g27172, which writes locals
  52/7/8/32 as documented.
- **Writers.** It has exactly two:
  - region 3501 (the tavern threshold), event 2, g7092, predicate 164 (`local36==0`) → 2;
  - region 3805 (the village gate passage), event 2, g7950, predicate 165 (`local36==2`) → 3.

### CAN.WOM: later-visit setup (0x9EA)

**Import-slot anchors.** The host import table is shared across the room DLLs. Its base is the highest used slot
− 0x13C. The slots are cross-checked on MOFF (give_item, movie, set_flag, movie_flags), on CAN (movie, set_flag), and
on MLIB uses the port already hosts (get_local `Dawn_dam_out_cave`, set_local `Met_Dawn`, set_global
`GV_RUNES_TRANSLATED`).

**Branches.** With flag 34 set (after the first farewell), the setup takes the first of these that applies:

| Condition | Effect |
| --- | --- |
| `Left_Village == 3` | **Maid** (speaker 32): lines 700…707. Then `GV_HULINE_ALERT` = 1, which follows line 707. Then line 708, host `+0xE4(1)` if flag 267 is clear, line 709, set flag 267 (the tavern never reopens), room VILLAGE, close. Bacatta is not installed (existing `bacatta_present`). |
| flag 42 clear | Set 42; lines 662/663 (Bacatta), 664/665 (Luther, audio only), 666 |
| flag 43 clear | Set 43; line 675 |
| flag 44 clear | Clear 37, set 44, call `0xE09`. The farewell routine sets 34, resets `GV_BACATTA_RELATIONSHIP`, plays Luther's 637/638 only when 37 is set (here it is clear), plays Bacatta's 676/677, then closes. |

### Reachability with Bacatta57 (existing owner, `jungle-bacatta57.md`)

- **The seal.** The farewell sets the relationship to 0. The **next** entry into region 3501 runs Bacatta57's
  g10162: the doors shut, the threshold is sealed, timer1 starts, and Luther is returned just outside the doors.
- **One later visit.** Normal play therefore allows exactly one post-farewell tavern visit:
  - the **maid**, if Luther left through the gate first (`Left_Village` 3);
  - otherwise the 662–666 conversation.
- **Unreachable in normal Act 1 play.** Line 675 and the flag-44 farewell need further entries that the seal
  prevents. They are hosted from source anyway and tested by placing Luther directly in the threshold region.

## Port

- **Left_Village writes.**
  - g7092 runs where `monastery_rooms.gd` already detects the region-3501 entry.
  - g7950 runs through a new `region` hook on the village alarm, the owner of the grounded region-3805 entry, before
    its own g7956. That gives it the alarm's world/pause gating.
  - Both writes are one-shot under their source predicates, saved in the existing monastery bank.
- **Conversations.** `monastery_conversation.gd` adds `CAN_MAID`, `CAN_REVISIT` and `CAN_REVISIT_LATE`. Flags are
  written before the lines, as in the DLL. The flag-44 farewell reuses `CAN_EXIT` from clip 2.
- **Partial saves.** They validate through the existing started-flag rule. `CAN_MAID` additionally requires
  `Left_Village == 3` and flag 34. Older saves without flags 42/43/44 load as 0.
- **Alert ownership.** `GV_HULINE_ALERT` keeps its single owner. The room bank only *requests* the write
  (`raise_huline_alert()` → `_kelsrick_shared(29)` → `village_gate.shared29`).
- **Alarm consequence.** The existing alarm timer1 keeps reloading every 0–5 s once armed (source kind2 rows, never
  stopped), so the alarm fires within at most 5 s of the betrayal:
  - the gates shut;
  - the Bacatta57 doors shut;
  - Kelsrick turns hostile;
  - the archers fire.

## Adapters (not native parity)

- **Not traced:** host `+0xE4(1)`, the `movie_flags` variants (0x80/0xA0/0xE0) and the debug print. The clips play
  through the shared room compositor like every other room line.
- **Clocks:** the existing room clock and alarm cadence adapters.

## Routes after the betrayal (measured, no bypass)

These were measured with production grounded movement and every live owner (Bacatta57 seal, alarm, gate, Kelsrick,
archers):

- **Start.** The return point puts Luther outside the shut tavern doors. The alarm fires on its own timer and the
  village gate shuts.
- **Monastery.** The existing source route `tavern_to_monastery` does not use the gate passage, and reaches the
  monastery hall. Luther arrived with **9/30 health after 7 arrow hits**. That is a real hazard (the archers use the
  existing 3-damage adapter), not an obstruction. Healing remains available.
- **Hive.** The source `monastery_to_hive` route then enters the Hive.
- **Departure.** The departure route also starts at the monastery hall and does not use the gate.

## Tests

`tests/tavern_return_live_test.gd` (rendered, actual Jungle host).

**Scenario 1 (room branches, Bacatta57 held out):**
- g7092 runs once;
- the first visit and farewell;
- 662–666, including a partial save on the audio-only line;
- 675;
- the flag-44 farewell (676/677);
- silence afterwards;
- g7950 through the alarm owner: not while paused, once, and inert without the alert;
- the maid: the alert only after 707, flag 267, the tavern refused afterwards;
- disk round-trips;
- legacy and forged saves.

**Scenario 2 (live):**
- farewell → gate departure → sealing return → maid alert → return point;
- the alarm fires;
- grounded escape to the monastery hall, then into the Hive.

## Activation coverage limitation

The current regression places the player at the entry regions and calls room admission directly. Scenario 1 also disables Bacatta57. These checks verify the branch logic and persistence, not a walked approach or viewport hotspot click. Only the post-betrayal monastery/Hive escape uses continuous grounded movement. The additional `tavern_liz_ordinary_route_test` now covers grounded approaches to regions 3501/3805, actual viewport clicks, the earned farewell, sealing return, maid alert and LIZ access after the seal, with every encounter owner active. Its initial main-gate-open state and starting position are supplied; it is not a fresh full-campaign proof.
