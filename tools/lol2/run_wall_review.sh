#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
exec flatpak run org.godotengine.Godot --path "$project_dir" res://scenes/lol2/wall_texture_review.tscn "$@"
