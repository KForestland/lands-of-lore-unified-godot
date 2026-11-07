# Museum torch switch (L3_DH)

Producer: `tools/prepare_museum_torches.py --game GAME --review L3_DH_REVIEW_JSON --output scripts/lol2/museum_torches_source.json`
(media to `assets/lol2/generated/museum_torches/`, local only). Host: `scripts/lol2/museum_torches.gd`, saved as
checkpoint `museum_torches`. Test: `tests/museum_torches_state_test.gd` (headless).

## Native chain (PROVEN from the L3_DH records, asserted byte for byte by the producer)

1. Props start at owner state 0: the object init at 0xAE990 (VA) copies placement words and byte30 (durability,
   to +0x26) and writes `+0x25 = 0`; +0x25 is the owner state that predicates of operand type 5 read
   (verify_hive_executioner.py emulation at 0x66AB0).
2. **Movable52** (the wall plate in niche region 1475/1476), kind4 mode0 (empty-hand use): op16 prop61 state1.
   Its kind6 value16 (a travel end) sets prop61 back to state0; what starts that travel is untraced.
3. **Prop61** (the small pilot flame, durability 2), kind9 masks 0x0011/0x0001, threshold 1, mode4, one-shot,
   predicate207 (owner state == 1): flare (selector1), sound 740, one magic level (op2 sub0x10, D88CD),
   then event20 (group70): op19 hits (masks 1/1, damage 5) on 35 torch props, a screen shake, sound 411 at
   prop63, prop61 state1.
4. **35 torches** (template22, durability 1), kind9 threshold 1 mode4, not one-shot: lit selector and sound 740.
   Any single torch can also be lit with Spark.

So in the original the player presses the plate, then Sparks the small flame; a Spark before the plate does
nothing. The owner's recollection (2026-10-28: "spark the small torch and every torch lights") matches step 3;
the plate press is the native precondition.

The 2026-10-28 Museum audit counted 18 wall torches; group70 hits 35 distinct props, all template22.

## Not hosted

See DEVIATIONS 2026-10-28 (Museum torches): torch light properties (lighting chunk), screen shake, plate travel
reset, fire-bit (0x10) hits from Firestorm/fire crystal.

The geometry review is an explicit input, checked before any generated output is written. Use the original L3_DH all-maps review with SHA-256 `8af16e5dcc1e02a2fa8eea985649211993a5771b41b7fb183e5cb1e45258ab8d`. A different export is refused; changing this contract requires reviewing its geometry. `--game` is passed directly to the source reader and takes precedence over `LOL2_GAME_ROOT`.
