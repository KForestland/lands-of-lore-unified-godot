# Expanded capsule traversal — 2026-09-11

The expanded selector finds 119 ordinary continuous seams: 100 flat pairs and
19 sloped pairs. All 238 directional routes pass with grounded vertical velocity
zero, airborne gravity 128 units/s², and floor snap 4. Recovered ceilings and
provisional absent-neighbor boundary walls are included. No initial capsule
penetration or airborne movement frames occur on these routes.

Six negative control routes also behave as intended: missing floors fail to
settle and fall; a synthetic wall perpendicular to the route starts clear and
blocks arrival; synthetic ceiling height 32 intersects the assumed height-64
capsule at spawn and is rejected. The low-ceiling control can be pushed onto
the ceiling by physics, so arrival alone is deliberately insufficient for success.
All 244 expectations pass in Godot 4.7.2. Controls are synthetic test fixtures,
not modifications to the original cave.

The previous constant-downward-velocity controller timed out uphill from region
625 to 623, with and without the shell. The gravity-motion comparison resolves
that timeout without changing source geometry, speed or the 180-frame limit.
Historical comparison reports remain in captures; the current report is
captures/capsule_traversal_audit_expanded_shell_gravity.json.

## Reproduce

From /home/bob/lands-of-lore-unified-godot:

```sh
python3 tools/lol2/build_traversal_fixtures.py --all
flatpak run org.godotengine.Godot --headless --fixed-fps 60 --path . res://scenes/lol2/capsule_traversal_audit.tscn -- --expanded --shell --gravity-motion
```

Omit --all / --expanded for the earlier six-pair subset. Omit --shell to isolate
floors; omit --gravity-motion to reproduce the older forced-downward controller.
Fixture generation also refreshes shell geometry for the subset when run without
--all. The report records which switches were used.

## Scope

The selector still requires unique ordinary reciprocal indexed edges, continuous
floor endpoints, seam length >=128, and both quad centroids at least 48 horizontal
units from the seam midpoint. Routes extend 32 horizontal units each side toward
the centroids. It does not cover all cave connections, subdivisions or special
connectors. Original-unit coordinates are translated to each seam midpoint.
Capsule radius 8, height 64, speed 32, safe margin 0.05 remain assumptions. Initial
penetration uses a slightly smaller capsule (radius 7.9, height 63.8) to avoid
classifying numerical floor contact as penetration.

Wall spans are provisional. This does not validate native collision, full-world
precision, interactive objects, hazards, steps, textures or original player size.
The review and default scene are unchanged. Next: use this tested controller in
an explicitly experimental local walk view, retaining an easy reset and keeping
unverified special connections out of fidelity claims.

Correction: shell fixtures also include provisional interior-span candidates. See CONNECTED_WALK_REVIEW.md for scope clarification.
