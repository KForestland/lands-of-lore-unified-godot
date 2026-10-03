# Rune-dependent Hive warrior copies

Actors21/22 are HIVEW templates used by a missing rune-dependent population action. They are not ordinary enable-only return warriors. Source group420 requests property20 on actor22 and then actor21 when shared9 (`GV_HAS_RUNES`) equals1. Prop76 owns both startup-event9 and event20 records for this group. Region284 event2 invokes group150, which sends property21 to prop76; that property emits event20. Existing source predicate/event verifiers establish the admission rules separately.

Property20 calls native A6828. It selects the first **allocated** creature slot whose flag0x800000 is set. A merely unallocated pool slot is not eligible. It copies188 bytes from the template, preserves the destination inventory pointer, attaches the copied actor to the active list, and requests enable1 and event23. If no eligible slot exists, it copies nothing. The property setter nevertheless clears the template word7C and returns success. A reported successful command therefore does not prove a spawned actor.

The template positions are actor21 `(-1023,-235,-8185)` and actor22 `(189,-140,-4949)`, each with requested health400. Selection is ordered22 then21; two available slots can receive two separate copies. Repeated triggers must use current slot availability, not a permanent two-enemy toggle or unrestricted instantiation.

## Recycling after death

The original HIVEW definition byte77 is5. The zero-health outcome copies that byte to actorAE. Native updates decrement AE only in behavior15. Values0 and255 remain unchanged; B4bit20 holds an expiring counter at1. The ordinary AA16 cleanup branch waits for AE0 and the shared cleanup gate96A38 to be clear. It then requests event12 and invokes removal, which marks0x800000 and detaches the actor from the active list. Empty-inventory, direct-region removal is replayed through the actual list code; event effects, final disable, nonempty loot disposal and the update clock remain boundaries.

This corrects two tempting assumptions: health0 alone does not make a slot reusable, and a corpse is not necessarily permanent. The current live restoration keeps warrior corpses indefinitely and does not run group420. The next implementation should add saved corpse retirement and finite slot reuse together, preserving slot identity, generation/defeat history and inventory ownership. A documented modern time mapping can drive the proven counter; inventing unlimited spawns or recycling every dead actor immediately would change the encounter.

## Evidence

`tools/verify_hive_rune_population.py` passes512 property-setter cases and512 allocated/reusable slot-selection cases. It pins source commands, owners, template records and native dispatch. Native bitmap lookup and queue insertion execute; copying and selected world callbacks are explicit boundaries. See [copy report](hive-rune-population-native.json).

`tools/verify_hive_corpse_reuse.py` passes1,536 counter cases and512 ordinary cleanup admissions. It binds the actual HIVEW counter and AA16 dispatch, including native removal/list detachment for the scoped fixture. The replay explicitly bridges SETE and JNE-after-DEC because the shared interpreter does not retain DEC flags. See [retirement report](hive-corpse-reuse-native.json).

Both generators use the local RE toolchain and a separately owned original installation. Numeric reports contain no original media or saves. These are verified prerequisites, not live rune-encounter integration or Act One completion.
