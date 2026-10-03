# Creature navigation (modern adapter, 2026-10-03)

Woken, combat-ready scripted creatures (cave guards, Museum skeletons/Rat, provoked Huline villagers) that cannot see the player but are within 1200 units follow the map's own region graph:

- `tools/prepare_creature_nav.py` exports `assets/lol2/generated/creature_nav/<area>.json` for L1_DC, L3_DH, L4_HJ and L5_HC from the pinned all-map geometry: source region quads and floors, and portal midpoints between neighbouring regions with ≥47 units standing clearance, ≤32 units floor step and ≥24-unit portal width (the filters the earned route builders already use).
- `scripts/lol2/creature_navigation.gd`: grid-indexed region lookup, bounded A* (600 expansions) over portals, returning the next portal midpoint. The generic owner caches it per actor and refreshes every 0.5 s or on arrival; existing ledge and floor guards still apply.

Not native: LoL2's own path slots (`6F4A0`, Grok's DINO waypoint lane) and goal scheduling are not replayed. The Jungle DINO population (separate owner) and the Roach population do not use this yet.

Checks: `creature_navigation_test` (graph load, region lookup, route from guard 39's side room; live guard 39 spawned by region 775 reaches and strikes the player). Earned cave→Museum (route17) and Museum→Jungle (walk7) pass with navigation enabled.
