# Museum wheel door (static assembly / control80)

Behind the curtain (control81, `docs/museum-curtain.md`) a marble wall closes doorway region1232. It separates the west room (region1218, where the curtain hangs) from the east hall (regions 1160/1164). In the longplay (19:02–19:06) the player gathers the curtain, clicks the marble, and it swirls into a round vortex and vanishes, opening a dark passage.

```
python3 tools/prepare_museum_wheel_door.py --game ~/lol2_runtime_root --re-root ~/lol2_re_publish_20260911
```

## Source (L3_DH)

- **Placement80**, template61, at (-3809, height 0, native y 1091), heading 49152. Placement bytes are pinned.
- **Template61 child151:** a closed 12 × 70 × 85 box over x -3815..-3803, z -1126..-1056, filling the doorway up to its 85-unit ceiling.
  - West face: resource138, a 40-phase group. It runs from plain marble (phase 0) through the vortex to fully transparent index 0 (phases 35–39).
  - East face: resource227.
  - Other faces: resource31.
- **Control80 records (stream1, no predicate):**
  - kind4 value0 (empty-hand use) → g7008 `[op7 control80 sub0, op0x14 sound342]`: play the phase group with sound 342.
  - kind6 value2 (end of the group) → g7030 `[op9 control80 property2]`: B49EC unlink, so the assembly is removed and the doorway is open.
  - No other group in either stream addresses control80. The producer asserts that, and all groups byte for byte.

The door is independent of the curtain's state. On the west side the curtain simply hangs in front of it.

## Runtime (`scripts/lol2/museum_wheel_door.gd`)

- **States:** 0 linked, 1 playing, 2 unlinked.
- **Saved as** `museum_wheel_door` = `{version, state, clock}`. `museum_save.gd` validates it, and a missing field loads linked.
- **Drawing:** the box is drawn with back faces culled, so the passage shows through the transparent final phases. The owners list (`static_assembly_owners.json`) takes assembly 80 out of the generic static pass: the museum now has 92 drawn, 26 owned.
- **E (empty hand)** works when aimed anywhere on the face you stand in front of, within 96 units, with nothing in the way:
  - From the west, the closed or drawing curtain takes the click. Only the gathered curtain leaves the wheel reachable.
  - From the east hall, the east face is usable directly.

## Adapters (deviations list)

- **Clock:** 15 frames/s, measured from the longplay (40 phases in about 2.7 s). The native op7 clock is not replayed.
  - The curtain's adapter uses 8 frames/s, but the longplay shows it at about 16. Not changed here.
- **Collision:** the box blocks the player while linked. Static-assembly collision is not traced natively, but the end group's unlink of a box that exactly fills the doorway means it closes the passage until used.
- **Side choice:** E from the east face is allowed (kind4 belongs to the whole assembly), so the door can never trap a player on either side.

## Test

`tests/museum_wheel_door_test.gd` (rendered) covers:
- At load the door is linked, solid and not drawn twice; walking east is stopped at the west face.
- The closed curtain takes the click. Once the curtain is gathered, a level-gaze E (no `look_at`) runs g7008 with sound 342.
- Frame 15 at 1.0 s; a mid-group save round trip.
- g7030 unlinks the door and the passage becomes walkable.
- East-face use; refusals (held item, looking away); malformed states refused; legacy save restores the door linked.

Negative controls: with the barrier layer off the test fails at load, and with the collision shape disabled it fails with "Walked through the linked wheel door".
