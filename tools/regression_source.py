"""Record portable project inputs, excluding original media and personal saves."""
import hashlib
from pathlib import Path

SUFFIXES = {'.gd', '.gdshader', '.gdshaderinc', '.tscn', '.tres', '.json'}


def snapshot(root: Path) -> dict:
    paths = {root / 'project.godot'}
    paths.update(root / 'tools' / name for name in (
        'run_regressions.py', 'run_isolated_regressions.py', 'regression_source.py'))
    for directory in ('scripts', 'scenes', 'tests'):
        paths.update(p for p in (root / directory).rglob('*')
                     if p.is_file() and not p.is_symlink() and p.suffix in SUFFIXES)
    result = {}
    for path in sorted(paths):
        try:
            result[path.relative_to(root).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
        except FileNotFoundError:
            # A concurrent removal is visible, never silently treated as a hash.
            result[path.relative_to(root).as_posix()] = None
    return result


def changes(before: dict, after: dict) -> list:
    return sorted(key for key in before.keys() | after.keys()
                  if key not in before or key not in after or before[key] != after[key])
