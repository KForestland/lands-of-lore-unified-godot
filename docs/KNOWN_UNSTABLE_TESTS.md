# Measured unstable subchecks

`cave_prop83_lift_live_test`: the **later wall-clock audio sample** is diagnostic
until the load/frame speed budget is established. It reports its residual in
seconds, the measured quickload duration and their ratio. A ratio is an
observation, not a tolerance or proof of cause. The original 0.06-second
classifier remains unchanged and its observed verdict is printed separately.

The hard gate still checks saved sound state, one restore/seek, its derived
offset and immediate playback position, inventory/cursor pause, the strike and
chain, the opened wall, the physical lift/ride and mid-lift save/reload. Only a
`wall_clock` failure in the later sample continues to those outcome checks;
deterministic state/seek failures still fail the test. No production lift or
audio code changes.

Evidence: the exact old r19o head 787c707 reproduced the same late-sample failure
in 3 of 20 reload observations, with deterministic state/immediate seek valid in
all 20. Opus independently passed the complete lift outcome on 63cdbbc alone.
Lead approved this split on 2026-11-15 at 09:35Z. The full lift test uses disclosed
controller/physics steps; it is not an unaided held-key route claim.
