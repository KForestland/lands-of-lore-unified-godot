#!/usr/bin/env python3
"""Stage the playtest start saves (docs/playtest-starts.md).

scripts/lol2/playtest_starts.json (committed) names WHICH earned saves are playtest starts and pins each by sha256.
This tool copies those files from a campaign output folder into assets/lol2/generated/playtest_starts/ (generated,
git-ignored, exported through the assets/*.json include filter):

  prepare_playtest_starts.py --from DIR --godot CMD [--only ID ...] [--dry-run]
  prepare_playtest_starts.py --describe FILE      # sha256 + format + resume kind, to write a new manifest entry

Refuses (exit 1, nothing staged): an --only id that is not in the manifest, a missing file, a file whose sha256 differs
from the manifest pin, or a file the game's own save reader/validator rejects (tools/validate_playtest_starts.gd, run in
Godot against a private temporary copy). Only then are the files moved into place, with a receipt
(_staged_receipt.json). Files already staged for other entries are kept.
"""
import argparse
import hashlib
import json
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'scripts/lol2/playtest_starts.json'
DEST = ROOT / 'assets/lol2/generated/playtest_starts'
RECEIPT = '_staged_receipt.json'
KIND_BY_FORMAT = {
    'lol2-restoration-museum': 'museum',
    'lol2-restoration-jungle': 'jungle',
    'lol2-restoration-hive': 'hive',
    'lol2-restoration-darker-jungle': 'darker',
    'lol2-restoration-dark-halls': 'dark_halls',
}
MARKER = 'PLAYTEST_STARTS_VALIDATION '


class Refused(Exception):
    pass


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def load_manifest(path=MANIFEST):
    data = json.loads(Path(path).read_text())
    if data.get('schema') != 1 or not isinstance(data.get('entries'), list):
        raise Refused(f'{path}: unsupported manifest')
    ids, saves = set(), set()
    for entry in data['entries']:
        for field in ('id', 'title', 'act', 'area', 'resume', 'save', 'sha256', 'source', 'identities'):
            if field not in entry:
                raise Refused(f'manifest entry {entry.get("id")!r}: missing {field}')
        for field in ('test', 'commit', 'input_sha256'):
            if field not in entry['source']:
                raise Refused(f'manifest entry {entry["id"]}: source missing {field}')
        if entry['resume'] not in KIND_BY_FORMAT.values():
            raise Refused(f'manifest entry {entry["id"]}: unknown resume kind {entry["resume"]!r}')
        name = entry['save']
        if Path(name).name != name or not name.endswith('.json') or name.startswith(('.', '_')):
            raise Refused(f'manifest entry {entry["id"]}: unsafe save name {name!r}')
        if entry['id'] in ids or name in saves:
            raise Refused(f'manifest entry {entry["id"]}: duplicate id or save')
        ids.add(entry['id'])
        saves.add(name)
    return data['entries']


def describe(path):
    data = json.loads(Path(path).read_text())
    fmt = data.get('format') if isinstance(data, dict) else None
    kind = KIND_BY_FORMAT.get(fmt)
    print(json.dumps({'save': Path(path).name, 'sha256': digest(path), 'format': fmt,
                      'source': {'test': 'FILL', 'commit': 'FILL (40 hex)', 'input_sha256': 'FILL or null'},
                      'identities': {'contains': {'inventory.collected': []}, 'excludes': {}, 'values': {}},
                      'resume': kind or f'UNSUPPORTED ({fmt}): needs a gate resume branch first'}, indent=2))
    return 0 if kind else 1


def validate(godot, project, folder, ids, manifest=MANIFEST):
    command = [*godot, '--headless', '--path', str(project), '--script', 'res://tools/validate_playtest_starts.gd',
               '--', f'--dir={folder}', '--only=' + ','.join(ids), f'--manifest={Path(manifest).resolve()}']
    result = subprocess.run(command, capture_output=True, text=True, timeout=300)
    lines = [line for line in result.stdout.splitlines() if line.startswith(MARKER)]
    if not lines:
        raise Refused('validator printed no result (exit %d): %s' % (result.returncode, (result.stdout + result.stderr)[-1500:]))
    report = json.loads(lines[-1][len(MARKER):])
    checked = {row['id'] for row in report['entries']}
    if result.returncode != 0 or not report.get('passed') or checked != set(ids):
        bad = [f'{row["id"]}: {row["error"]}' for row in report['entries'] if row['error']]
        raise Refused('game validator refused: ' + ('; '.join(bad) or report.get('manifest_error') or 'entries not checked'))
    return report


def stage(source, godot, only=(), dry_run=False, project=ROOT, dest=DEST, manifest=MANIFEST, out=print):
    entries = load_manifest(manifest)
    known = {entry['id']: entry for entry in entries}
    unknown = sorted(set(only) - known.keys())
    if unknown:
        raise Refused('not in the manifest: ' + ', '.join(unknown))
    chosen = [entry for entry in entries if not only or entry['id'] in only]
    source = Path(source).resolve()
    for entry in chosen:
        path = source / entry['save']
        if not path.is_file() or path.is_symlink():
            raise Refused(f'{entry["id"]}: missing {path}')
        actual = digest(path)
        if actual != entry['sha256']:
            raise Refused(f'{entry["id"]}: {path} sha256 {actual} differs from the manifest pin {entry["sha256"]}')
    with tempfile.TemporaryDirectory(prefix='playtest_starts_') as temporary:
        for entry in chosen:
            shutil.copyfile(source / entry['save'], Path(temporary) / entry['save'])
            if digest(Path(temporary) / entry['save']) != entry['sha256']:
                raise Refused(f'{entry["id"]}: copy changed bytes')
        report = validate(godot, project, temporary, [entry['id'] for entry in chosen], manifest)
        out(f'game validator: {len(report["entries"])} saves PASS')
        if dry_run:
            out('dry run: nothing staged')
            return report
        dest.mkdir(parents=True, exist_ok=True)
        for entry in chosen:
            target = dest / entry['save']
            partial = target.with_name(target.name + '.partial')
            shutil.copyfile(Path(temporary) / entry['save'], partial)
            partial.replace(target)
            out(f'staged {entry["id"]}: {entry["save"]} {entry["sha256"]}')
    receipt_path = dest / RECEIPT
    receipt = json.loads(receipt_path.read_text()) if receipt_path.is_file() else {'entries': {}}
    for entry in chosen:
        receipt['entries'][entry['id']] = {'save': entry['save'], 'sha256': entry['sha256'],
                                           'from': str(source / entry['save']), 'validator': 'tools/validate_playtest_starts.gd'}
    receipt['manifest_sha256'] = digest(manifest)
    receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--from', dest='source', type=Path, help='Folder holding the earned saves (campaign userdata)')
    parser.add_argument('--godot', help='Godot command prefix, e.g. "tmp/godot_host_starts.sh" (default: godot on PATH)')
    parser.add_argument('--only', action='append', default=[], metavar='ID', help='Stage only this manifest id (repeatable)')
    parser.add_argument('--dry-run', action='store_true', help='Check and validate; do not stage')
    parser.add_argument('--describe', type=Path, metavar='FILE', help='Print sha256/format/resume kind for a new manifest entry')
    args = parser.parse_args(argv)
    if args.describe:
        return describe(args.describe)
    if not args.source:
        parser.error('--from DIR is required')
    godot = shlex.split(args.godot) if args.godot else [shutil.which('godot') or '']
    if not godot[0]:
        parser.error('Godot not found; supply --godot COMMAND')
    try:
        stage(args.source, godot, args.only, args.dry_run)
    except (Refused, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f'refused: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
