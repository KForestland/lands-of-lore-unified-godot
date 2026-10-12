# Saved Dawn projectiles

`dawn_projectile_store.gd` owns persistent spell32 contact state and mode1 explosion first-pass markers. Both local Dawn hosts checkpoint/restore the store in an optional `projectiles` packet field. Legacy packets initialize an empty store; untouched encounters keep their existing packet shape. Rejected restores leave the live encounter unchanged, including foreign-caster records.

The store assigns monotonic effect IDs, initializes the verified fireball contact fields, commits contact state before returning direct-damage requests, creates the explosion before retiring an exhausted parent, and commits explosion consumption before returning area-damage requests. The child’s saved direct target comes from the parent’s last contact; caller neighbor hints cannot replace it. A modern256-effect allocation limit can return allocation failure; callers must still apply the original cast-completion tail.

Validation covers JSON round trips, ignored caster contact, repeated direct/explosion suppression, child-before-retire ordering, invalid/duplicate state rejection, and ID retention after retirement. Rendered tests exercise both actual host disk save/load paths with supplied allocations, clear the in-memory store before reload, reject foreign-caster state atomically, and restore legacy packets. Existing Jungle/Hive Dawn encounters pass. [Evidence](dawn-projectile-save-checks.json).

This is effect ownership and save integration, not completed combat. AI-driven creation, movement, live health dispatch, explosion presentation/retirement and original launch getter binding still need integration. The store does not introduce a per-actor clock; movement must consume the shared world clock. Native constructor placement and presentation are not replaced by this store.

Run `godot --headless --path . --script res://tests/dawn_projectile_store_test.gd`. The [host save patch](../patches/dawn-projectile-save-binding.patch) targets the current full local host; the complete host dependency tree and original media remain outside this component PR.
