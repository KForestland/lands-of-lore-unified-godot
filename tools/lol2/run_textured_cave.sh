#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
exec flatpak run org.godotengine.Godot --path "$project_root" res://scenes/lol2/textured_cave_review.tscn -- "$@"
