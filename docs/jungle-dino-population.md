# Huline Jungle DINO herds — live encounter slice (2026-10-03)

All 15 source L4_HJ definition4 `DINO` placements (actors 21–35, four herds of 3/5/2/5) are now live in the Jungle scene (`jungle_dino_population.gd`), with saved state in `quests.jungle_dino_population` (`jungle_dino_population_state.gd`). Because the packet lives in quests it is validated by `act_one_quest_state.gd`, saved with every Jungle/Hive save and carried through both area handoffs.

## Source-bound

- Identities, positions, headings, 150HP and reward scale4 from the pinned `jungle-dino-bindings.json`.
- Original indexed frames through the existing `jungle_dino_sprite.gd` presenter: idle selector0, walk selector1 (eight views, source mirror flags), bite selector4, death selector8, corpse selector9.
- Bite: selector4/resource952 kind1 event at frame9, byte100%. `tools/prepare_jungle_dino_population.py` executes native A1D28/A1F2C/A22FB on the original `global\ai\DINO\stat.csv` (total81=30, minimum82=3, bank bytes3/2 = 206/50) giving fresh base24, so each bite requests **24** before mitigation (`jungle-dino-attack.json`).
- Melee XP uses the shared source progression rule at scale4; Spark/aura XP uses the shared spell reward path at scale4. Overkill rewards only the remaining health; defeated actors cannot be rewarded twice.

## Modern adapters (explicit)

Perception range240/height96 with a clear world ray, reach60, speed55, 8fps clip clocks (impact1.125s, clip1.75s, death1.5s), 14×40 capsule, creature pixel scale shared with the cave Roach, ledge guard, no creature–creature collision, fresh constructor A3=0. Native goal/action scheduling, the region955 actor21 selector request and prop195 consumers are not used for admission.

## Playability note for Bob's playtest

Native bite request24 is applied to the provisional30-point playable health pool, so two bites from one DINO are lethal. The native player-health scale and armour mitigation are still unresolved project-wide; this may make the herds much harder than the original. Please report how it feels; scaling will not be invented without evidence.

Player death in the Jungle: creatures stop, saving is refused (existing 1–30 health rule), `R` recovers at the current position with health30 (as in the Hive), `F9` loads.

## Checks

- `jungle_dino_population_state_test` (headless): source binding, single bite24 at frame9, cap, defeat/corpse clock, JSON, quest validation and malformed rejection.
- `jungle_dino_live_test` (headless Jungle scene, only the mouse-capture world gate replaced): actor24 perceives, pursues on real floor, bites for24, mid-bite disk save/rollback, production melee strike with XP and cooldown, Spark collider hit, defeat clip/corpse, JSON area handoff and retry.

Open: rendered visual review (scale/anchor are adapters), DINO sounds (kind2 events), native perception/cadence, mitigation, earned Jungle routes now meeting herds (see regression report), and Bob's playtest.

Publication note: this branch carries the portable state modules, source JSON, verifiers and checks. Scene integration (`jungle_dino_population.gd`, `cave_roach_population.gd` and walkthrough wiring) and original media remain local, as with earlier publications.
