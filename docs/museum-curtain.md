# Museum curtain (control81, 2026-10-20)

Owner witness 2026-10-20 (original game in DOSBox, `~/lol2_original_screens/museum_20261020/orig_12-12-53.png`):
a fire/dragon tapestry hangs across a museum doorway. The port showed an open doorway there.

```sh
python3 tools/prepare_museum_curtain.py --game ~/lol2_runtime_root --re-root ~/lol2_re_publish_20260911
```

Writes `scripts/lol2/museum_curtain_source.json` and `assets/lol2/generated/museum_curtain/` (closed, gathered, eight
drawing frames, sounds 346/347). A changed archive, placement, owner record, group, predicate or image exits before
writing the contract.

## Source (L3_DH)

- **Static placement81**, template60, (-3820, height 1, native y 1084 / port z -1084), heading 16384. The face spans the
  x -3820 doorway (z -1164..-1004, height 1..95), just west of the Draracle-wing bar line (x -3789).
- **Template60 children on face2**, chosen by the assembly mode byte `[obj+0x3d]` (constructor 0x5B66A writes 0;
  renderer 0x5E156 draws a child when `mask & (1 << mode)`): child149 mask1 = descriptor181 (closed), child150 mask2 =
  descriptor61 (8-phase group 61-68), child148 mask4 = descriptor180 (gathered). Group frame0 is byte-identical to 181
  and frame7 to 180, so the group is the drawing of the curtain.
- **Control81 is this assembly.** Opcode5 on kind16 reaches vtable+0xB0 = 0x5D510, which returns early when the mode is
  unchanged and otherwise stores the new mode byte (0x5D558).
- **Records (stream1), predicates14/15 = owner state 0/1:**
  - kind4 value0 (empty-hand use), state0, g7036: op9 p14, **op5 mode1**, op7 0, **op20 sound347**, op9 p8.
  - kind6 value2, state0, g7076: **op5 mode2**, **op16 state1**, op9 p13.
  - kind4 value0, state1, g7100: op9 p14, **op5 mode1**, op7 3, op7 8, op7 0, **op20 sound346**, op9 p7.
  - kind6 value2, state1, g7152: op9 p13, op7 7, **op5 mode0**, **op16 state0**.

## Port

`museum_curtain.gd` draws the one face with the mode's image. E with an empty hand, aimed at the face centre within the
host's `can_reach_item` cone, runs the use group for the current owner state. The end of the drawing runs the kind6
group. A use during the drawing keeps the mode (0x5D510 no-op) and replays the sound. Saved in the Museum checkpoint as
`museum_curtain = {"version":1,"owner_state","mode","clock"}` (optional; a legacy save restores it closed).

## Adapters (disclosed)

- Drawing clock: 8 frames at 8 frames/s (the Museum's authored surface rate). The native group clock and the producer
  of kind6 value2 are not replayed; "value2 = end of the drawing" is inferred from the record pairs.
- op7 0/3/8/7 read as presentation: forward on open, reversed on close. Not proven.
- Drawn from both sides (one source face in a walk-through doorway); unshaded like the portraits.
- No collision: whether a closed curtain blocks the capsule natively is not established, so the doorway stays passable
  as before.

## Not hosted

op9 control81 properties 14/8/13/7.

## Checks

`museum_curtain_test` (registered, rendered): closed at load; refusals (held item, looking away); g7036 drawing +
sound347 → g7076 gathered; g7100 reverse + sound346 → g7152 closed; mid-drawing save/restore; eight malformed states
refused; legacy save restores closed; rendered samples change between closed and gathered. Negative control
(`use()` returning false) fails at "Empty-hand use refused".
