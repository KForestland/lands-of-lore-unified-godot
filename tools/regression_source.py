"""Record portable project inputs, excluding original media and personal saves."""
import hashlib
from pathlib import Path

SUFFIXES = {'.gd', '.gdshader', '.gdshaderinc', '.tscn', '.tres', '.json'}


def snapshot(root: Path) -> dict:
    paths = {root / 'project.godot'}
    paths.update(root / 'tools' / name for name in (
        'run_regressions.py', 'run_isolated_regressions.py', 'regression_source.py', 'stage_worktree.py', 'prepare_playtest_starts.py',
        'test_prepare_playtest_starts.py', 'validate_playtest_starts.gd'))
    paths.update(root / 'tools' / name for name in (
        'check_item_grant_census.py', 'test_item_grant_census.py'))
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


SCOPE = ('project.godot', 'scripts', 'scenes', 'tests', 'tools')


def git_state(root: Path) -> dict:
    """HEAD and the porcelain status of the source scope (docs/ is left out: tests write their check reports there)."""
    import subprocess
    def run(*args):
        result = subprocess.run(['git', '-C', str(root), *args], capture_output=True, text=True)
        return result.stdout.strip() if result.returncode == 0 else None
    return {'head': run('rev-parse', 'HEAD'), 'status': run('status', '--porcelain', '--', *SCOPE)}


MARKER = Path('tmp') / 'GATE_RUNNING'


def gate_marker(root: Path):
    """The live gate in this worktree, or None. A marker whose process is gone is stale and ignored."""
    import json, os
    path = root / MARKER
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text())
        os.kill(int(data['pid']), 0)
        return data
    except (ValueError, KeyError, ProcessLookupError, PermissionError, OSError):
        return None
