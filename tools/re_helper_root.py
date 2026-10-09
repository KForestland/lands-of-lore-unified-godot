"""Resolve the external lands-of-lore-2-re helper checkout (github.com/KForestland/lands-of-lore-2-re).

Set LOL2_RE_ROOT to the checkout root (the directory that contains tools/ and tools/draracle/). Without it, the
historical local checkout /home/bob/lol2_re_publish_20260911 is used when present, so existing local runs are unchanged.
An explicitly set but invalid LOL2_RE_ROOT (including an empty value) always fails with a clear error instead of silently importing elsewhere.
insert(*parts) repeats sys.path.insert(0, ...) for each part in order, exactly like the literal inserts it replaces.
"""
import os
import sys
from pathlib import Path

ENV = 'LOL2_RE_ROOT'
LEGACY = Path('/home/bob/lol2_re_publish_20260911')
PARTS = {'tools': Path('tools'), 'draracle': Path('tools/draracle')}


class HelperRootError(RuntimeError):
    pass


def _valid(path: Path) -> bool:
    return all((path / part).is_dir() for part in PARTS.values())


def root(required: bool = True):
    value = os.environ.get(ENV)
    if value is not None:  # explicitly set, including empty or whitespace: never fall back
        if not value.strip():
            raise HelperRootError(f'{ENV} is set but empty; unset it to use the legacy local path, or point it at a lands-of-lore-2-re checkout')
        path = Path(value).expanduser()
        if not _valid(path):
            raise HelperRootError(f'{ENV}={value!r} is not a lands-of-lore-2-re checkout: it must contain tools/ and tools/draracle/')
        return path.resolve()
    if _valid(LEGACY):
        return LEGACY
    if required:
        raise HelperRootError(f'Set {ENV} to a lands-of-lore-2-re checkout (containing tools/ and tools/draracle/); '
                              f'the legacy local path {LEGACY} is not available.')
    return None


def path(part: str, required: bool = True):
    base = root(required)
    return None if base is None else base / PARTS[part]


def insert(*parts: str, required: bool = True) -> None:
    base = root(required)
    if base is None:
        return
    for part in parts:
        sys.path.insert(0, str(base / PARTS[part]))
