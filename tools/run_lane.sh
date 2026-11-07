#!/bin/bash
# Per-lane render recipe (WORKFLOW_PLAN W5, 2026-10-31): one lane = its own Xvfb display (run_isolated_regressions.py / godot_capture.py
# already start a private Xvfb through -displayfd, so displays never collide) + its own CPU set (taskset), so two lanes can render at
# once without one starving the other's physics ticks. Usage:
#   tools/run_lane.sh CPUSET -- COMMAND...        e.g. tools/run_lane.sh 0-3 -- python3 tools/run_isolated_regressions.py --suite all ...
#   tools/run_lane.sh 4-7 -- python3 ~/opus_work/ai_tools/godot_capture.py --project . --out DIR --scene res://...
# CPUSET is a taskset list (0-3, 4-7, 0,2,4). Everything after -- runs under `taskset -c CPUSET nice -n ${LANE_NICE:-10}`. Pick disjoint
# sets per lane (nproc shows the count); the headless runner of a third lane takes the remaining CPUs the same way. Exit status is the
# command's. No display argument is needed: each run announces "Isolated rendered display :N" from its own Xvfb.
set -u
if [ "${1:-}" = "" ] || [ "${2:-}" != "--" ]; then echo "usage: $0 CPUSET -- COMMAND..." >&2; exit 2; fi
CPUSET="$1"; shift 2
command -v taskset >/dev/null || { echo "taskset not found (util-linux)" >&2; exit 2; }
exec taskset -c "$CPUSET" nice -n "${LANE_NICE:-10}" "$@"
