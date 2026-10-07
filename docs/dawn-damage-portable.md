# Portable player damage components

This update provides the calculation and defense components needed for Jungle Dawn's spell32. It also retains verified melee calculations. It does not implement Dawn's cast selection, projectile movement, visuals or player health writes.

`hive_damage_preparation.gd` applies the original unsigned heading window, guard and difficulty-mode adjustments. `hive_damage_calculation.gd` scales the spell by Dawn's factor10 and the supplied positive player magic level, then applies mitigation. `player_mitigation.gd` constructs the ordered equipment/form defense list and handles separate scalar/list bypass flags. Callers still supply actual equipment descriptors, stat parts, form/UI transition mode and effect flags.

Run without original-game assets:

```sh
godot --headless --path . --script res://tests/dawn_damage_portable_test.gd
godot --headless --path . --script res://tests/player_mitigation_test.gd
```

The tests compare 2,048 melee calculations, 5,760 spell calculations, 4,096 melee preparations, 294 spell preparations and 2,048 defense-list/spell compositions against numeric fixtures recovered through local native replay. The accompanying evidence manifest pins the executable used for that replay and the published files. Executable bytes and original media are excluded.

Spell inputs are deliberately validated within the verified domain: the six amount/signature pairs produced from the source request, scalar0..128 and magic levels1..30. Controller defense parts currently require nonnegative values. Stable and transitional UI modes must remain distinct; mapping a saved player form directly to a stable mode during a transition is not verified.

These checks establish component behavior, not complete combat fidelity, a rebuilt demo, full Act1 acceptance or Bob's playtest acceptance.
