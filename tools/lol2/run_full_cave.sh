#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ ! -f "$project_dir/assets/lol2/generated/original_floors/full_walk.json" ]]; then
  echo 'Generated cave assets are missing. See docs/RESTORATION_STATUS.md.' >&2
  exit 1
fi
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$project_dir" res://scenes/lol2/original_walk_review.tscn -- --full-map "$@"
fi
exec flatpak run org.godotengine.Godot --path "$project_dir" res://scenes/lol2/original_walk_review.tscn -- --full-map "$@"
