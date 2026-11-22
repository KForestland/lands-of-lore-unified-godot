# Per-object earned routes follow-up

This follow-up is isolated in lol2_sol_dark_halls_next while lol2_sol_dark_halls stays frozen for the affected sweep.

Knot: the initial floor-whole-edge route graph reached slide1015 but falsely left slides1041/1013 far from any approach. That was a route-planner result, not evidence that the player needed a geometry change or crouch at those slides.

Facts: original L7 records expose their four neighbor IDs at record words2..5. Some neighbors meet along partial edges, so requiring identical exported edge endpoints loses valid connections. Source-neighbor BFS reaches floor106 near1041 and floor161 near1013. Native source hash is checked by prepare_dark_halls_routes.Hive.load. A source route is only a plan; collisions, scripted gates, combat and pointing must still pass in the live host.

Builder read: use the original topological links to choose the walk, then let actual W/Shift/mouse input and world physics prove it. Do not widen a wall because a test planner lost a connection. Risks: a topological link needs a gate opened; an approach-floor center lies in a closed leaf; an enemy or trap genuinely changes the route. Flip point: an actual-input1041 walk distinguishes the planner bug from a world blocker. Next check: dark_halls_objects_earned_test with LOL2_DH_OBJECTS=slides:1041.

The registered test takes comma-separated objectives (slides:1041, bookcases:58, etc.) from LOL2_DH_OBJECTS. It enters via the pinned monastery/cellar witness, writes an actual arrival quicksave and reloads that real entry for each objective. The child input helper only uses E on a visible closed shelf/door on the direction of travel, captures the interaction, and lets native scripts change the leaf. It never mutates positions, health, inventory or quests and never disables population or route processing. A closed trap must be resolved through the live combat system. Missing inputs skip via registry needs, rather than silently generating a supplied goal fixture.

Generators: tools/build_dark_halls_objects_walk.py --game ~/lol2_runtime_root writes the new route plan, keeping the previously earned slide1015 route fixture intact. Test helper is a supporting script, not a standalone executable test.

First next check PASS: tmp/sol_objects_1041_first/report.json,83.42s/source_stable; actual input opens door56 on route and then toggles slide1041 and reloads. Closed/open captures inspected. Remaining six unproved objectives queued as one explicit list in tmp/sol_objects_remaining_first (not yet PASS). godot_check2/0 on follow-up scripts.

Route failure retained: tmp/sol_objects_remaining_first stopped7.3 units short of a waypoint on a14-unit portal. The source graph had selected a thin floor strip next to the standing corridor; the30-unit Human capsule cannot occupy its midpoint. The planner now rejects links shorter than the existing Human diameter and uses the adjacent standing corridor. This is a route planning constraint, not a movement tolerance change. The second run was deliberately stopped (SIGTERM to this worktree's engine only, log retained) after discovering the original slide texture variants, so it is not a passing receipt. No world geometry was changed.
