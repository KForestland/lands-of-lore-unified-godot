# Original cave interior-span candidates — 2026-09-11

Added 955 geometric exposure candidates on 6354 eligible directed
neighbor edges. Only unique reciprocal edges sharing the same original vertex
indices are accepted. Floor/ceiling intervals are compared along each edge;
all crossings between their linear height functions split the edge. Only source
room vertical intervals outside the neighbor opening are emitted. The opening
itself stays clear. Subdivision owners/children, special flag-0x10 connectors
and nonmatching edges are deferred with per-edge reasons in interior_audit.json.

These are geometric candidates, NOT a replay of the native wall builder. They
may need different topology/materials or exceptions. They remain an amber,
default-hidden review layer toggled with I. No collision is generated from them.
B/C still toggle boundary walls and ceilings. Run the existing launcher
`/home/bob/run_lol2_original_floors.sh`.

Tests: equal openings produce no span; narrower openings preserve the open
interval; crossing slopes and vertically disjoint rooms are checked against
pointwise interval membership. Three tests pass. Godot scene/count smoke passes;
GUI capture with the amber layer enabled was inspected at overview scale.
Detailed/native comparison is still required before promoting these candidates.

Implementation: tools/lol2/interior_spans.py and test_interior_spans.py,
import_original_floors.py and original_floor_review.gd under the Godot project.
Next: close-up navigation/inspection of representative step and sloped spans,
then native wall comparison and scoped collision. Special openings remain open.
