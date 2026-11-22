#!/usr/bin/env python3
"""Export a code snapshot of one commit, guarded.

  python3 tools/export_snapshot.py --out DIR [--rev HEAD]

Writes the commit's tracked files (git archive) to DIR/.staging, runs tools/check_publishable.py on that copy with this
repository's OWNER_DERIVED.md, and only when it passes renames it to DIR/snapshot_<short rev>. On failure the staging
copy is deleted and nothing is left in DIR. The snapshot is local: this tool never pushes, and publishing still needs
the owner's yes each time (lead decision 2026-11-15 19:48Z).
A public snapshot is always such a fresh tree export, never a push of this repository or its history.
"""
import argparse
import io
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import check_publishable  # noqa: E402


def export(repo: Path, rev: str, out: Path) -> int:
    short = subprocess.run(['git', 'rev-parse', '--short=8', rev], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()
    final = out / f'snapshot_{short}'
    staging = out / '.staging'
    if final.exists() or staging.exists():
        print(f'FAIL export: {final} or {staging} already exists')
        return 1
    out.mkdir(parents=True, exist_ok=True)
    archive = subprocess.run(['git', 'archive', '--format=tar', rev], cwd=repo, check=True, capture_output=True).stdout
    staging.mkdir()
    try:
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            links = [m.name for m in tar.getmembers() if m.issym() or m.islnk()]
            if links:
                for name in links:
                    print('  symlink (never published): ' + name)
                print(f'FAIL export refused: {len(links)} symlink(s) at {short}; nothing written')
                shutil.rmtree(staging)
                return 1
            tar.extractall(staging, filter='data')
        problems = check_publishable.check(staging, repo / check_publishable.OWNER_LIST)
        if problems:
            for problem in problems:
                print('  ' + problem)
            print(f'FAIL export refused: {len(problems)} file(s) at {short} must not leave this machine; nothing written')
            shutil.rmtree(staging)
            return 1
        staging.rename(final)
    except BaseException:
        if staging.exists():
            shutil.rmtree(staging)
        raise
    print(f'PASS export: {final} (local only; publishing still needs the owner\'s yes)')
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--rev', default='HEAD')
    parser.add_argument('--repo', type=Path, default=ROOT)
    args = parser.parse_args(argv)
    if not (args.repo / check_publishable.OWNER_LIST).is_file():
        print('FAIL export: OWNER_DERIVED.md missing; refusing without it')
        return 1
    return export(args.repo, args.rev, args.out)


if __name__ == '__main__':
    sys.exit(main())
