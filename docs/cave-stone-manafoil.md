# Cave Ancient Stone (prop1050) and Mana foil (control75)

`tools/prepare_cave_stone_manafoil.py` pins both producers. It writes `scripts/lol2/cave_stone_manafoil_source.json` and stages the stone sprite, the box material and both item icons in `assets/lol2/generated/cave_stone_manafoil/` (local, original media).

## Coverage before this slice

Nothing in the port owned prop1050 or control75. The same items existed only from other sources:
- The Hive rune-room Ancients' Stone (`hive:runes:Ancients_Stone`, use `ancient`).
- The magic-shop Mana foil (`jungle:magic_shop:Mana_foil`, no use).

## Source

**prop1050** (template53, sprite prop_477, region751):
- Kind4 mode0 at owner state0 (group8846):
  - op9 property16 on itself: B5401 calls E416C(23C68, prop, 1), handing the object to the native hand presentation.
  - op3 "66-Ancients stn" (definition68, handler6, identity 0xE0649CBA).
  - op16 state1.
- Its kind6 event9 record (group8876, the startup scanner) only plays a sound.

**control75** (static assembly template46, at the bottom of the region-506 shaft at height −1000):
- Child85 is always shown. Child86, carrying resource93 (an encoding the exporter rejects), is shown only at selector0.
- Kind4 mode0 while local16 == 0 (group9750):
  - op2 player sub 0x29, which goes to D86B6: a first-time help screen (player +0x20C bit0, 73FF0(1)).
  - op198 local16 = 1. Local16 is shared with the stalagmites, the captain and other first-pickup records.
- Kind3 value1, raised when selector1 is reached (group9768): op3 "131-Mana foil" (definition133, handler43, identity 0xC221EB6B).
- **No selector-1 producer was found in the audited scope.** This is not proof that none exists.
  - Every command in both L1_DC command streams (owned and unowned groups) was scanned: none is an op5 targeting control75.
  - The only direct `E8` caller of the selector setter F2944 is A7DC4, the class virtual that op5 reaches through vtable +0xB0.
  - Computed or indirect virtual calls to +0xB0 were not enumerated, so a native producer reached that way is not excluded.

## Port

- **Owner:** `cave_stone_manafoil.gd`.
  - Saved by the cave host as `stone_manafoil`: the collected ids, at most two, unique.
  - `walkthrough_save.gd` validates the list. A consumed Cave stone must have been picked up: the consumed-item check now covers the stone as well as Aloe.
- **Host wiring:** E through `cave_walkthrough._update_interaction`, the shared interaction prompt, and `carried_items()`, which filters consumed ids.
- **Ancient Stone use:** generalised from the Hive id to every `ancient` use (`player_item_controller.gd`, the charge-history check in `player_item_state.gd`). Both stones are definition68/handler6 and share the player counter byte.
- **Catalog:** both items have origin `cave`, plus names and shop info.

## Rendering fix (lift patch)

The released owner drew the stone sprite, the foil marker and the box with RGB materials on the default layer 1. The cave's final image is its layer-2 palette-index viewport, so they were not visible.

They are now indexed layer-2 meshes mirrored into the mask pass:
- the stone as `prop_477_index.png`;
- the foil marker as an index image mapped to the L1_DC DAC palette by nearest colour;
- the box as `wall_indices/material_86.png`.

## Adapters

- **Pickup:** E at the aimed pickup in reach.
- **Stone:** hidden after the take.
- **Mana foil:**
  - E runs group9750 when local16 is 0; the help screen is not hosted.
  - E then advances the selector to 1, which runs the source kind3 group9768 grant once. There is no source writer for this selector.
- **Foil marker:** the item icon stands in for the undecodable displayed child above the box.
- **Not traced:** whether the shaft floor at −1000 is reachable along the playable cave route.

## Debug-kit props (classification)

L1_DC prop343 and L4_HJ prop1913 each own one kind5 value19 group that grants a whole kit:
- **Cave (16 items):** Pyra pod, Ancients stn, Guardian orb, six Cave aloe, Guard shield, Brnt Chain, Lt crosbow, three Rocks, Halberd.
- **Jungle (13 items):** Prism, Pois paint, Skull key, SumScrl, Long arm, SS1, two Ancients stn, Guard shield, Dragon gem, Mail shirt, Lt crosbow, Fine longswd.
- Both also run player op2 0x0D/0x0E.

`tools/audit_debug_kit_props.py` checks the following scope (`docs/debug-kit-props.json`):
- All 17 direct `E8` call sites of the kind5 dispatcher AD8E0. Each pushes a constant in {0,1,2,3,5,6,13..18,20}; F6C87 passes the masked touch flag, which is 0 on that path. None passes 19.
- Every op9 command in both command streams of L1_DC and L4_HJ: none sends property 19 to either prop.

Indirect or computed calls to AD8E0, and other areas' commands, were not enumerated. Within that scope no producer exists, so both are classified as unreachable debug/test kits and are not implemented.

Test: `tests/cave_stone_manafoil_live_test.gd` (registered in `tools/run_regressions.py`).
