# Map surface diagnostics

These tools inspect locally generated map exports. They never change source geometry, arrival positions or readiness. Original game data and generated map payloads are not included. The current full preparation pipeline remains in the active local development tree; these tools accept its `index.json`, per-area `review.json`, `geometry/geometry.json`, and ceiling-chain reports. Godot probes additionally require saved scenes exported with structural collision.

Run portable synthetic controls without original assets:

```sh
python3 -m unittest discover -s tests -p 'test_map_*coverage.py'
```

Run a source audit with a local generated map root:

```sh
python3 tools/audit_map_floor_coverage.py --map-root /path/to/maps --out /path/to/floors.json
python3 tools/audit_map_ceiling_coverage.py --map-root /path/to/maps --out /path/to/ceilings.json
python3 tools/audit_map_subdivision_coverage.py --map-root /path/to/maps --out /path/to/subdivisions.json
```

These audits return1 when findings remain, including source-degenerate polygons and parent/child outline differences. A finding is not automatically an exporter defect. Reports retain input hashes, explicit absent surfaces and unresolved results. Subdivision checks are projected XZ coverage, not height continuity; declared selector255 holes remain open. Pairwise overlap totals are not a polygon-union calculation.

Godot commands (use the project's installed Godot executable):

```sh
godot --headless --path . --script res://tests/all_maps_surface_collision_test.gd -- --map-root=/path/to/maps --report=/path/to/surfaces.json
godot --headless --path . --script res://tools/audit_map_arrival_clearance.gd -- --map-root=/path/to/maps --report=/path/to/arrivals.json
godot --headless --path . --script res://tools/probe_thin_triangle_precision.gd -- --map-root=/path/to/maps --report=/path/to/precision.json
```

The arrival diagnostic uses an assumed radius8/height64 capsule and reports alternatives without adopting them. It checks candidate placement and short sweeps, not native form bounds or complete traversal. The precision probe isolates three known source cases at original coordinates and near the origin, with positive and negative controls.

The [execution checklist](execution-checklist.md) tracks the broader maps→Act1→Act2 work. Its completed entries refer to local verified evidence, not an assertion that every associated implementation is already published.
