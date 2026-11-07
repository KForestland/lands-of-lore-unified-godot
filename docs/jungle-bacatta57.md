# Huline Jungle: village-entry Bacatta (prop482 → actor57), 2026-10-07

Once Bacatta's relationship has dropped to 0 (after the CAN farewell or the rude jungle branch), the next time Luther
enters the village threshold the village double door swings shut and the threshold is sealed. Bacatta57 stands
outside, non-hostile. This is a fixture-tested slice on the real Jungle host; it is not earned-route or owner
acceptance.

| Source → output | What |
|---|---|
| `tools/prepare_jungle_bacatta57.py` → `scripts/lol2/jungle_bacatta57_source.json`, `jungle_bacatta57_population_source.json` | Byte-for-byte pins: region3501 g7026, prop482 event20 g10162, region3157 g5570 and predicates 173/167. Also the control216 timer rows, the actor57 placement, the op18 return point, region polygons and the native new-game globals. A completeness check proves that every group naming actor57, prop482, movables 56/57 or region3501 is pinned or attributed to its other owner. |
| → `assets/lol2/generated/jungle_bacatta57/` | Local only, never published. Movables 56/57 (template82, 41 faces each): 101 hinge poses from the source rest faces and the native rotation model, plus the original textures. |
| `scripts/lol2/jungle_bacatta57_state.gd` / `_packet.gd` | The pure source-chain state and atomic packet validation. |
| `scripts/lol2/jungle_bacatta57.gd` | The live controller: region producers, doors, threshold seal, return point. It drives the generic creature owner for actor57 using the BACL4 sprites staged by the Bacatta65 media preparer. |
| Host (`jungle_walkthrough.gd`, `act_one_quest_state.gd`, `player_spark_aura.gd`) | Setup, save/restore (`quest_state.jungle_bacatta57`), context with native global defaults, and spell targets. |

## Story chain (source)

1. **Every threshold entry.** Region3501 (the existing VILLAGE room entrance) runs g7026:
   - room12 VILLAGE (op12, owned by `monastery_rooms.gd`);
   - prop482 event20;
   - op18 return point (-1718,-3961), just outside the doors.

   Predicate173 `GV_BACATTA_RELATIONSHIP==0` is tested when event20 is queued (ADDE0).
2. **g10162.**
   - `op14 control216 3/0/1`: starts timer record 1, 300 ticks → g27172. That group runs only under the Huline alert
     (predicate192): gates 78/79 shut, 56/57 to 100, Kelsrick hostile. **Unowned: reported, not run.**
   - `op197 region3501 sub2`: region bit0, the player-impassable bit.
   - `op1 kind32 56/57 → 100`: the double door shuts.
   - `op9 57 property3`: links Bacatta57 at (-1738,-3974), outside the door.
3. **When relationship==0 happens.** The native new game starts it at **1** (GLOBAL.MIX; also soul 5 and Dawn
   relationship 1). The first visit therefore runs nothing. CAN.WOM's exit routine (0xE09) sets it to 0, so the
   *next* entry runs g10162. The rude jungle branch (g11072) also sets 0.
4. **Removal.** Region3157 (`GV_MET_BACATTA==1`) runs op9 property2 on 57 (and 65, which jungle_bacatta65 owns).

## Native facts (static LOLG.DAT, bounded)

- **op14 (B47B4).** byte4 = operation, byte5 = argument, byte6 = the nth kind2 record. Operation3 (B485C) clears the
  stopped bit.
- **op197.** Dispatcher 64770 → 64CD4; jump table 0xBC84 is resolved through fixups. sub2 = region[+0x1C] |= 1.
  B0D98/AFF85 return "blocked" for bit0. The village gate sets bits 0|1 when closed and clears bit0 when opened.
- **op1 kind32.** Movable travel target in percent, the same encoding as the village gate's g4354. For 56/57, 100
  swings both leaves about the corners of region3501's west edge until their free ends meet (1.92 units apart with the
  native rotation table). At 0 they are folded open.
- **Attitude.** g10162 sets no op13 hostility (contrast 65's g12514 and Kelsrick in g27172). B5 bits 0x0C are clear
  whether B5 starts zeroed or comes from placement byte33 (0x20, as for the friendly villagers). Bacatta57 is
  **non-hostile**.

## Deliberate mechanics changes (modern)

- **Doors.** 1.5 s swing with collision. A pose whose sweep would hit the player waits; there is no native pushing.
- **Seal.** A collision prism over the region3501 polygon, active once sealed whenever the player is outside it. The
  port does not otherwise honour source region-block bits.
- **Return point.** Natively g7026's op18 runs on every entry. The existing room owner keeps the player inside
  instead, and that flow is unchanged. Only once the threshold is sealed is the return point applied, after the
  VILLAGE room has closed (or 0.25 s if no room opens). Luther then faces Bacatta. The point lies 24 units from her,
  so physics may separate the two capsules.
- **Bacatta57.** She stands at her placement in the dormant idle pose; A7544's behaviour-4 AI is not replayed. A strike
  sets B5 0x0C and she fights through the generic owner, like Bacatta65's peaceful body.
- **Globals.** An absent monastery global reads its native new-game value (`_native_global` in the host). This applies
  to Bacatta65's hooks too, so its offer now takes the relationship 1→2 and a late hit takes soul 5→4. Other owners
  still read 0; that cross-owner fix is reported to the lead.
- **Unbound.** The control216 alarm (g27172) and g7026's op9 property10 on props 484/485/428/429 and control100 have
  no port owner. They are reported as effects.

## Tests

- **`tests/jungle_bacatta57_state_test.gd` (headless):**
  - native globals, and the relationship-1 entry is inert;
  - g10162 effects and order;
  - door clock;
  - strike → hostile once;
  - region3157 needs MET;
  - JSON round-trip;
  - unreachable/malformed branch and packet rejection.
- **`tests/jungle_bacatta57_live_test.gd` (rendered, real Jungle host):**
  - absent globals read native values in both hooks;
  - control: a walk enters the open threshold;
  - first visit opens VILLAGE with 57 inert;
  - supplied post-farewell flags (relationship 0, met 1): re-entry seals, the room still opens, then the return point
    is outside;
  - mid-swing disk save/load is exact, and the doors shut with Bacatta57 present;
  - the same walk can no longer enter, and the room does not reopen;
  - fresh-host resume;
  - strike → hostile, persisting;
  - region3157 removal, persisting;
  - atomic malformed packets.
  - Captures: `bacatta57_doors.png`, `bacatta57_outside.png`.
