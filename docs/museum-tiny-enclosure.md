# Museum Long arm chute: tiny-form enclosure (softlock adapter)

Owner r3 playtest report `report_2026-10-20T11-20-57_790051341` (Museum, X −1764.7 Y −1089.8): stuck human in a low
sloped tunnel with a magenta floor. The quicksave from 13:19 holds the same spot (−1771.8, −10.56, −1088.0), human,
no transformation pending.

## Source geometry

`tools/prepare_museum_tiny_enclosure.py` pins the regions from the published L3_DH geometry
(`museum_geometry_20260913/geometry.json`, sha256 `bae648d2…`) into `scripts/lol2/museum_tiny_enclosure_source.json`.

- Region 965 is the centre lane of a 44° chute (floor −10 → −170, ceiling 40 → −95, "Sludge" preset 17). The side
  lanes 963/957 (60 high), the top landings 959/960/961 and the bottom 962/964/966 complete it.
- These 9 regions are the clearance ≥ 46 (human height) neighbour component of 965. Their only exits are region 967
  (clearance 30, the duct mouth, itself a human-return region) and region 958 (clearance 20, toward the Long arm pit
  tunnel). Both are static (no owner). A human or beast standing in the chute can never leave it.
- Longplay 26:47–27:06: the small form crawls up this chute and turns human at the duct mouth, then walks out to the
  orb hall.

## How the trap happens in r3

The shared curse checks room only where the player stands. A pending human return (a timed form running out, or the
mouth request at 1463/967 while entering from the hall) waits at 967 (no room) and completes in the first spot inside
the chute where the human body fits (the flat side-lane bottom 964 in a grid probe). With the Museum walking controller
a human then slides down the 44° centre lane and cannot climb past x ≈ −1772 (967 is 30 high); the bottom exit 958 is
20 high. The tiny form climbs the same chute to x −1956 without help.

## Adapter (modern)

`scripts/lol2/museum_tiny_enclosure.gd`, hosted by `museum_walkthrough.gd`:

- **Hold tiny inside:** `player_curse.advance` asks the host `form_change_blocked(target)`. Inside the chute every
  morph except to form 2 waits, as when there is no room ("You need room to change back").
- **Rescue:** a player who is already human or beast inside the chute (older saves, F9) with no transformation
  pending gets the held tiny form (phase 1, duration 0, the Cave region631 held-form shape). This bypasses admission
  and the nonhuman → nonhuman refusal, like the Long arm owed form. The duct human-return regions end it as usual.
- **Shrink on the slope:** `form_change_unchecked(2)` skips the room query inside the chute, because the tiny
  cylinder's rim always meets the 44° slope; the mover resolves it.

Other hosts lack these hooks, so Cave, Hive and Jungle behave exactly as before.

## Not proven

- Whether the original checks room only at the current spot, and whether the original can trap a human here. The
  original's player collision is not modelled (a vertical 46-unit clearance would let a human stand anywhere in the
  chute, still with no exit).
- The owner asked for periodic random beast/lizard changes. The original has a periodic random curse countdown in
  the Hive (120–255 s, `hive_curse.gd`), but none was found for the Museum; it is not added here.

## Magenta floor (not fixed here)

The magenta is the review's debug colour for floors whose texture is not in the extracted material set. All 47 such
Museum floors (including this chute, the duct mouth corridor 1428–1463 and the Long arm walkway regions 167–176 and
204–220) bind preset 17 "Sludge", resource 21. The longplay shows it as a green moss/slime floor. Resource 21 is not in
`materials.json`; it likely needs the same phase-group decoding as the Cave lava (`prepare_cave_animated_floors.py`).

Test: `tests/museum_tiny_enclosure_test.gd` (registered, headless).
