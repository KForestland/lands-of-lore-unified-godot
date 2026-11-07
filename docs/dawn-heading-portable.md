# Dawn cast heading

`dawn_heading.gd` reproduces original helper1366EA. Cast positioning shifts its byte result left eight bits. It preserves the integer ratio, quadrant/reflection rules, small-coordinate scaling, signed endpoint comparisons and unsigned wrapped differences. Coincident points return255, as in the original.

612 native Unicorn executions match the Godot implementation:100 axis/boundary combinations and512 deterministic full signed32 endpoint pairs. Run `godot --headless --path . --script res://tests/dawn_heading_test.gd` without original media. Numeric fixture records executable and code hashes. This verifies heading arithmetic; it does not establish effect spawning, world movement or live target selection.

Prepared outside the shared main source while its240-test regression run is active. Main integration remains pending that run; this component publication is not a demo build.
