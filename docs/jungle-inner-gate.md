# Huline Jungle: Kelsrick's inner gate (movables 74/75), 2026-10-07

The original double gate behind Kelsrick (template43, carved Huline masks) now stands in the Jungle. It is shut at rest
and opens through its source producers. This is a fixture-tested slice on the real Jungle host; it is not earned-route
or owner acceptance.

| Source → output | What |
|---|---|
| `tools/prepare_jungle_inner_gate.py` → `scripts/lol2/jungle_inner_gate_source.json` | Byte-for-byte pins: the 5 owned records (g5160, g21138, g21156, g27916, g27934), predicate191, regions 2752/2750. A completeness check attributes every other record naming 74/75 (g5084 Kelsrick, g27172 alarm, g4442 and g14086 unowned). |
| → `assets/lol2/generated/jungle_inner_gate/` | Local only, never published. Both leaves (4 faces each): 101 hinge poses from the source rest faces and the native rotation table, plus the original textures. At rest the free ends meet, 0.39 apart (shut). |
| `scripts/lol2/jungle_inner_gate_state.gd` / `jungle_inner_gate.gd` | The pure state (per-leaf target and clock) and the live controller (leaves, collision-safe stepping, region2752, E-use). Saved as `quest_state.jungle_inner_gate`. |
| Host | Kelsrick's `effects` hook and the alarm's `inner_gate` hook pass their raw commands to `external()`. For a save without a gate packet the gate starts open if Kelsrick's receipts already hold his talk1-end `051062000100`, otherwise shut. |

## Source chain

- **Open:**
  - Kelsrick's talk1 end g30684 plays control98 selector1. Control98 is an invisible logic marker, so its "clip" ends at
    once into kind3 value1 = g21156: both leaves → 100.
  - Entering region2752 (the far side), g5160: both → 100.
  - Plain use (kind4 mode0) on a leaf while `GV_KELSRICK_DEAD==1`: g27934 (leaf 75) opens both. g27916 (leaf 74) opens
    74 only, because both of its commands name 74 (source quirk kept).
- **Shut:**
  - Kelsrick's region2750 g5084 (local6==0, talk2 on the gate line): 74/75 → 0 directly and through control98 selector0
    (g21138).
  - The village alarm g27172: 74/75 → 0.
- **Upstream-blocked (N3 classification):** g4442 (region2443, p111 alert==0 AND local6==1) and prop561 g14086 both
  follow the unimplemented water-gate / chief's-hut smoke-out puzzle:
  - control96 selector1 ends set local11 `Is_water_level_up`;
  - prop566 g14260 then sets local6 `Has_Luther_smoked_the_Cheifs_hut` and links prop561.

  No room DLL writes these locals. They stay reported, not stubbed.
- **Unreachable:** g18864 (control82 value1: region3811/3805 op197 sub0, 78/79 → 100). No source command plays control82
  selector1. Its region bits are covered in the port by leaf collision.

## Deliberate mechanics changes (modern)

- 1.2 s swing per leaf. The leaves open south across the passage, so a leaf holds its whole remaining swing while
  Luther stands anywhere in it. On the earned crossing, g5084 (stepping onto the gate line) therefore shuts the gate
  behind Luther instead of stopping it half-closed in his path. Native pushing is not replayed.
- **Masks.** The carved masks are exactly coplanar with the leaf faces (the native renderer paints them last). They are
  drawn 0.3 units outward to remove z-fighting; collision keeps the source vertices.
- E aimed at a leaf within 110 units triggers the use records. Only the source predicate (Kelsrick dead) makes them act.
- Earlier the port had no gate here. Passing south now needs one of the producers above, typically Kelsrick's first
  conversation.

## Tests

- `tests/jungle_inner_gate_state_test.gd`: the producers, leaf independence, the clock and validation.
- `tests/jungle_inner_gate_live_test.gd`:
  - shut at rest blocks the walk 3567 → 2752;
  - Kelsrick's real g30684 group (his own effects path) opens it;
  - mid-swing disk save/load is exact, and the walk then passes;
  - g5084 shuts it behind Luther, and region2752 reopens it;
  - the alarm shuts it;
  - use acts only after Kelsrick's death;
  - legacy receipt migration;
  - atomic malformed packet.
  - Capture: `inner_gate_shut.png`.
- **Earned:** `hive_quest_walk_test.gd -- --kelsrick-inner-gate` (fixture `tests/fixtures/kelsrick_inner_gate_routes.json`,
  source-neighbour BFS with portal widths ≥64 and clearance 127):
  - from the original Hive spawn, through the village gate (gate villager speech completes naturally);
  - to Kelsrick region3567: his talk1 runs at natural timing, and its end (g30684 → g21156) opens the gate;
  - then the walk crosses region2750 (g5084 shuts it behind) via 2753 into region2752.
  - No position or quest flag is injected after the spawn.
