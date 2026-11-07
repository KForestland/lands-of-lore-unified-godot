# Cave lava contact

Bob confirmed on 2026-09-24 that the purple surfaces in the late cave chamber
are lethal lava. The recovered all-map floor bindings identify material135
on86 floor regions. These are86 of the old cave scene's93 purple unresolved
floor patches. The seven remaining patches are deliberately excluded.

`tools/prepare_cave_lava.py` stages the material ownership, source hashes and
original cave floor polygons. `cave_lava.gd` checks grounded feet against those
polygons and heights. The playable cave sets health to zero on contact, stops
motion, rejects saving over a living save, and retains R/F9 recovery. Flight,
airborne traversal and points above the lava are excluded. Geometry is unchanged.

Lethality is user-confirmed. Immediate death on grounded contact is a modern
policy; original damage cadence, immunity and form-specific behavior are not
verified. Since 2026-10-14 the 86 regions draw the original 10-frame lava (descriptors
135-144) instead of the purple placeholder; see `docs/cave-animated-floors.md`. Other purple surfaces must not be classified
as hazards solely by color.

`tests/cave_lava_test.gd` passes real physical landing/death, rock/water/other
placeholder exclusions, altitude/flight exclusions, death-save rejection and
reset/load recovery. Its local spawn is a hazard fixture, not a full playthrough.
Evidence: `~/lol2_out/visibility_route_20260923/cave_lava_test.log`.
The route around the pools remains under traversal test.
