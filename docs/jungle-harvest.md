# Jungle Aloe plants, sap trees and the Aloe barrel

`tools/prepare_jungle_harvest.py` pins the source records byte for byte. It writes
`scripts/lol2/jungle_harvest_source.json` and exports the original selector images and item icons to
`assets/lol2/generated/jungle_harvest/` (local, original media).

## Source records

| Source | Props | Records |
|---|---|---|
| Aloe plant (template104, 4 selectors = owner state) | 254–260, 311 | Empty-hand use (kind4 mode0) at state0/1/2 enables kind2 timers 0 / 0,1 / 0,1,2, sets state and selector +1, and grants one "107-Aloe" (op3 property4). State3 is bare and has no use record. Timer j (flag 0x80, 15 minutes) at state j+1 stops itself and steps state and selector back to j. |
| Ironwood sap tree (template105, selector 0 closed / 1 tapped) | 261–267, 310 | Kind9 hit at state0: selector1, op7, state1. Use at state1/2/3: enable timer0, state+1, one "109-Ironwod sap". Timer0 (flag 0x80, 18 minutes) while state>0: op17 −1. Kind6 event3 (animation end) at state0: selector0, stop timer0. |
| Aloe barrel (template52, selector 1 broken) | 1464 | Use while state<3: op17 +1, one "107-Aloe" (property1). Kind9 hit, one-shot: sound, state4, selector1. No timer. |

## Native rules

- **op17** (B5A76) adds a signed byte to owner state, clamped to 0..255.
- **Timers** (op14, B47B4): sub3 enables a stopped record and keeps its counter; sub4 stops it and keeps the counter. Running records count down. On expiry (B8BA0) a record reloads with carry, then offers its group, which runs only when its predicate holds.
- **Durations** (B8AC4): flag 0x80 is minutes × 60 × rate; flag 0x10 is seconds × rate. The record counters (54000 and 64800) equal minutes × 60 × 60, which is consistent with 60 ticks per second.
- **Kind9 hit filter** (AE2C8):
  - Trees need mask0 ∩ 0x010E, mask2 ∩ 0x0004 and mode4 (remaining durability ≤ 3). Placement durability is 4, so ordinary melee (2/4) with any damage opens a tree. Spark (1/1) does not match.
  - The barrel matches any mask in mode1 (damage ≥ 1), one-shot.
  - These are not startup events: the ADF34 event9 replay selects none of these records.
- **Items:**
  - "107-Aloe" (definition109) uses handler9 (0x967A8), the same fixed +5 pending heal as "108-Cave aloe". It reads nothing from the definition, so the existing `aloe` use applies.
  - "109-Ironwod sap" (definition111) uses handler98, the existing `ironwood_sap` use.

## Port

- `jungle_harvest_state.gd` is pure state and timers.
- `jungle_harvest.gd` is the live owner, saved as `quest_state.jungle_harvest` and validated by `act_one_quest_state.gd`.
- `jungle_harvest_items.gd` holds the item pools.
- Invariants checked on load:
  - A plant's timer j runs exactly when j < state.
  - A sap tree's timer runs at state ≥ 2 and never at state 0.
- **Item pools:** Aloe 27 (8 plants × 3, plus the barrel's 3) and sap 24 (8 trees × 3).
  - A harvest takes the lowest pool id that is not carried.
  - Harvesting a consumed id removes it from the item-effects spent history, because a spent id must never also be carried.
  - Harvests are refused atomically when the hand is busy, the pool is exhausted or carrying is at `MAX_CARRIED`.

## Adapters

- **Use:** E with an empty hand at an aimed, reachable, unoccluded source is the use producer. The grant goes into the hand, as for the beehives.
- **Hits:** an armed melee strike (left click) is the hit producer, with context 2/4 and damage 1.
- **Not hosted:**
  - Spark on the barrel.
  - op7, and the barrel's op20 sound (presentation).
- **Tree closing:** a tree's event3 group (selector0, stop timer) runs as soon as its timer returns it to state 0. The native event3 timing for single-frame selectors is not replayed.
- **Clock:** timers run on the active Jungle world clock at 60 ticks/s.

Test: `tests/jungle_harvest_live_test.gd` (registered in `tools/run_regressions.py`).

Simultaneous Aloe timer expiries are fully processed at the exact boundary before checkpointing; a regression reproduces and prevents zero-countdown save states.
