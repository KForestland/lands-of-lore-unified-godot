#!/usr/bin/env python3
"""Publish guard: refuse a tree that holds owner-derived or machine-local material.

  python3 tools/check_publishable.py [TREE] [--owner-list tests/fixtures/OWNER_DERIVED.md]

Lead decision 2026-11-15 19:48Z: before any export or code snapshot leaves this machine, the tree being exported must
hold none of the following. Each one found is printed and the exit status is 1.
  1. a file listed in OWNER_DERIVED.md (the owner's saves, recordings and their manifests);
  2. a text file containing a local machine path (a home folder), an F10 report id (report_YYYY-MM-DDTHH-MM-SS), or, in a
     data file (.json), a user:// path (a save written on this machine; game code may name user:// freely);
  3. an unlisted file under tests/fixtures whose name holds owner_, report_ or autosave;
  4. any private pattern (the owner's private name and address) listed one per line in the per-user file
     ~/.config/lol2/publish_private_patterns.txt (or $LOL2_PUBLISH_PATTERNS), kept outside every repository so the
     guard never carries them. The check is permanent: when that list is missing or empty the guard refuses everything.
Passing this check is not permission: publishing still needs the owner's yes each time.
Every pattern is case-insensitive and every reading of a file is scanned (UTF-8, UTF-16/32 by BOM or shape, Latin-1 with
NULs removed). A file that is not text is refused unless tools/publishable_binaries.txt allow-lists its path and SHA-256.
Nothing tracked is skipped by folder. Symlinks are always refused. Each reading is scanned again with backslashes read as
slashes and with all whitespace removed (a pattern split by a line break still matches).
A public snapshot is always a fresh tree export of one commit (tools/export_snapshot.py), never a push of this
repository or its history: older commits still hold material this check refuses (the owner's private name until
2026-11-17, owner saves, local paths).
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OWNER_LIST = Path('tests/fixtures/OWNER_DERIVED.md')
PATTERNS_ENV = 'LOL2_PUBLISH_PATTERNS'


def patterns_file() -> Path:
    import os
    return Path(os.environ.get(PATTERNS_ENV) or Path.home() / '.config/lol2/publish_private_patterns.txt')
# Every pattern is case-insensitive (Grok R-guard 2026-11-17: capitalised home paths, report ids and fixture names got through).
LOCAL_PATH = re.compile('/' + 'home/', re.I)  # split so this file does not match itself
REPORT_ID = re.compile(r'report_\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}', re.I)
USER_PATH = re.compile(r'user://', re.I)
FIXTURE_NAME = re.compile(r'owner_|report_|autosave', re.I)
# Binary files leave only when allow-listed by path and SHA-256 (one "sha256  path" per line); a changed file needs
# approval again. Nothing is allow-listed yet: the tracked images, video and sound may be original game data.
BINARY_ALLOW = Path('tools/publishable_binaries.txt')


def listed_paths(owner_list: Path) -> set:
    """Paths in the first column of OWNER_DERIVED.md's table. A bare name continues the previous path's folder; a name
    starting with '.' replaces the previous path's last suffix (`a.json` + `.provenance.json`)."""
    paths = set()
    if not owner_list.is_file():
        return paths
    for line in owner_list.read_text(encoding='utf-8').splitlines():
        if not line.startswith('|'):
            continue
        cells = line.split('|')
        if len(cells) < 3:
            continue
        previous = None
        for token in re.findall(r'`([^`]+)`', cells[1]):
            token = token.strip()
            if token.startswith('.') and previous is not None:
                path = previous.with_suffix('').as_posix() + token
            elif '/' not in token and previous is not None:
                path = (previous.parent / token).as_posix()
            else:
                path = token
            if path.endswith('/'):
                path = path[:-1]
            paths.add(path)
            previous = Path(path)
    return paths


def private_patterns() -> list:
    if not patterns_file().is_file():
        return []
    return [line.strip() for line in patterns_file().read_text(encoding='utf-8').splitlines() if line.strip() and not line.startswith('#')]


def binary_allow(path: Path) -> set:
    """(sha256, path) pairs from this repository's allow-list (never the exported tree's own copy)."""
    allow = set()
    if path.is_file():
        for line in path.read_text(encoding='utf-8').splitlines():
            parts = line.split(None, 1)
            if len(parts) == 2 and not line.startswith('#'):
                allow.add((parts[0].lower(), parts[1].strip()))
    return allow


