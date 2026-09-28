# Hive boulder damage calculation

The portable calculator matches 4,096 original-code replay fixtures. Source groups 10324/10404 create a player-targeted request with a null attacker, mask 256, flags 28, kind 4, tag 255 and raw amount 10. Mode 0 prepares amount 3, mode 2 prepares 20, and other byte values prepare 10. The caller must supply mode, current health, scalar and defense descriptors.

Flag 8 bypasses scalar armor. Flag 16 prevents reduction operations unless the matching descriptor filter includes that flag; it is not a second damage component. Null-attacker/tag255 final callback skips are verified. Twelve surviving health writes and twelve entry-gate cases were replayed; lethal outcomes, protection and equipment-to-descriptor binding remain separate.

Contact scanner evidence covers 243 proposed-position/reset cases and 768 single-candidate traversals. Event admission depends on the collision counter, callbacks and suppression state. This does not establish a timed cooldown or damage frequency. The live adapter now invokes this helper; see hive-boulder-contact-live.md for its explicit health and timing scope.

Run the asset-free comparison with:

```sh
godot --headless --path . --script tests/hive_boulder_damage_test.gd
```

The numeric fixtures and native reports are included. Native replay generators currently depend on the local reverse-engineering toolchain and a separately owned original installation; they are not included in this publication. No original game media or personal saves are included.

Validation: 4,096 boulder fixtures pass in Godot. Existing native EXEC/sword regression covers 2,048 calculations and 1,050 sword mitigation cases. This is progress toward Act One, not completion.

## Collision response evidence

Native displacement replay now covers 47,160 cases across player, WORM-with-peer and WORM-without-peer branches. It executes the original sine/cosine helpers against the previously reproduced, hash-pinned rotation table. Only the active mover with flag 0x100 receives the penetration correction. The no-peer WORM branch additionally decrements its counter and clears two flags. Signed fixed-point multiplication is replayed; SHRD is explicitly bridged. These cases use nonnegative penetration and cover the scoped slices rather than full callbacks.

The B3210 response has 2,016 stationary impulse/queue cases with supplied getter boundaries. A further 72 cases bind the original player and WORM getters, mover setup, definition and form records. The comparison values are WORM 255 and human/beast/lizard 125/200/50. In either contact direction, an initially zero player impulse becomes 130/55/205; the WORM receives no impulse in those cases. These values are movement response, not health damage or proof of movement speed. Actual B3B04 handling returns immediately for the player address, which is also replayed.

Already-moving participants call native 111AD4 to combine vectors. Its arithmetic and floating-point bearing conversion remain the next boundary, along with full callback composition and movement scheduling. No periodic damage cooldown has been established, and live contact now uses the documented modern adapter in hive-boulder-contact-live.md. Reports: `hive-boulder-separation-native.json`, `hive-boulder-velocity-response-native.json`, and `hive-boulder-impulse-binding-native.json`.

## Moving impulses

`hive_boulder_impulse.gd` now reproduces 4,096 original 111AD4 executions with exact fixture agreement for bearing, length and the stored low-word/low-byte results. The native harness executes the sine lookup, Euclidean distance, FPATAN and conversion helpers as 32-bit x86. Only absolute data addresses are relocated; original constants and the independently reproduced rotation table are hash checked. The portable sine-table formula was compared against all 4,096 reproduced table entries with zero differences. Hardware FPATAN is selected explicitly; the original running game's FPU mode remains unobserved, so the helper requires an explicit rounding mode.

The tested combinations cover all four rounding modes and incoming impulses 130/55/205 with previous magnitudes 0..255. Result magnitude can wrap when narrowed to the native byte. The Godot helper preserves that behavior. This arithmetic now supports saved live momentum; contact admission and movement-attempt scheduling use the documented adapters in hive-boulder-contact-live.md. A contact-entry latch was suggested in advisory review but rejected because it would replace the observed attempt-based source admission.

Portable check: `godot --headless --path . --script tests/hive_boulder_impulse_test.gd`. Native numeric report: `hive-boulder-vector-native.json`. The local generator is `tools/verify_hive_boulder_vector.py`; it requires the existing private original installation and RE toolchain.
