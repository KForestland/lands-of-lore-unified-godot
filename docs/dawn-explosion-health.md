# Dawn explosion health integration

Both local Dawn hosts expose `damage_projectile_explosion(id, player_flags, other_neighbors, source_context)`. It measures planar distance using the actual player position and saved explosion position, supplies the stable source-player identity, and routes the original first-pass request through the shared transactional player health boundary. The saved direct-target override remains owned by the effect store.

Explosion consumption is committed before calling the health setter. Repeated calls and disk reloads cannot repeat damage. A batch containing unsupported damage recipients is rejected without changing health or consuming the pass; it is not silently reduced to player damage. Other world-neighbor enumeration and native player flags remain caller-supplied.

This change also corrects the earlier direct-hit heading binding: original request+8 names the caster, so directional damage uses the caster heading. Both hosts now read their saved live actor heading for direct and explosion damage. The focused test distinguishes caster heading32768 from projectile heading0 and checks the11-point directional result. Original reference: `tools/verify_dawn_spell32_preparation.py`.

Four source-stable final checks pass: transactional direct/explosion health, both actual host health/save paths, and existing Hive/Jungle Dawn encounters. Rendered fixtures provide native stats and projectile allocation, then observe actual player collision, a10-point direct hit plus19-point explosion, and disk reload without repeated health loss. The two original explosion filter/calculation tests also passed in the preceding run; that run’s new test failed to parse until an explicit variable type was supplied. [Evidence](dawn-explosion-health-checks.json).

Difficulty, player heading/guard, defense/mitigation, magic level, entry gates and collision bearing still need production binding. World enumeration beyond the player, automatic casting/scheduling, visuals and full health-scale reconciliation remain open. Modern lethal health0 behavior remains distinct from the unimplemented original lethal continuation.

The [host patch](../patches/dawn-explosion-health-binding.patch) follows the direct-health patch in the full local source. Asset-free check: `godot --headless --path . --script res://tests/dawn_player_damage_test.gd`.
