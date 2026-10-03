# Huline villagers — Jungle population (2026-10-03)

The eighteen present L4_HJ placements 39–56 (TIG_CUB 39–45, TIG_FEM 46–50, TIG_MAL 51–56) now appear in the Jungle on the generic scripted creature owner, in quests as `jungle_villagers` (validated by `act_one_quest_state.gd`, carried with Jungle/Hive saves).

Source-bound: positions, headings, health (130/150/160), definition reward scales (cub 2, adults 4), present flag (0x1000 clear), behaviour 6, no event groups or literal commands, 761 original indexed frames (`tools/prepare_jungle_villager_sprites.py`), attack clips (two 50 % hits at frames 8/11 or one 60 % hit at frame 11; native base 15).

Adapters: as friendly village population they idle in their original idle pose and do not perceive the player; a hit provokes that villager, which then fights with the shared creature rules (playable damage ×0.4, 0.8 s recovery). Native wander (goal 6) movement is not implemented — Grok's DINO admission lane covers the shared goal-6 path. The packet is written into quests only once something changes, so untouched saves stay identical. Scale ≈0.47 u/px (adult opaque height ≈ human), cubs 0.33.

Not live: absent rogues 36–38 (only property writes, no spawn in these streams), the exit-area guard/Bacatta story sequence (props 552/554/4398, actors 58–61, 0/66), Kelsrick 64 and Dawn 63 actors (existing dialogue systems own those roles).

Check: `jungle_villager_live_test` (idle harmlessness with quests untouched, provocation via production strike, fight-back, disk rollback, quest transport).
