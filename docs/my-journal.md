# My Journal (2026-10-29)

Owner rule 2026-10-27: Classic keeps native stuck points and gives a vague My Journal note; Enhanced adds guards.
LoL2 has no journal of its own (no "journal" text in the original files), so this is a presentation adapter on the
shared interface sheet (the Atlas/Character sheet), opened by the player with **J** (or closed with J/Escape).

- Notes: the `JOURNAL_HINTS` rows beside the planners' flags (`scripts/lol2/my_journal.gd` SOURCES, 18 notes; id =
  the row's `when`). The `enhanced_guard` text is developer data and never shown.
- Discovery: `MyJournal.discover(host, id)` at the moment in play; shown in discovery order; one notice
  "A new note in My Journal (J)." Reading changes nothing.
- Saved: `item_effects.journal` (array of ids) in the carried packet, so it travels with every save and area handoff;
  older saves have none; `player_item_state.validate` rejects unknown/duplicate/non-text ids; continuity snapshots carry
  `journal[id]`.
- Wired moments (16 of 18):
  - `pilot_spark_before_plate`: an admitted Spark/fire hit on the Museum pilot flame (prop61) before the niche plate.
  - `long_arm_before_passage`: first reaching the Long arm walkway while passage78 is still shut (before the pickup).
  - `tavern_after_farewell`: while Bacatta's farewell (CAN_EXIT, flag34) plays.
  - `stones`: while Anyar's death (CHUT_KILL, flag150) plays.
  - `kelsrick_attacked_then_hut`: while branch A (CHUT_ATTACK: the hut entered after striking Kelsrick, line 365) plays.
  - `gate_closed_before_shalla`: the village gate region2443 entered and refused before Shalla's rescue (shared38 clear,
    no alarm, never admitted); `jungle_village_gate.on_entered()`.
  - `no_confidante_yet`: Confidante region3408 entered where the first meeting would start (p198: local20==0, hut not
    smoked) but neither GV_LUTHER_KNOWS_ABOUT_DANIEL nor GV_KITYARA_DEAD is set; `jungle_confidante._journal_region()`.
  - `password_known_den_unfound`: Met_Confidant (local27) written while the den door was never opened (den flag 271).
  - `kelsrick_must_die_quietly`: Mauri's first meeting sets den flag 28; `village_hostile_gate_shut`: his tunnel offer
    with the village roused sets den flag 18 (both now forwarded as host effects to `thieves_den_rooms._apply`).
  - `thohan_sword_broken`: the Museum control181 grant of the broken Thohan while GV_KNOWLEDGE_OF_POWER_ORB is clear.
  - `larkhon_must_sleep` / `larkhon_ask_shaman` / `larkhon_serum_needs_leaf` / `larkhon_vapors_unactivated`: near the L8
    Larkhon (600 units) or at its L8->L12 refusal, the one matching earned state (`l8_larkhon.gd guidance_for`).
  - `tree_torches_unlit`: near the L8 tree platform with fewer than five torches lit (`l8_tree.gd`).
- Not wired (no planner state represents the moment):
  - `hut_smoked_before_password`: the chief's-hut smoke-out (Kelsrick local6 `Has_Luther_smoked_the_Cheifs_hut`) is not
    hosted; no port code writes local6 (docs/jungle-inner-gate.md). The contract also asks for a before-the-fire text.
  - `firestorm_wanted`: no state records Luther learning of either Firestorm offer (Mauri's or Kit'yara's); the
    lines that carry them are not transcribed, and flag 63 only records owning Firestorm.
- Tests: `tests/my_journal_test.gd`, `tests/my_journal_triggers_test.gd` (gate, Confidante x2, broken Thohan), and the
  real-host assertions in `thieves_den_room_test` (28/18) and `chut_branches_test` (CHUT_ATTACK).
- Hive: J is blocked during conversations, like Tab/I/M. Test: `tests/my_journal_test.gd` (headless).
