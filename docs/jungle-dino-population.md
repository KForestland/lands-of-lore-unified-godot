# Huline Jungle DINO herds — live encounter slice (2026-10-03)

All 15 source L4_HJ definition4 `DINO` placements (actors 21–35, four herds of 3/5/2/5) are now live in the Jungle scene (`jungle_dino_population.gd`), with saved state in `quests.jungle_dino_population` (`jungle_dino_population_state.gd`). Because the packet lives in quests it is validated by `act_one_quest_state.gd`, saved with every Jungle/Hive save and carried through both area handoffs.

## Source-bound

- Identities, positions, headings, 150HP and reward scale4 from the pinned `jungle-dino-bindings.json`.
- Original indexed frames through the existing `jungle_dino_sprite.gd` presenter: idle selector0, walk selector1 (eight views, source mirror flags), bite selector4, death selector8, corpse selector9.
- Bite: selector4/resource952 kind1 event at frame9, byte100%. `tools/prepare_jungle_dino_population.py` executes native A1D28/A1F2C/A22FB on the original `global\ai\DINO\stat.csv` (total81=30, minimum82=3, bank bytes3/2 = 206/50) giving fresh base24, so each bite requests **24** before the unresolved native damage calculation (`jungle-dino-attack.json`). Player-facing damage uses the shared playable scale ×0.4 (the Hive warrior base6 adapter) = **10**, followed by the warriors' 0.8 s recovery.
- Melee XP uses the shared source progression rule at scale4; Spark/aura XP uses the shared spell reward path at scale4. Overkill rewards only the remaining health; defeated actors cannot be rewarded twice.

## Modern adapters (explicit)

Perception range240/height96 with a clear world ray, reach60, speed55, 8fps clip clocks (impact1.125s, clip1.75s, death1.5s), 14×40 capsule, creature pixel scale shared with the cave Roach, ledge guard, no creature–creature collision, fresh constructor A3=0. Native goal/action scheduling, the region955 actor21 selector request and prop195 consumers are not used for admission.

## Playability note for Bob's playtest

Earlier today the native request24 was applied directly; that made two bites lethal. It now uses the same playable scale as every other creature (10 per bite, 0.8 s recovery). The native player-health scale and mitigation remain unresolved project-wide; please report how the herds feel.

Player death in the Jungle: creatures stop, saving is refused (existing 1–30 health rule), `R` recovers at the current position with health30 (as in the Hive), `F9` loads.

## Checks

- `jungle_dino_population_state_test` (headless): source binding, single native24 request/playable10 bite at frame9, cap, defeat/corpse clock, JSON, quest validation and malformed rejection.
- `jungle_dino_live_test` (headless Jungle scene, only the mouse-capture world gate replaced): actor24 perceives, pursues on real floor, bites for playable10, mid-bite disk save/rollback, production melee strike with XP and cooldown, Spark collider hit, defeat clip/corpse, JSON area handoff and retry.

Original footsteps, bite and death audio are integrated with pause and saved partial playback; see [audio scope and checks](jungle-dino-audio.md).

Open: rendered visual review (scale/anchor are adapters), native perception/cadence, mitigation, earned Jungle routes now meeting herds (see regression report), and Bob's playtest.

Publication note: this branch carries the portable state modules, source JSON, verifiers and checks. Scene integration (`jungle_dino_population.gd`, `cave_roach_population.gd` and walkthrough wiring) and original media remain local, as with earlier publications.

Melee cooldown persistence: the local controller now stores its remaining 0.45-second strike cooldown in the validated population packet. Legacy saves without that field retain zero cooldown. Saving/loading after a strike restores the remaining lockout instead of keeping a later in-memory value; world pause freezes it. Invalid negative, oversized, nonnumeric and nonfinite cooldowns reject before restore. Live disk rollback, expiration, pause and subsequent Spark/defeat/area handoff pass; see [cooldown checks](jungle-dino-strike-save-checks.json). The first extended fixture needed to re-aim after the normal load camera reset; those failed logs are retained. No native cadence or full campaign acceptance is claimed.

Idle presentation: original selector0 now loops its twelve frames using the existing8fps adapter. The shared per-actor pose cursor preserves idle phase across save restoration. Fresh idle animation alone does not initialize quest progress, and gameplay pause freezes it. Headless idle-loop/texture restoration, audio ownership and full DINO combat tests pass in `tmp/regressions/codex_dino_idle_20261003/report.json`. GPU/native cadence acceptance remains open.
