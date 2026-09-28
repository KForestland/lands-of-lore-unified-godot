# Act One actor coverage audit

Four pre-departure map archives only. Positive implementation bindings are reviewed leads, not completion. Unmatched actors may be alternate states, script placeholders, cinematic actors or playable encounters; source reachability and live implementation classification remain required. L8_SJ acceptance ends at verified arrival/onward walk, not completion of Act Two content.

194 source placements across four archives; 15 explicitly reviewed live encounter bindings. These numbers are not a completion percentage.

| Area | Definition / label | Source actors | Reviewed live actors | Classification pending |
| --- | --- | --- | --- | --- |
| L1_DC | 0 / GGCAPT | 56 | none | 56 |
| L1_DC | 1 / GGUARD | 2, 38, 39, 54 | none | 2, 38, 39, 54 |
| L1_DC | 2 / GGUARD | 1, 52, 53 | none | 1, 52, 53 |
| L1_DC | 3 / Kenneth | none | none | none |
| L1_DC | 4 / Roach | 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51 | none | 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51 |
| L1_DC | 5 / ROACH | 0, 23 | 23 | 0 |
| L1_DC | 6 / WORM | 36, 37 | none | 36, 37 |
| L1_DC | 7 / B_HUMAN | 55 | none | 55 |
| L1_DC | 8 / WORM | 24 | none | 24 |
| L1_DC | 9 / B_HUMAN | 13, 14, 15, 16, 17, 18, 19, 20, 21, 22 | none | 13, 14, 15, 16, 17, 18, 19, 20, 21, 22 |
| L1_DC | 10 / B_HUMAN | 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 | none | 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 |
| L3_DH | 0 / skel | 21, 28, 29, 30, 31, 32 | none | 21, 28, 29, 30, 31, 32 |
| L3_DH | 1 / Rat | 22 | none | 22 |
| L3_DH | 2 / skel | 20, 23, 24, 25, 26, 27 | none | 20, 23, 24, 25, 26, 27 |
| L3_DH | 3 / B_HUMAN | 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 | none | 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 |
| L3_DH | 4 / B_HUMAN | 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 | none | 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 |
| L4_HJ | 0 / TIG_ROG | 36, 37, 38 | none | 36, 37, 38 |
| L4_HJ | 1 / TIG_MAL | 51, 52, 53, 54, 55, 56, 62 | none | 51, 52, 53, 54, 55, 56, 62 |
| L4_HJ | 2 / TIG_FEM | 46, 47, 48, 49, 50 | none | 46, 47, 48, 49, 50 |
| L4_HJ | 3 / TIG_CUB | 39, 40, 41, 42, 43, 44, 45 | none | 39, 40, 41, 42, 43, 44, 45 |
| L4_HJ | 4 / DINO | 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35 | none | 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35 |
| L4_HJ | 5 / BACL4 | 57, 61, 65 | none | 57, 61, 65 |
| L4_HJ | 6 / L4WW | 0, 66 | none | 0, 66 |
| L4_HJ | 7 / Kelsrick | 64 | none | 64 |
| L4_HJ | 8 / DawnL4 | 63 | none | 63 |
| L4_HJ | 9 / GGuard | 58, 59, 60 | none | 58, 59, 60 |
| L4_HJ | 10 / VILLAGER | none | none | none |
| L4_HJ | 11 / B_HUMAN | 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 | none | 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 |
| L4_HJ | 12 / SSAR | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | none | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 |
| L5_HC | 0 / HIVEW | 21, 22, 23, 24, 25, 26, 27, 28, 29, 32, 33, 34 | 23, 24, 25, 26, 27, 28, 29, 32, 33, 34 | 21, 22 |
| L5_HC | 1 / EXEC | 35, 36 | 35, 36 | none |
| L5_HC | 2 / WORM | 30, 31 | 30, 31 | none |
| L5_HC | 3 / DAWNL4 | 20 | none | 20 |
| L5_HC | 4 / B_HUMAN | 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 | none | 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 |
| L5_HC | 5 / B_HUMAN | 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 | none | 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 |

Reproduce with `python3 tools/audit_act_one_actor_coverage.py`. The JSON pins the source inventory and reviewed implementation hashes. This checks bindings and inventory consistency; it does not execute encounters.

Next: classify the unreviewed placements by source activation and existing scene owners before adding encounters. In particular, the 24 definition4 Roach placements are distinct from live cave actor23; do not treat the single tested duel as coverage of that population. Return groups bind seven additional HIVEW actors23–29; source-region ambushes now bind actors33/35. Rolling boulders30/31 now have partial path/presentation/save bindings; their contact response/damage and sound remain absent. Native AI/presentation limits, alternate activation paths and other placements stay open.
