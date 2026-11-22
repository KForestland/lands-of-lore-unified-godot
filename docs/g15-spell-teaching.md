# Spell teaching and legacy saves

`player_spell_teaching.json` is the single teaching table used by legacy loads and F2 starts. Live acquisition remains with its existing owner. The lead authorized chapter backfill on 14 November so replacing contextual stand-ins does not strand an existing player.

| Lesson | Existing teaching evidence/opportunity | Already-past chapters |
| --- | --- | --- |
| Dampen, Curse 1 | Monastery rune translation / charm | All Act 2/3 |
| Control, Curse 2/3/5 | Dawn Control Token exchange receipt or token | Claw, Citadel, Temple and all Act 3 |
| Mists 1/3 | Temple/City Mists scroll | City and later |
| Prism 5 | Dark Halls/Ruins Prism scroll | All Act 2/3 |
| Summon 3 | Museum secret scroll receipt or scroll | Jungle/Hive/Dark Halls and all Act 2/3 |

The JSON lists exact receipt paths and item IDs. Chapter backfill is an authorized modern compatibility adapter, not evidence that an old player consumed a scroll. On the first live frame after normal load, only a magic packet lacking `spellbook` is migrated. An explicit modern book, including an empty one, is authoritative. Fresh fallback magic contains an empty book so new component maps do not infer chapter lessons. Mana, cooldown, selection, health, story, inventory and pose are unchanged.

F2 deliberately merges those same chapter lessons into a detached checkpoint copy, including a future pin with a partial modern book. It also retains the established full-health adapter. Source pins are never rewritten. Normal slot loads do not receive the F2 override.

`g15_spell_teaching_test` checks table contracts, modern/fresh boundaries, idempotence and detached F2 merging. `g15_legacy_teaching_input_test` opens seven actual F2 starts and loads an untouched game-written r19i Claw slot (SHA256 `b3fe96a441904a72620ecd11f02f12654f777ddaded429f58bd3eca4a5738f6c`, 430863 bytes). Both Claw cases change form with real Ctrl+Q and survive F5/F9. F2 Claw first walks off its sloped arrival surface onto the nearby flat tread: existing body clearance refuses a lizard on the slope. This is a load/input component proof with private session resets and held clocks disclosed in the registry, not a new earned walk. The original save has the actual committed Dawn exchange receipt.
