# Museum skeleton population — source leads (2026-10-03, not implemented)

Static decode of L3_DH (`tools/audit_game_actor_scripts.py` groups/events, predicate table). Leads only; no live behavior added.

- Twelve `skel` placements: actors 20, 21 (definitions 2/0) and 23–32. Placement health bytes: 150 for 20, 21, 29, 30, 32; 100 for 23, 24 (others to confirm). Native attack base from `global\ai\skel\stat.csv`: total81=30, minimum82=3, fresh base15 (same loader replay as the Roach/DINO tools).
- Actor event records are kind6 carrying an actor event byte. Event11 is the documented post-death event.
- Each of actors 23–32 (exactly ten) has two event11 handlers: an unconditioned group running `op207 cf00 0000 1701` (candidate: local23 += 1) and a predicate58 group running `op210 d200 0000 0800` then `op14` prop93 → state3. Predicate58 = `local23 == 10` (predicate table, local variable23).
- Prop93 (kind3 target; object107 uses kind3 in group1886) is at source (-3717, 603); stream group1696 also sets it to state4. Its identity/template and whether it gates the onward Museum route are unresolved.
- Actor20 event9 handler: `op13` on itself then two `op3` grants of identity 0x7c5eb1bf (item drop lead). Actor21 has op2 global writes. Actor29 has extra handlers (event20, predicate206, op8/op13).

Next: confirm op207/op210 semantics against the native command dispatcher, identify prop93 and its state3 effect, locate skeleton regions relative to the earned Museum route, then implement with the shared creature live rules if it is required content.
