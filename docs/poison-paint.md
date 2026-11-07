# Poison Paint and the silent Kelsrick kill (chunk 7, fix V4)

Decoded and built by fable on 2026-10-27 (AI_COMMS `POISON_SILENT_KILL_20261027.md`, PROVEN from LOLG.DAT, L4_HJ.MIX
and the GLOBAL.MIX definitions; longplay 62:56–63:18). Builds on the Thieves' Den chain (`thieves-den.md`), which
grants the paint.

## Source

- **Poison Paint** (definition 125 "123-Pois paint", handler 10 at 0x96880). Mode 0x0C (the paint dropped on the
  weapon circle): if the two coat counters sum to less than 9, the paint leaves the hand and is freed, counter
  0x23C43 (interface object 0x23819 + 0x42A) gains one coat through 0x82DCC, and the weapon ring is redrawn
  (0x7F69C; the longplay shows it green). At 9 the use is refused and the paint kept. Mode 1 (used on Luther) poisons
  Luther instead (a self-hit record with flag 0x20). Death sac (handler 11) feeds the second counter 0x23C44
  (0x82E10); the Light crossbow spends a coat per bolt.
- **The armed melee strike** (0x88E80–0x891AF). With the equipped weapon's definition, the hit context takes the
  definition words +0x3B (mask) and +0x3D (flags: 5-Short swd 2/4, 9-Firestorm 0x112/5, 30-Empty hand 0xA/0xC). If
  counter 0x23C44 > 0: flags |= 0x40 and the counter drops by one; else if 0x23C43 > 0: flags |= 0x20 and it drops by
  one (0x88FD0–0x89113). Then `target->vtable[0x80](ctx)`.
- **The script scanner** (0xAE2C8). For kind-9 records in list order: masks (zero = wildcard, else intersection with
  ctx+0 / ctx+2), mode-1 threshold against the final damage (ctx+0x1E), the following kind-0x13 predicate; the first
  record that passes runs its group, one-shot records are cleared, and the scan stops (`[esp+4] != 0` exits the loop).
- **Kelsrick** (L4_HJ actor 64, list at archive offset 12770022): 30402 (masks 0/0x60, one-shot, no predicate) comes
  before 30456 (0/0x1F, predicate 31) and 30544 (0/0x1F, predicate 132). 30402: GV_KELSRICK_DEAD = 1, player property
  0x27, local52 = 1, local8 = 200, op8, op13 sub7, op13 sub17 (death; event 11 → 31122 then sets local8 = 30 and
  soul −1). Nothing in that path writes shared29 (GV_HULINE_ALERT), and local52 = 1 blocks the two alert records for
  good. The village alarm (g27172) needs the alert, so the gate timer stays inert: no bells, no archers, gates open,
  and TINT plays its quiet Firestorm scene.
- **Other targets.** The player's take-hit (0xD03B8) sets status +0x1B5 (0x20 / 0x40) with a dose timer; creatures
  (0xA6B95) test resistance (0xA73F8) and set +0xB6 bits 0x30 / 0x10; the round-robin slow update (0xAB50F) then takes
  1 (paint) or 2 (death sac) hit points per tick. **The tick cadence is not traced** (0xB30AC's call rate), so this
  damage over time is not hosted.

## Port

- `scripts/lol2/weapon_poison.gd`: the two counters as `quest_state.weapon_poison` ({version, paint, sac}; 0..9,
  sum ≤ 9; older saves load it empty), `apply_paint`, `strike_flag` (sac 0x40 first, then paint 0x20), the host
  helpers `use` (the inventory's Use on Poison Paint) and `spend` (an armed landed strike), and the ring tint.
- `item_catalog.gd`: "123-Pois paint" has use kind `poison_paint`; `museum_inventory.gd` shows "Apply to weapon";
  `player_item_controller.use` applies it (health > 0, human form, as the other uses).
- `scripted_creature_population.strike`: after a landed armed strike, `last_poison` = the spent coat's flag.
- `jungle_kelsrick.gd` `_mirror_damage`: mask2 = 4 | `last_poison` for melee (Spark stays 1/1).
- `jungle_kelsrick_state.hit`: the scanner rule — the first passing record runs, then the scan stops.
- `museum_interface.gd`: the Attack ring (hand and weapon icons) tinted `weapon_poison.RING_TINT` while coats remain;
  the hover highlight returns to that tint.

## Adapters (docs/DEVIATIONS.md, 2026-10-27)

Use button instead of the weapon-circle drop; the coat is spent on landed strikes only (no miss model); the ring tint
replaces the original redraw's art; the creature poison tick, Luther's self-poisoning, Death sac and crossbow coats
are not hosted; the scanner stop-after-first rule.

## Tests

- `weapon_poison_state_test` (headless): coats (apply, the cap, sac-then-paint, flags, validation, legacy) and the
  Kelsrick scanner through `jungle_kelsrick_state.hit`: a sword strike fires 30456 and writes shared29; a coated
  strike fires 30402 alone (GV_KELSRICK_DEAD, local52, death, no shared29).
- `kelsrick_silent_kill_test` (headless, actual Jungle host): the den gives the paint; Apply to weapon (one coat,
  paint consumed, ring tinted); one generic strike kills Kelsrick with GV_KELSRICK_DEAD = 1 and shared29 = 0; the gate
  passage arms the alarm timer, which stays inert (gates open, no arrows, soul unchanged); Mauri's quiet Firestorm
  scene grants Firestorm; disk save/load keeps it all and rejects ten coats; a fresh host without paint: the same
  strike raises the alert.
