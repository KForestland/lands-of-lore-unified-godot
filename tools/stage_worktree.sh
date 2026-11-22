#!/bin/sh
set -eu
STAGE_TOOL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$STAGE_TOOL_DIR/stage_worktree.py" "$@"
