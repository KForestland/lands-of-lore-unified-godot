# prop83 side chamber: audit, access and animated props

`tools/prepare_cave_side_chamber.py` pins the records. It writes `scripts/lol2/cave_side_chamber_source.json` and stages 30 index frames in `assets/lol2/generated/cave_side_chamber/` (local, original media).

## Audit (regions 1020..1033, 1815..1822)

**What was checked:**
- every prop and static assembly placed in these regions;
- their owner records;
- every command in both L1_DC streams that targets them.

**Findings:**
- **No reward:** no item grant, no use (kind4) record and no reward of any kind.
- **No records:** controls 59/60/61/72/73 and props 139-143, 200/201, 448-452 and 610-614 have no records of their own (prop614 has only a startup sound).
- **Region entry:** regions 1815/1817/1818 (g2040/2070/2100) run op12 ED6D0(0x20), which is audio, and an op18 whose flags word lacks bit 0x20, so nothing is queued.
- **Ambient animation:**
  - prop1362 (template19, region420) runs a kind2 timer (flags 0x30: 1 s, running).
  - op23 then sets its state to a random value 0..9, and op9 property21 on itself raises event20 (B5448 → ADDE0).
  - Its event20 records for states 1..8 send property21 to props 559/558/557/564/563/561/560/562.
  - Each of those props' own event20 record runs op7 (2,0) then op7 (0,0): a splash.
- **Not drawn in the port:** the recovered prop preview omits animated props, so none of these were visible:
  - the waterfall 142/143 (template81, 5 frames);
  - the mist 139-141 (template90, 10 frames);
  - the splashes 557-564 (template74, 15 frames; 557/558/559 stand in the main cave, regions 981/995/1000).

## Access (strict shared-edge check)

The check walks region to region and admits an edge only if, at both shared vertices, the step is at most 24 and the clearance at least 72, using per-vertex source floor and ceiling corners.

- **The prop83 opening** makes wall regions 1029..1033 walkable from 1037..1041, plus corridor 1820..1822 through the 18-unit sliver 1033.
- **The main chamber stays sealed** (1020..1028, 1815..1819, holding the centrepiece, statues and splashes 560-564). Its edge regions 1026/1027/1028 are source slopes (floor_slope, corners −192 → −32) that meet the wall edges at −32, where the ceiling is also −32.
- **Correction:** an earlier lenient walk had reported the whole chamber as opened.

## Port

- **Owner:** `cave_side_chamber.gd` draws all 13 animated props as indexed layer-2 billboards (the cave's visible index viewport), mirrored into the mask pass.
  - 139-143 loop.
  - 557-564 play one splash when prop1362's 1 s sequencer draws their state.
  - It uses the world-active gate and a seeded generator.
  - Its state is not saved (ambient).
- **Fixes to the frozen lift release** (`cave_prop83_lift.gd`, additive here):
  - **Prop83's collider:** it stood on layer 2, which the cave player collides with, and kept blocking region1040 after property16 removed prop83. It is now disabled once prop83 is gone.
  - **The opening:** it adds walls on wall-region edges with no neighbour or with a higher neighbour floor at the shared vertices. Those are the chamber slopes at −32, so the chamber stays sealed, as in the source, instead of showing a void.
  - **The alcove ceiling:** a rock ceiling at −32 replaces the old top faces of the zero-height regions. `prepare_cave_prop83_lift.py` now records each wall-region edge's neighbour floor and ceiling at the shared vertices.

## Adapters

- 10 frames/s animation.
- op7 (2,0), (0,0) is played as one splash from frame0.
- The sequencer randomness is seeded and not saved.
- Region-entry audio and markers 610/614 are not hosted.

## Test

`tests/cave_side_chamber_live_test.gd`:
- A grounded walk from prop83's floor into the opened regions 1031/1032 on the −192 floor (ray-checked at every waypoint).
- Walking toward the sealed chamber does not get in.
- All 13 props are on the indexed layer-2 path with mask mirrors.
- Main-cave splash 558 plays.
- Loop frames, a one-shot splash, the seeded sequencer and the world gate.

The 1033 sliver toward 1822 is not walked, because the port capsule jams in it.
