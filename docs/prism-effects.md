# Prism effects: on-hit blind and alcove panorama

The Museum Prism (`museum:prop280:Prism`, GLOBAL definition 7 "8-Prism") was a plain shared melee weapon. This
adds its two source effects through modern adapters: a chance to blind a creature it hits, and the clearing of
the alcove's painted panorama when it is taken. Source evidence: `tools/verify_prism_effect_sources.py` writes
[prism-effect-checks.json](prism-effect-checks.json) and `scripts/lol2/prism_blind_regions.json`.

## Source (LOLG.DAT, bounded read)

- **Handler.** Definition 7 uses item handler 7. Table slot 7 resolves to `0x965DC`.
- **Trigger.** The handler acts only on event 5. That event is used only by the special melee weapons (Prism,
  Firestorm, Axe of the Traitor, Drac dagger, Blizzard, Darkstorm), and Darkstorm/Drac test the target class. So
  event 5 is read as the melee on-hit event. *Inference.*
- **Roll.** The handler draws `12415C(221D8, 1, 1000)`. The threshold depends on bit `0x200` of word `+0x1C` (on-disk
  word 14) of the **player's current region**:
  - bit set: success when the draw is above 749 (about 25%);
  - bit clear: success when the draw is above 249 (about 75%).
- **Where the bit is set.**

  | Area | Regions with the bit |
  | --- | --- |
  | Museum | 1499 / 1499 |
  | Hive | 1289 / 1292 |
  | Cave | 1900 / 1954 |
  | Jungle | 442 / 4787 (huts and interiors, e.g. region 3501) |

  The port calls set regions *enclosed* and clear regions *open*. Whether the bit actually means light is not
  claimed.