def readings(data: bytes):
    """(is_text, texts): every way the bytes might read as text. A file is text when it decodes cleanly as UTF-8
    without NUL, or as UTF-16/UTF-32 (by byte-order mark, or UTF-16 by shape). The pattern scan runs on all readings
    whatever the verdict, including Latin-1 with NULs removed (catches ASCII hidden between NULs)."""
    texts = [data.decode('latin-1').replace('\0', ''), data.decode('utf-8', errors='replace').replace('\0', '')]
    is_text = False
    boms = [(b'\xff\xfe\x00\x00', 'utf-32-le'), (b'\x00\x00\xfe\xff', 'utf-32-be'), (b'\xff\xfe', 'utf-16-le'),
            (b'\xfe\xff', 'utf-16-be'), (b'\xef\xbb\xbf', 'utf-8')]
    for bom, codec in boms:
        if data.startswith(bom):
            try:
                texts.append(data[len(bom):].decode(codec)); is_text = True
            except UnicodeDecodeError:
                pass
            break
    try:
        text = data.decode('utf-8')
        if '\0' not in text:
            is_text = True
    except UnicodeDecodeError:
        pass
    for codec in ('utf-16-le', 'utf-16-be'):
        if len(data) % 2:
            continue
        try:
            text = data.decode(codec)
        except UnicodeDecodeError:
            continue
        texts.append(text)
        printable = sum(1 for ch in text if ch.isprintable() or ch in '\r\n\t')
        if text and printable / len(text) > 0.95 and '\0' not in text:
            is_text = True
    # Grok round 3: a pattern split by a line break, a path written with backslashes. Each reading is scanned again
    # with backslashes as slashes, and with all whitespace removed.
    more = []
    for text in texts:
        slashed = text.replace('\\', '/')
        more += [slashed, re.sub(r'\s+', '', text), re.sub(r'\s+', '', slashed)]
    return is_text, texts + more


def check(tree: Path, owner_list: Path, extra_patterns=None, allow_file=None) -> list:
    """Nothing in the tree is skipped by folder (only a top-level .git, which git archive never writes)."""
    tree = tree.resolve()
    listed = {p.casefold() for p in listed_paths(owner_list)}
    patterns = private_patterns() if extra_patterns is None else extra_patterns
    private = [re.compile(re.escape(q), re.I) for p in patterns for q in {p, re.sub(r'\s+', '', p)} if q]
    allow = binary_allow(Path(allow_file) if allow_file else ROOT / BINARY_ALLOW)
    problems = []
    if not patterns:
        problems.append(f'private pattern list {patterns_file()} missing or empty: the name check cannot run, so nothing passes')
    files = []
    for path in sorted(tree.rglob('*')):
        rel = path.relative_to(tree)
        if rel.parts[0] == '.git':
            continue
        if path.is_symlink():
            problems.append(f'symlink (never published): {rel.as_posix()}')
            continue
        if not path.is_file() or path.resolve() == patterns_file().resolve():
            continue
        files.append((path, rel.as_posix()))
    for path, rel in files:
        key = rel.casefold()
        if key in listed or any(key.startswith(entry + '/') for entry in listed):
            problems.append(f'owner-derived (OWNER_DERIVED.md): {rel}')
            continue
        found = []
        if key.startswith('tests/fixtures/') and rel != OWNER_LIST.as_posix() and FIXTURE_NAME.search(Path(rel).name):
            found.append('unlisted owner-like fixture name')
        data = path.read_bytes()
        is_text, texts = readings(data)
        if not is_text:
            import hashlib
            if (hashlib.sha256(data).hexdigest(), rel) not in allow:
                found.append('binary or undecodable, not allow-listed')
        if any(LOCAL_PATH.search(t) for t in texts):
            found.append('local path')
        if any(REPORT_ID.search(t) for t in texts):
            found.append('F10 report id')
        if key.endswith('.json') and any(USER_PATH.search(t) for t in texts):
            found.append('user:// path in data')
        if any(rx.search(t) for rx in private for t in texts):
            found.append('private pattern')
        if found:
            problems.append(f'{", ".join(found)}: {rel}')
    return problems


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('tree', nargs='?', default=str(ROOT))
    parser.add_argument('--owner-list', help='default: TREE/tests/fixtures/OWNER_DERIVED.md, else this repository\'s')
    args = parser.parse_args(argv)
    tree = Path(args.tree)
    owner_list = Path(args.owner_list) if args.owner_list else (tree / OWNER_LIST if (tree / OWNER_LIST).is_file() else ROOT / OWNER_LIST)
    if not owner_list.is_file():
        print(f'FAIL publish guard: owner list {owner_list} missing; refusing without it')
        return 1
    problems = check(tree, owner_list)
    for problem in problems:
        print('  ' + problem)
    if problems:
        print(f'FAIL publish guard: {len(problems)} file(s) must not leave this machine ({tree})')
        return 1
    print(f'PASS publish guard: nothing owner-derived or machine-local in {tree}. Publishing still needs the owner\'s yes.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
