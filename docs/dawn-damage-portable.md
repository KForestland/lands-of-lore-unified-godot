# Portable player damage components

This update provides the calculation and defense components needed for Jungle Dawn's spell32. It also retains verified melee calculations. It does not implement Dawn's cast selection, projectile movement, visuals or player health writes.

`hive_damage_preparation.gd` applies the original unsigned heading window, guard and difficulty-mode adjustments. `hive_damage_calculation.gd` scales the spell by Dawn's factor10 and the supplied positive player magic level, then applies mitigation. `player_mitigation.gd` constructs the ordered equipment/form defense list and handles separate scalar/list bypass flags. Callers still supply actual equipment descriptors, stat parts, form/UI transition mode and effect flags.

Run without original-game assets:

```sh
godot --headless --path . --script res://tests/dawn_damage_portable_test.gd
godot --headless --path . --script res://tests/player_mitigation_test.gd
godot --headless --path . --script res://tests/dawn_spell_motion_test.gd
godot --headless --path . --script res://tests/dawn_spell_contact_test.gd
```

The tests compare 2,048 melee calculations, 5,760 spell calculations, 4,096 melee preparations, 294 spell preparations and 2,048 defense-list/spell compositions against numeric fixtures recovered through local native replay. The accompanying evidence manifest pins the executable used for that replay and the published files. Executable bytes and original media are excluded.

Spell inputs are deliberately validated within the verified domain: the six amount/signature pairs produced from the source request, scalar0..128 and magic levels1..30. Controller defense parts currently require nonnegative values. Stable and transitional UI modes must remain distinct; mapping a saved player form directly to a stable mode during a transition is not verified.

These checks establish component behavior, not complete combat fidelity, a rebuilt demo, full Act1 acceptance or Bob's playtest acceptance.

`dawn_spell_motion.gd` adds the original update-tail movement request, verified against1,029 numeric cases: native speed200 produces distance(delta×500)/60; signed vertical interpolation uses the original fixed-point floor. The caller supplies the native clock and planar distance. Constructor target binding and generic collision application remain separate; no live projectile is claimed.

The target snapshot now uses the source variant1 logical height20, with90 original constructor fixtures. `dawn_spell_contact.gd` preserves last-contact identity, counter, completion marker and heading across JSON save round trips. Its864 original callback fixtures cover repeated-contact suppression, collision128, strict travel threshold and capped heading correction. World collision production and the current-effect displacement adjustment are outside these tests; the caller still owns health application and the projectile update lifecycle.

The collision component also emits ordered post-hit lifecycle events: secondary-effect creation precedes zero-counter retirement; failed creation sets threshold100. The108 native lifecycle cases test cancellation, failed/successful creation and save continuation. Child-effect behavior and actual world application remain caller responsibilities. Movement input limits now cover the nonnegative signed32 delta×500 domain, signed32 planar distance and bounded signed height differences; oversized clock inputs are rejected before native multiplication would overflow.

Explosion98 damage calculation now covers2,880 original cases: mask16, signatures5/13, adjusted amounts1..40, caster factor10, target magic levels1..30, scalar0..128, and split-component mitigation. The original signed32 multiplication can overflow before scalar reduction; this behavior is preserved. Run `godot --headless --path . --script res://tests/dawn_explosion_calculation_test.gd`. Neighbor admission, heading/difficulty production and live health application remain separate.
