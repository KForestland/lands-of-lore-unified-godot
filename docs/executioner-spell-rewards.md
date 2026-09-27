# Executioner spell rewards

This detached planner models the original damage-feedback reward branch. Fighting modes1/5 award fighting experience. Spell mode2 awards magic experience from the effect entry, tripled for signed damage greater than1, scaled by actor scale minus magic level. Spell kills do not receive the melee tenfold multiplier. Zero damage and other modes award nothing.

Local source checks bind actor36 to scale8 and lowest-charge Spark to type4, effect20, mode2 and base12. At magic level1 it awards30 for damage1 or90 for damage above1. The separate cast-time award atD1114 belongs to Explosion effect10, not Spark.

The local native replay covers25,792 cases. This publication includes only actor-scale8 numeric fixtures, with spell cases restricted to effect20, and the semantic Spark base12. It excludes the raw effect-table window, executable bytes, media and personal saves. Run the fixture/boundary test with:

```sh
flatpak run org.godotengine.Godot --headless --path . --script res://tests/executioner_spell_reward_test.gd
```

The live research checkout also integrates aimed Spark hits, magic level growth, mana debit/cooldown retention, miss/corpse rejection and disk rollback; four focused checks pass. Live integration and its original-asset dependencies are not included in this focused PR. Instant hit/damage, RNG and charge1 as the basic cast are modern adapters; higher-charge projectiles, other enemies and native health ownership remain open. The constructor mode/effect and reward branch were checked independently; end-to-end native projectile dispatch was not replayed.
