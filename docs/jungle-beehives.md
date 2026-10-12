# Jungle beehives (renewable wax)

Props251-253 (template56, three original selector images: full/half/empty) share one source record set. Owner state is the hive's fullness. An empty-hand use (kind4 mode0) at fullness0 or 1 grants one "71-Wax" (identity 0xAE5ADACF; the op3 item property is 4, not a count), advances fullness and selector, and starts the hive's kind2 timers. Those timers (flag 0x10, range bytes 244..250) step fullness 2→1→0, so wax regrows. At fullness2 the use runs op15 sub108 (B6AB5 → DD104: player status +0x225 = 0x27 plus a sound); its gameplay effect is not established and is not hosted. A kind5 value2 hit record (forces empty, swarm, starts both timers) is not hosted either.

`jungle_beehives.gd` renders the three hives with the original art. Aimed, reachable, unobstructed E with an empty hand harvests one wax into the hand (HUD prompt "E — Take wax"); an empty hive explains "The hive is empty." Regrowth uses a fixed 247 s per stage on the active world clock (source units unproven). State is saved in quest_state.jungle_beehives; disk load restores hive and inventory together, so reloading cannot farm wax.

Wax uses a fixed pool of six ids (jungle:beehive:Wax_1..6, Jungle scope, source name "71-Wax"): a harvest takes the lowest id not carried, and wax consumed at the rune inscription frees its id. The rune inscription accepts it like any other "71-Wax" (hive_rune_transaction.is_wax). It travels with the Jungle→Hive handoff.

Validation: actual Jungle host with supplied camera vantage, dispatched E, live regrowth clock, disk reload, pool exhaustion and Hive handoff. Native timer units, two-timer interplay and the swarm status are not established.
