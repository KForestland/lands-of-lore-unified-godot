# Huline village alarm (control216 and the gate archers), 2026-10-07

Once the Huline are alerted (Luther struck Kelsrick: `GV_HULINE_ALERT`), passing through the village gate, or
re-entering the village threshold after Bacatta's farewell, starts a 5 s alarm. When it fires:
- the village gate and the inner gate shut, and the Bacatta57 double door shuts;
- Kelsrick turns hostile and Luther's soul drops by 2;
- the bells ring while the alert holds;
- archers on the gate towers (and one by the village entrance) keep shooting arrows at Luther.

This is a fixture-tested slice on the real Jungle host. It is not earned-route or owner acceptance.

| Source → output | What |
|---|---|
| `tools/prepare_jungle_village_alarm.py` → `scripts/lol2/jungle_village_alarm_source.json` | Byte-for-byte pins: 8 owned records and their groups (7956, 27162, 27172, 27316, 18758, 27324, 21372, 21418), predicates 49/85/166/183/192, the kind2 rows of controls 77/216/217, archer and prop510 positions, the region3805 polygon, local names and the Arrow definition. A completeness check attributes every other record naming these timers or region3805 (prop482 g10162, movable79 g28168, g7950). |
| → `assets/lol2/generated/jungle_village_alarm/sounds/403.wav` | Original `bells1.aud`, local only, staged with the shared creature-audio tool. |
| `scripts/lol2/jungle_village_alarm_state.gd` / `_packet.gd` | The pure source-chain state and atomic packet validation (`quest_state.jungle_village_alarm`). |
| `scripts/lol2/jungle_village_alarm.gd` | The live controller: region producer, bells, arrows, routing to the other owners. |
| `jungle_kelsrick.gd` `run_external()` | Kelsrick's own interpreter runs the alarm's commands on his locals 8/32/33/52, his B5/flags and the shared globals. |
| `jungle_village_gate.gd` `alarm_closed()` | The gate leaves 78/79 swing to 0 when the alarm reports target0. |
| `jungle_bacatta57*.gd` `shut()` / `shut_doors()` | The 56/57 door owner accepts an alarm shut without the threshold seal. |

## Chain (source)

1. **Arming.** Region3805 (the gate passage) g7956 runs on every entry:
   - op2 player 0x25 (receipt);
   - **control216 timer1 start**;
   - op210 music 0x12 (receipt).

   Bacatta57's g10162 starts the same timer.
2. **g27172.** It runs when timer1 expires (300 ticks) under predicate192 (`GV_HULINE_ALERT==1 AND local32==0`). Its
   21 commands:
   - **Kelsrick-owned:** local52=1, soul −2, local8=30, Kelsrick sub13+sub7 (hostile), local32=1 (the one-shot latch).
   - **control100 event20:** g21418 (local52==1) re-wakes Kelsrick hostile and sets alert=1; g21372 (local33==1)
     does the same for Anyar.
   - **Movables:** 79/78 property17 (receipt); 75/74 → 0; 56/57 → 100; 78/79 → 0.
   - **local7=2** (owned here).
   - **Timers:** control216 index0 and index2, control77, control217.
   - **op5 control82 selector0** (receipt).
3. **Bells.** Control216 index0 → g27162: op20 sound 403 at prop510 under predicate85 (alert). It repeats with a
   [0,5] s reload.
4. **Archers.** Control216 index2 (240 ticks, [2,5] s), control77 (300 ticks) and control217 (120 ticks) → op15
   sub-op93: an **Arrow** from the control at Luther. No source command ever stops these timers.

## Native facts (static LOLG.DAT, bounded)

- **op14 (B47B4).** byte4 = operation, byte5 = argument, byte6 = nth kind2 record. Operation3 (B485C) starts a stopped
  timer; a nonzero argument redraws its countdown.
- **op15 (B5C82).** byte5/word6 name the second object (kind1 0 = the player); byte4 indexes 0x5C6B4. Case 93 (B62A4)
  pool-allocates 0x72 bytes and calls F7030(obj, control, target, 7). That is FB838(obj, 0x5B, definition 12,
  owner), vtable 0x980C. Mode 7 (table 0x9DFD0 → F70A8) sets +0x58=3 and speed 0xFA00000. SPELL.ODF definition 12 is
  **Arrow** (name table ds+0xEB6C).
- **op20 (B5BDC).** E3924(0x23C68, word+4, object, ...) plays sound-bank request word+4 (403 = bells1.aud).
- **op9 (B50C0, table 0x5C010).** 2/3 unlink/link; 9/10 [+0x16] bit1; 13/14 [+0x15] 0x80; 17 sets [+0x15] 0x40;
  21 = event20.
- **Movable motion (63740/63890).** Raises 15 or 16 at its travel ends, then 17. g28168 (movable79 event16, alert)
  only re-arms timers g27172 already starts; it is reported, not separately produced.

## Deliberate mechanics changes (modern)

- **Arrows.** A visible bolt (no original sprite) at 900 units/s from the control position + 80. It is fired only when
  Luther is within 1400 with a clear line; otherwise that shot is held. Damage is 3. The native speed (0xFA00000),
  damage table and arrow presentation are not replayed. Arrows in flight are not saved.
- **Bells.** Not restarted while still playing (the reload may be 0 ticks).
- **Gates.** The village gate keeps its own collision-safe stepping when closing. 74/75 go to Kelsrick's inner gate
  owner (`jungle-inner-gate.md`).
- **Receipts.** op2 player 0x25, op210 music, op9 property17 on 78/79, and the region bits in g18864 are kept as
  saved receipts.
- **Control82.** An invisible logic marker (assembly template36: direct resource 0, type 0, no movie; lead control_movies.json), so op5 selector0 ends at once into g18846
  (78/79 → 0 again; nothing new to see).
- **local7=2.** Retires the separate, unimplemented drunken-villager encounter (control110, assembly template53 movie E105E.VQA, owned by the lead; props 484/485 sightings,
  region3355 block). No port consequence until that encounter exists.

## Tests

- **`tests/jungle_village_alarm_state_test.gd` (headless):**
  - arming;
  - no alert → inert;
  - alert → g27172 once, with the Kelsrick bundle order and g21418;
  - movable targets, local7, timers;
  - bells follow the alert; three archers repeat;
  - Bacatta57 arming;
  - JSON and validation.
- **`tests/jungle_village_alarm_live_test.gd` (rendered, real Jungle host):**
  - no alert inert;
  - supplied alert: passage → alarm, with Kelsrick hostile, soul 5→3, latch, gate and doors shut, bells, arrows
    damaging Luther;
  - disk save/load exact with no repeat;
  - pause frozen;
  - fresh-host resume;
  - atomic malformed packet;
  - Bacatta57's sealing entry arms the same alarm.
  - Capture: `village_alarm.png`.
