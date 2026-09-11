# Room-scale cave inspection — 2026-09-11

Added right-click floor picking and focused orbit inspection to the original
Godot cave review. Picking intersects the original rendered floor triangles
mathematically; it does not add physics collision or establish walkability.
Focus reports the region ID/material descriptor and opens a cutaway by hiding
boundary walls and ceilings. B/C restore those layers. N cycles regions 10,13,
30 and 799 (step/subdivision/special-opening examples); R restores full overview.
I continues to toggle provisional amber interior spans.

Validation: Godot renders successfully. Initial room-scale render was occluded
by tall shell walls; cutaway focus fixes this. Region 13 cutaway was captured
and visually inspected at `captures/original_room_review.png` in the Godot
project. It shows height transitions and candidate spans clearly. This confirms
review usability, not native wall correctness; floor UVs remain conspicuously
diagnostic in the water area. No collision, material binding or native evidence
was promoted during this UI pass.

Run `/home/bob/run_lol2_original_floors.sh`.
Changed: scripts/lol2/original_floor_review.gd in the Godot project.
Next: use the close-up views with original-game evidence to resolve step and
special-opening behavior before collision generation and playable traversal.
