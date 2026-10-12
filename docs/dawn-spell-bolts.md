# Dawn Chain bolt (spell 7) and Plasma bolt (spell 58) — Classic Edition, modern

`scripts/lol2/dawn_spell_bolts.gd` is one reusable Node3D that runs both bolts in a real Godot world. The host connects
three things:
- `targets` — a callable returning `key -> {body, point, type, valid}`; type 2 = creature or actor;
- `deliver` — a callable that receives each hit request;
- `exclude` — the caster's body RIDs.

Calls: `cast_chain(caster, origin, first_target, hop_draw)`, `cast_plasma(caster, origin, target)` and `advance(delta)`
from the encounter's world update. `checkpoint()`/`restore()` handle saved state; restore validates and is atomic.

## Kept from the original (evidence: opus/spell7_58/AUDIT.md)
- **Chain bolt:**
  - 3–5 hops from the shared RNG draw (0..95);
  - candidates within 1280 units of the first target, in the verified nearest-first order (`dawn_spell7_chain.targets`,
    equal to the original routine on 600 executed cases);
  - a hop happens within 30 units;
  - each hop sends `{kind: chain_hop, mask 0x11, subtype 0x54, amount 10}`.
- **Plasma bolt** (Dawn's variant): one hit `{kind: plasma, mask 0x11, subtype 0x3A, amount 10}`. A bystander in the way
  takes the hit only if its type is creature-like (1/2/3/0x10).
- The caster never hits itself. Hit requests go to the health owner; this module never changes health.

## Deliberate modern changes (tune in playtest; all constants at the top of the script)
| Area | Original | Modern |
| --- | --- | --- |
| Motion | fixed-point motion clock, per-tick speeds 150 and 200 | homing at 420 (chain) and 300 (Plasma) units/s, swept-ray collision |
| Hop order | builder list indexed from slot 1; may strike the same creature twice in a row | first target, then distinct creatures nearest-first; cycles without immediate repeats |
| Walls | collision re-targets / skips sharp turns | a wall ends a chain bolt (impact flash); a Plasma bolt bursts harmlessly |
| Creature in the way | chain spends hops on sharp turns | a chain takes a hop on that creature (hit request) and continues |
| Lifetime | none observed | 6 s cap on stray bolts |
| Presentation | original Spark/Plasma effect sprites (palette/tint unresolved) | emissive orb, additive halo, light, hop arc, impact flash |

Health, defence, mask/subtype damage splitting (native 62922..62ABE), death and automatic Dawn cadence stay with the
lead's combat and health owners.

## Tests (stage project, headless)
- `dawn_spell_bolts_test`, in a real physics world:
  - chain hits a→b→c at 10 each and retires;
  - cycle fill a, b, a;
  - a wall ends the chain;
  - Plasma lands a single hit;
  - a prop bystander absorbs the bolt; a creature bystander takes the hit;
  - caster pass-through;
  - save/load mid-flight; malformed state rejected.
- `dawn_spell7_chain_test`: 600 executed ordering cases.
- `dawn_spell58_plasma_test`: 40 executed hit-table cases.

Render check: `tests/dawn_spell_bolts_capture.gd` produces `bolts_capture.png` (local review image).

## In Dawn's modern combat (dawn_modern_combat.gd)
- **Rotation:** Dawn rotates orange bolt → Chain bolt → Plasma bolt on the existing cooldown and wind-up telegraph. The
  first shot is still the orange bolt. The charge orb is coloured by the coming spell: orange, blue-white or violet.
- **Gates:** casting uses the same line-of-sight lane, wall, talk/hold, world-active, pause and hostility rules as before.
  Losing hostility clears all bolts.
- **Damage**, applied through the existing path `Defense.incoming(host, raw, 4)` and blocked by the lightning aura:
  | Spell | Raw | Observed loss on the 30-health baseline | Why |
  | --- | --- | --- | --- |
  | orange bolt | 15 | 6 | |
  | Chain | 12 | 5 | fast, harder to dodge |
  | Plasma | 20 | higher | slow, dodgeable |
- **Targets:** only the player is a target in the encounters. Chain hops therefore land once on the player; it would hop
  to other creatures only if a host lists them.
- **Saved state:** `packet.combat` now has 7 keys (adds `rotation` and `spells`). Legacy 5-key packets still validate and
  load with rotation 0. The disk round trip is exact.

## J review fixes (lead 07:26)
- Hit requests are delivered only after the bolt's hop/impact/target are committed, so a save taken in the health
  callback cannot replay a hit.
- Proximity arrival requires a clear remaining path; something in between is touched instead.
- The struck creature is excluded from the sweep itself, so a wall behind it is still found. A bystander creature
  becomes "last struck" and is not re-contacted.
- Validation requires exact integers for identities, limits and hops, with chain/Plasma progress consistency.

## Tests
- Real hosts: `dawn_modern_spells_test` (rotation, telegraph colours, Chain damage via Defense, in-flight disk reload
  without repeat, gating, aura, legacy packet, hostility clears spells; captures inspected) and the lead's
  `dawn_modern_combat_test` (unchanged, PASS).