- **Success.** The handler allocates pool object `0x5E` and calls `107498(obj, attacker, target region, target
  position, 3)`.
  - The effect object uses vtable `0x7278`. Its tick (`0x107A84`) shows message slot `0x134` on frame 1.
  - If the target has `+0x14` bit `0x4000`, it then sends the target's `vt+0x80` a status packet: `{0x1040, 1,
    2/0xF, duration 0xA}`. Modes 1 and 2 of the same effect come from other callers and use duration `0x10`.
- **Failure.** The handler shows the item's own message (definition word `+0x37`).
- **Damage.** Both paths return 0, so the ordinary weapon hit is unchanged.
- **Not traced:**
  - how creatures actually handle packet `0x1040`;
  - the unit of `0xA` (read as 10 seconds);
  - the message texts;
  - the `0x5E` visual;
  - the distribution of `12415C` (assumed uniform).
- **Panorama commands.** The pickup group 6590 also runs seven `op204` commands. Decoder `0x64770` treats a
  `word+4` other than -1/-2 as an index into the wall-record table `[22D08]`: it sets word 0 to `word+6` and ORs
  `0x40` into byte 5.

  | Record | Region | Descriptor before → after |
  | --- | --- | --- |
  | 1743 | 481 | 430 → 871 |
  | 1744 | 482 | 429 → 871 |
  | 1771 | 483 | 428 → 871 |
  | 1745 | 447 | 427 → 871 |
  | 1772 | 484 | 426 → 871 |
  | 1746 | 485 | 425 → 871 |
  | 1747 | 486 | 424 → 871 |

  - The regions form the thin ring around the display region 454.
  - Descriptors 424..430 are 128×80 type-0x8F column textures that together paint a panorama of the gallery.
  - Descriptor 871 is 32×32 and entirely index 0, i.e. transparent.
  - These edges have neighbours, so the review geometry (no-neighbour walls only) never built the panels.

## Port

- **Blind:** `scripts/lol2/prism_blind.gd`.
  - After a **landed** melee hit with the Prism equipped on a living creature, the population draws 1..1000 from
    its own RNG (seeded once per session).
  - The draw is compared with the source threshold for the player's region (`prism_blind_regions.json`: area
    default plus the listed minority regions; polygon and height test).
  - Success blinds the creature for 10 s: it does not move or attack, and any started attack is cancelled. The
    HUD shows "The Prism's light blinds the …", and the target label gains "· blinded".
  - Failure adds nothing to the ordinary hit.
  - A repeat success refreshes the blind to 10 s, with no stacking. A failed repeat leaves the remaining time
    unchanged.
  - Blinds age only while `world_active` is open. Death ends a blind, and a killing hit blinds nothing.
- **Hosts:** the same as the Net of Exile.

  | Host | Hook |
  | --- | --- |
  | `scripted_creature_population.gd` (Museum skeletons, Jungle villagers/Bacatta/Kelsrick/exit encounters, Cave) | `strike()` → `prism_hit()` |
  | `jungle_dino_population.gd` | `strike()` → `prism_hit()` |
  | `hive_return_population.gd` (with ambush and rune populations) | `hive_warriors.strike()` → `prism_hit()` |

  Dawn bodies opt out, because her source script drives her.
- **Saves:** blinds are transient combat state (`prism_blinds` on each population), like the Net holds.
  - Save/load, `restore` and an area change release them.
  - No save field is added.
- **Panorama:** `museum_prism.gd` builds the seven panels from `scripts/lol2/museum_prism_panorama.json`.
  - That JSON holds numbers only: quads, UVs, source pins.
  - The panels are single-sided, facing the alcove, unshaded, with alpha-scissor on index 0.
  - They are shown while the Prism is on display and hidden by the pickup and by a taken `museum_prism` receipt.
  - An untaken save brings them back. No new save field is added.
- **Panorama media:** `tools/prepare_museum_prism_panorama.py` decodes the panel textures from the user's game
  files into `assets/lol2/generated/museum_prism/panorama_<descriptor>.png`.
  - These are original media and are never published.
  - If they are missing, the Museum still runs without the panels and logs a warning.

## Adapter choices (not native parity)

- **Blind behaviour.** "Blinded" means a 10-second stand-still with no attacks. The native creature response to
  packet `0x1040` is not traced.
- **Messages.** The success line is modern text. A failed roll is silent, whereas the native game shows the
  item's message.
- **Region test.** The current region is resolved with the source polygons and the player's foot height. A host
  without a table (e.g. the darker Jungle, L8_SJ) counts as enclosed (25%).
- **Panorama addressing.** The panels use stretch addressing (mode 0, addressing 0) as in the review builder,
  show static mip 0, and treat index 0 as transparent. Flag `0x40` and the native wall pipeline are not
  replicated.
- **Not hosted:** the `0x5E` effect visual, its sound and the native message texts.
- **Not covered:** the Executioner and the two Hive guardians, as for the Net.

## Tests

| Test | Covers |
| --- | --- |
| `tests/prism_blind_rules_test.gd` (headless) | Thresholds, gate, refresh, expiry, region table, panorama JSON |
| `tests/prism_effects_museum_test.gd` | Actual Museum: panorama before/after screenshots, real E pickup, receipt reloads, real inventory equip, woken skeleton fail/success/refresh/pause/expiry/save/kill |
| `tests/prism_blind_jungle_test.gd` | Museum→Jungle transport; open-region draw 250..749 blinds a biting DINO and a provoked villager; region 3501 enclosed; save/load release; Jungle→Hive carries no blinds |
| `tests/prism_blind_hive_test.gd` | Actual Hive warrior via `hive_warriors.strike()`; Net hold stays separate |

Draws are deterministic: each test advances the population's own RNG until the next draw has the outcome it
needs.

Independent lead review (2026-10-10): source evidence, region data, panorama geometry and all7 textures regenerate byte-identically. Two live negative tests reproduced misleading success feedback on a failed repeat roll and an existing blind surviving target death. All three controllers now gate success feedback on the current draw and clear both Net and Prism effects on lethal damage. Hive/Museum pre-existing-blind death and Jungle lethal-spell cleanup of both simultaneous effects pass. Combined12/12 checks passed with unchanged source, including chamber/lift/Fire/Net interactions and rune population. Before/after panorama captures were inspected. This reviewed source is integrated after R12; it is not part of the R12 binary.
