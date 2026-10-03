# Cave guard placements — source leads (2026-10-03, not implemented)

Static decode of L1_DC (`collect_owners` + stream groups). Leads only.

| Actor | Label/def | Source position (x,y,z) | HP | Behaviour | Wake / script owners |
| --- | --- | --- | --- | --- | --- |
| 56 | GGCAPT/0 | (-2057, 63, -4430) | 200 | 14 | control120 event6 (op9/op16/property13 0x0C,0x0B,7); own events 4/6/9/10 run states, item grants |
| 39 | GGUARD/1 | (-1051, 0, -5871) | 150 | 14 | regions 769/772/775 (pred51) property13/7; region631 (pred22); control109 (two branches); prop533 |
| 52 | GGUARD/2 | (-163, -10, -7834) | 150 | 14 | region1104 property13/7; control114, control119 |
| 38 | GGUARD/1 | (-532, -200, -10347) | 150 | 4 | region1941 (pred48) + item grant; prop152 sequences (pred200/202) |
| 53 | GGUARD/2 | (159, -215, -12009) | 150 | 4 | regions106/121 op9 property3 |
| 54 | GGUARD/1 | (-264, -270, -15435) | 150 | 14 | region969 (pred9) op9 property3 |
| 1, 2 | GGUARD/2,1 | (17,-285,-16493), (-48,-285,-16609) | 140 | 6 | region23 event4 op9 property3; event11 handlers |
| 24 | WORM/8 | (-1993, 44, -5677) | 50 | 14 | prop1305 sequences; own event2/4/6 |
| 36, 37 | WORM/6 | (-655,-430,-13734), (272,-430,-14004) | 150 | 14 | own event9 property writes |
| 55 | B_HUMAN/7 | (-272, -270, -15254) | 0 | 14 | region969; event3/pred3 addresses 21/22 |
| 3–22 | B_HUMAN/9,10 | grid x2496–2752, z-17504…-17760 | 0 | 6 | none (off-map staging pool) |

Several guards lie on the earned cave route (39, 52, 38, 53). Item grants use identities 0xe29a1126 and 0x9e689a13 ("38-Guard shield"). Next: decode op9 property3/op16/op6 semantics for these actors with the native dispatcher, the control109/114/119/120 interactions, then implement with the shared creature rules.
