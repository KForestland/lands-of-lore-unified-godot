# Net of Exile on-hit (modern adapter)

`tools/verify_net_exile_onhit_sources.py` pins the source evidence and writes `docs/net-exile-onhit-checks.json`.

## Source (bounded read)

- GLOBAL definition 25 "26-Net of Exile" uses item handler 104 (0x9B718).
- The handler acts only on event 17 (a landed hit), and only when the target's class is 2 (a creature).
  - It allocates pool object 0x7A and runs the family-4 timed-effect constructor 10E2F8, bound to the attacker and the target.
  - It does not change damage, so the hit is an ordinary weapon hit.
- 10E2F8, when bound to a target:
  - requests a sound;
  - sends message 0x1A (value 1) to targets of one class (0x22574);
  - sets the effect lifetime +0x6E to 0xA0000, which is 10.0 in 16.16. Reading this as 10 seconds is an inference.
- With no target bound, it only spawns the visual pool 0x5E.
- No item description text exists; the game gives only the name.

## Port (`scripts/lol2/net_exile_hold.gd`)

- **Hold:** a landed hit with the Net equipped holds a living creature for 10 s.
  - The creature does not move or attack, and an attack it had already started is cancelled.
  - The hit's damage is the normal weapon damage.
- **Repeats:** a repeat hit refreshes the hold to 10 s; holds never stack.
- **Ending:** death ends the hold. The timer ages only while the shared world gate (`world_active`) is open.
- **Feedback:** the line "The Net of Exile entangles the …" and a "· netted" suffix on the target label.
- **Hosts:**

  | Host | Strike path |
  |---|---|
  | `scripted_creature_population.gd` (Jungle villagers, Bacatta encounters, Kelsrick, exit encounter, and Cave/Museum populations, although the Net is not admitted there) | `strike()` → `net_hit()` |
  | `jungle_dino_population.gd` | `strike()` → `net_hit()` |
  | `hive_return_population.gd` (with `hive_ambush` and `hive_rune_population`) | `hive_warriors.strike()` → `net_hit()` |

  Dawn (Jungle and Hive Dawn20) moves by her source script, so her body opts out (`net_hit` returns false).
- **Saves:** holds are transient combat state (`net_holds` on each population), just as checkpoint recovery drops unfinished attacks. Save/load, `restore` and area change release them, and no save field is added.

## Differences / not hosted

- The hold itself is an adapter. The source shows a 10.0 timed effect bound to the creature; what that effect does natively, beyond the message 0x1A to class 0x22574, was not traced.
- Not hosted: the 0x5E net visual, the native sound request, and message 0x1A.
- Not covered: the Hive Executioner and the two Hive guardians (separate strike paths).

## Tests

- `tests/net_exile_onhit_hive_test.gd`
- `tests/net_exile_onhit_jungle_test.gd`

Independent lead review (2026-10-10): the original release retained a hold when an already-netted creature died. A live Hive negative test reproduced `health=0` with a remaining 10-second hold. All three population damage paths now clear the hold on lethal damage, including spell damage; the Hive and Jungle tests cover this case. Combined chamber, lift, Fire crystal, recharge, Net pickup/combat and rune-population checks passed8/8 with unchanged source. Hive feedback and Jungle netted-label screenshots were inspected. This reviewed patch is integrated in source after R12; R12 binaries do not contain it.
