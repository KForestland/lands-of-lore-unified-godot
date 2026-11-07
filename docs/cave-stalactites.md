# Cave dripping stalactites (template72) and prop83's later art

`tools/prepare_cave_stalactites.py` pins the records and stages `assets/lol2/generated/cave_stalactites/` (index frames of descriptors 862/872/882/887/897, prop473's four frames, sounds 221/298/718/759) and writes `scripts/lol2/cave_stalactites_source.json`. Two runs are byte-identical; existing output is refused.

## Source (L1_DC)

Props 359, 632, 633 and 634 (template72, five selectors) start at selector0 with placement durability byte30 = 10. Each prop owns, in record order:

| Record | Admission | Commands |
|---|---|---|
| kind9, owner state 0 | masks 0x0907/any, threshold 9, mode 4 | op5 selector1, op16 state1, sound 718 |
| kind9, owner state 1 | masks 0x0907/any, threshold 5, mode 4 | op5 selector2, op16 state3, sound 718 |
| kind9, local10 == 0 | masks 0x0906/0x0004 (melee) | local10 = 1, op2 sub7 arg10 (D8A1C fighting 10), sound 221 |
| kind9, local10 == 0 | masks 0x0001/0x0001 (Spark) | local10 = 1, op2 sub8 arg10 (D8B94 magic 10), sound 221 |
| kind3 selector 0/2 | — | op9 property16 (stop the prop's sounds) |
| kind3 selector 1 | — | sound 759 |
| kind4 mode0 (own local 21/22/27/28 == 0) | — | local = 1, sound 298 |

The native hit scanner AE2C8 runs only the first admitted record per hit. Prop359 repeats its state0 record at the end. Local10 is shared by all four props, so the 10-point award happens once per level.

Template92 (prop83) has selectors 19/882/897; prop83's chain selects 897.

## Port

`cave_stalactites.gd` draws the four props as indexed layer-2 billboards (10 frames/s), replays the admission over the pinned records (masks, mode4 threshold against the remaining durability, predicates, first match) and runs their commands: selector and state, sounds, local10, the fighting/magic awards through `player_property_rewards.gd`, sound stop for property16. Melee: an armed left click at an aimed stalactite (context 2/4, form melee damage). Spark: the shared ray (context 1/1, 8). E: the kind4 record. The player does not collide with the hit volume. Saved as `cave_stalactites`; `walkthrough_save.gd` validates selector/state pairs.

## Adapters and limits

Durability decreases by the port's melee/Spark damage (native damage calculation not replayed). Animation clock 10 frames/s. No prompts are shown (the original has none). Prop collision is not modelled. Native object sound channels are approximated by one 3D player per request.

Test: `tests/cave_stalactites_prop83_test.gd`.
