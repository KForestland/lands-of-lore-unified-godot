# Huline weapon shop

The original four WPNEXT entry regions now open the exterior in normal Jungle
play. Enter opens WPN, plays Kityara's original introduction and applies its
ordered flags and Daniel-knowledge write. The Firestorm interaction produces
Power Orb knowledge after line527, then plays528–534. Julian reads the resulting
shared global. No global is supplied just for reaching his office.

Talk, Long Arm and Bracers reproduce the normal living-NPC Short Sword, Long Arm
and Gargoyle Bracers grants, respectively. Grants occur at their original movie
boundaries and are retained by inventory, Jungle/Hive/darker-jungle saves and
rollback. The two weapons can be selected; they currently use the existing
provisional armed-melee adapter. Bracers have original art and inventory identity,
but accessory equipping and original item-specific combat stats remain open.

`tools/audit_weapon_shop.py` runs original room callback instructions with explicit
host boundaries. Eight selected WPN interactions match in both loose and archived
scripts; this does not settle general file precedence. `prepare_weapon_shop.py`
stages40 original speech clips, the two animated backgrounds and Kityara idle.
The Luther306 line is an original named AUD, not a missing VQA. WPNEXT uses VPTR
vectors and is decoded by the existing verified room-vector decoder before OGV
conversion. Each speech clip checks source frame and PCM counts. Original media
stay local and are not for publication.

`verify_weapon_shop_admission.py` checks128 original exterior door combinations;
Godot admission matches the fixture. Kityara’s outdoor meeting/knife, death and
orb-offer producers are now integrated; see [jungle-kityara.md](jungle-kityara.md).
The Firestorm exchange is covered by the later offer extension below. Remaining
later-visit absence stories, in-shop hostile interactions, native ambient cadence
and original hotspot/item presentation remain open. The current action buttons
are a modern functional interface.

The room test supplies only the initial nearby position. It verifies detector
entry, original media, dialogue effects, a partial disk-save rollback across the
orb write, all three grants, duplicate rejection, weapon selection, exterior
return and Julian's offer-plan admission. Report:
`tmp/regressions/weapon_shop_20260927/report.json` (first two checks), followed by
`tmp/regressions/shops_integration_20260927/report.json` (seven of eight passed).
The latter found a legacy-default-state regression; adding weapon-shop state to
`Quests.initial()` fixes it, verified by
`tmp/regressions/weapon_legacy_fix_20260927/report.json`. These are focused checks,
not a full suite or Act One completion claim. The continuous cave-derived monastery→shop→garden/cellar→Julian visit passes80.78s; subsequent translation12.29s and departure37.79s pass.
`docs/weapon-shop-earned-chain-checks.json` verifies all ten actual saved-game
links, retaining earned knowledge and both side-room visits at the darker-jungle
arrival. The first seven legs are prior checked runs, not new full-route replays.

2026-09-28 offer extension: twelve archived/loose callback pairs and42 dialogue clips now include preknown orb knowledge, Power Orb consumption followed by Firestorm grant, and held-dagger refusal. Rendered offer tests verify partial disk rollback and Firestorm equipment/travel. Orb inventory is supplied in this focused test; Julian’s earned delayed-orb producer is now checked by `broken_repair_earned_walk_test`. Initial test teardown leaked two textures; waiting for rendered cleanup passes without changing game logic. Detached state core is published in GitHub PR6; live room integration remains local.
