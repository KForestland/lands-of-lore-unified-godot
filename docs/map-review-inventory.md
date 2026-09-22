# Map review inventory

`tools/build_map_review_inventory.py` turns locally prepared map exports into a
review checklist. It groups primary regions by their source neighbor links,
records component bounds and arrivals, and counts prepared mechanism states.
It does not extract game archives, distribute assets, or mark maps complete.

```sh
python3 tools/build_map_review_inventory.py --maps-root /path/to/prepared/maps
python3 -m unittest discover -s tests -p test_map_review_inventory.py
```

Each map directory supplies three JSON files:

- `geometry/geometry.json`: `source`, `vertices_fixed`, and `regions`. Each region
  has an integer `id`, `record_role`, `neighbors`, `vertex_indices`,
  `floor_corners`, and `ceiling_corners`; child records may have an `owner`.
- `geometry/arrivals.json`: `entries` with `index` and `region`, plus optional
  `adjacent_labels`. Labels stay unbound; they are not assigned to components.
- `review.json`: `faces` with `kind` and `region`, optional `geometry_issues`,
  `movable_placements`, `movable_state_faces`, and `attached_state_props`.
  Source archive hashes must agree when the review supplies a hash.

Primary-region components use undirected connectivity: either region listing
the other establishes a link. This is a review grouping, not a navigation or
reachability graph. `None` is a boundary. Unknown neighbor IDs and duplicate
region IDs are rejected. Child records do not become component members; their
faces, arrivals and issues remain separately accounted for. World coordinates
use x=fixed_x/65536, z=-fixed_y/65536, and source integer heights.

The tool writes each map's `review_inventory.json` and root-level JSON/Markdown
indexes. Component rows preserve source IDs, bounds, arrival IDs, face counts
and geometry issues. Mechanism rows preserve placement/child/mask provenance
for initial and later-state assets. State reachability is unknown (`null`),
visual QA is pending, and `ready_for_content` remains false.

On the current local 15-map export, the inventory accounts for 237 primary-region
components, 164,840 emitted faces, 5,026 initial mechanism faces, 292 later-state
faces and nine later-state attached sprites. These are extraction/review counts,
not evidence that every map matches the original game. Generated reports, game
archives, textures, saved scenes and screenshots remain local.
