# Huline Jungle: alert-before-first-meeting Bacatta (prop553 → actor65), 2026-10-07

Optional branch. If Luther strikes Kelsrick (which sets the Huline alert) before he has met Bacatta, she meets him
in the jungle instead of the village. Fixture-tested slice on the real Jungle host. It is not earned-route or
owner acceptance.

| Source → output | What |
|---|---|
| `tools/prepare_jungle_bacatta65.py` → `scripts/lol2/jungle_bacatta65_source.json`, `jungle_bacatta65_population_source.json` | 83 records pinned byte for byte: prop553 69, actor65 2, the prop3235 kind5 starter, and 11 region groups. Also 38 predicates, the prop553 timer row, placements, region polygons and the template84 selectors 0–29. A completeness check proves that every group naming prop553 or actor65 is pinned. |
| `tools/prepare_jungle_bacatta65_media.py` → `assets/lol2/generated/jungle_bacatta65_media/` | Original media, local only and never published. 30 selectors: 25 distinct VQAs plus BC08 with three LIND segments. Also the BACL4 definition5 sprites. |
| `scripts/lol2/jungle_bacatta65_state.gd` / `_packet.gd` | The pure source-chain state and atomic packet validation. |
| `scripts/lol2/jungle_bacatta65.gd` | The live controller. It handles the producers and presentation, and drives the generic creature owner for actor65. |
| Host (`jungle_walkthrough.gd`, `act_one_quest_state.gd`, `player_spark_aura.gd`) | Setup, save/restore (`quest_state.jungle_bacatta65`), the movement lock, shared-global hooks and spell targets. |

## Story chain (source)

1. **Trigger.** The prop3235 sighting runs g16958 under p86 (GV_HULINE_ALERT==1 AND GV_MET_BACATTA==0). Prop553
   becomes present and raises event20, which plays the BC08 segment1 idle on repeat (255) with player focus.
   GV_HULINE_ALERT is the village gate's `shared29`, and its only writer is the Kelsrick hit. The host reads and
   writes it only through that owner.
2. **Meeting.** First entry into region 577/582/3895–3897 (p87, local2==0) holds the player, repositions him
   facing Bacatta, sets local2=1, then state2 and selector1. When the first line ends, GV_MET_BACATTA=1.
3. **Talk.** Bacatta (`13…`) and Luther (`01…`) lines run as selector N → kind3 N → start → kind6 value0 → next.
   The waits at states 6 and 11 are one BC08 loop each: the wrap's kind6 value1 continues the talk.
4. **Offers.** These are kind4 mode1 (any carried item; the item is kept). At state 6 the offer adds
   GV_BACATTA_RELATIONSHIP +1 and plays selector28 before returning to the wait. At states 10 and 16 it plays
   selector28 without the +1. State 16 returns to state 10's wait, as in the source.
5. **Peaceful outcome (B).** State16 starts timer0 (180 ticks). Expiry runs g12438 → states 20–27, then state28 runs
   g12888, which releases the hold, removes prop553 and links actor65 with op13 sub17.
6. **Hostile outcome (A).** Any hit on prop553 (kind9 mode1, threshold1) sets GV_MET_BACATTA and local3, and leads
   to Luther lines (states 19 → 17 → 18). Then g12514 removes prop553 and links actor65 hostile (sub13 + sub7).
   - A hit after state 15 also takes GV_LUTHERS_SOUL −1 and GV_BACATTA_RELATIONSHIP −1.
   - A second hit is immediately hostile.
7. **Walk-away.** Entering region 576/601/3890–3892 while local2==1 repositions the player, plays selector29 once
   (local2=3) and resumes at state 7.
8. **Removal.** Region3157 (GV_MET_BACATTA==1) removes actor65. Its actor57 removal is reported as an unowned
   effect; actor57 is not implemented.

## Native facts (static LOLG.DAT, bounded)

- **9EBFC/113BF0.** A finished pass with repeat count left (+0x30) returns 4, which raises kind6 **value1**. The final
  pass returns 5, which raises **value0**.
  - This differs from the prop552/prop554 adapters, which report value0 at each wrap. That is harmless only while
    no value0 record is live during a loop. Flagged; not changed.
- **op8 via B43EC.**
  - property2: 9EC7C load + 113D24 start, with repeat = command word +6.
  - property0: 9EC7C load only.
  - property9/10: one LIND segment (9EE70).
- **Creature op13** (table 0x4D2A4 slot10 → A677A, sub table 0x4D248). sub17 = A660D → `A7544(actor,0)`, which
  re-runs the actor's own behaviour decision and does not read the parameter byte.

## Deliberate mechanics changes (modern)

- **Hold.** Source 0x26/0x27 locks movement and jumping only while a spoken line is selected. The BC08 idle waits
  leave the player free: the source's offer, hit and walk-away records need the player to act mid-talk.
- **Walk-away line.** Group13102 uses property0, which natively loads but never starts the line, so state32 would
  wait forever. Here the line plays once.
- **Peaceful Bacatta65.** She stands at her placement with her dormant idle pose; A7544's behaviour-4 AI is not
  replayed. Striking her makes her hostile through the generic creature owner.
- **Hostile Bacatta65.** She fights with BACL4 definition5 through the generic owner, like hostile Bacatta61.
  Death/corpse use the idle frame.
- **Producers.**
  - prop3235 sighting: camera frustum plus a clear ray within 1600, as for prop552/prop554.
  - Region entry: grounded polygon entry.
  - Hit: armed melee aimed at prop553 (any strike meets threshold1).
  - Offer: E-use with a carried item aimed at prop553.
- **Unbound producers.** actor65 kind10 value 0x9000 (re-run A7544) and kind6 value13 (prop2955 event20) have no
  producer, so they are not raised.
- **Clocks.** Clip/segment durations come from the staged media. The timer runs at 60 ticks/s.

## Tests

- `tests/jungle_bacatta65_state_test.gd` (headless) covers:
  - the alert/met gate;
  - idle wraps;
  - first entry hold and GV_MET_BACATTA;
  - timer → peaceful;
  - offer +1 and return;
  - hit → Luther lines → hostile;
  - late-hit soul/relationship −1;
  - second hit hostile;
  - walk-away once;
  - region3157 removal;
  - JSON round-trip;
  - malformed packets rejected.
- `tests/jungle_bacatta65_live_test.gd` (rendered, real Jungle host) covers:
  - no alert → nothing;
  - camera sighting;
  - grounded first entry with hold and reposition;
  - GV_MET_BACATTA;
  - disk save/load mid-line restores exactly;
  - idle-wait offer;
  - timer → peaceful actor65;
  - fresh-host resume without re-trigger;
  - region3157 removal;
  - atomic malformed packet;
  - armed strike → hostile actor65 persisting over save/load.

  The approach is supplied, not earned.

Lead integration review: independent eight checks and final main eight checks pass on stable source. An additional real-host probe observes hostile damage30→24, frozen pause state and defeated-body disk persistence; these assertions are retained in the live regression. The defeat probe calls the combat receiver with lethal damage, not an earned melee kill. Numeric source regeneration matches the release. Conversation capture inspected; supplied approach and no representative GPU/audio or Bob acceptance. See [checks](jungle-bacatta65-checks.json). R4 binaries predate this integration.
