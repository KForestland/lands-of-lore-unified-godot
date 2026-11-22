#!/usr/bin/env python3
"""Copy prepared, untracked runtime/test inputs into a project without replacing code or saves."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = Path('tmp/staged_inputs/manifest.json')
USERDATA = Path('tmp/staged_inputs/userdata')
LIQUID_AREAS = ('L3_DH', 'L4_HJ', 'L8_SJ', 'L19_BC')


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def tracked(root):
    result = subprocess.run(['git', '-C', str(root), 'ls-files', '-z'], capture_output=True, check=True)
    return {name.decode() for name in result.stdout.split(b'\0') if name}


def user_relative(root):
    text = (root / 'project.godot').read_text()
    def setting(name, default):
        match = re.search(r'^' + re.escape(name) + r'=(.+)$', text, re.M)
        return json.loads(match[1]) if match else default
    if setting('config/use_custom_user_dir', False):
        result = Path(setting('config/custom_user_dir_name', ''))
    else:
        result = Path('godot/app_userdata') / setting('config/name', root.name)
    if not result.parts or result.is_absolute() or '..' in result.parts:
        raise ValueError('Unsafe project user directory')
    return result


def safe_destination(root, relative):
    if relative.is_absolute() or '..' in relative.parts:
        raise ValueError(f'Unsafe staging destination: {relative}')
    path = root
    for part in relative.parts:
        path /= part
        if path.is_symlink():
            raise ValueError(f'Refusing destination symlink (could modify the donor): {path}')
    return path


def files(folder):
    if not folder.is_dir():
        return
    # Follow prepared-media links, but stop cycles. Never install symlinks in the destination.
    seen = set()
    for parent, directories, names in os.walk(folder, followlinks=True):
        real = Path(parent).resolve()
        if real in seen:
            directories[:] = []
            continue
        seen.add(real)
        directories.sort()
        for name in sorted(names):
            path = Path(parent) / name
            if path.is_file() and not name.endswith(('.tmp', '.log')):
                yield path


def pinned_test_inputs(destination):
    """Required published artifacts; no dependency on one lane's donor tmp/."""
    for manifest in sorted((destination / 'tests/fixtures').glob('*_inputs_manifest.json')):
        data = json.loads(manifest.read_text())
        if data.get('format') != 'lol2-pinned-test-inputs-v1':
            raise ValueError(f'Unknown pinned input manifest: {manifest}')
        for row in data.get('files', []):
            relative = Path(row['path'])
            if not relative.parts or relative.parts[0] != 'tmp' or relative.suffix != '.json':
                raise ValueError(f'Unsafe pinned test input: {relative}')
            safe_destination(destination, relative)
            source = Path(row['source'])
            if not source.is_absolute() or not source.is_file():
                raise ValueError(f'Required pinned test input missing: {source} ({manifest.name})')
            if digest(source) != row['sha256']:
                raise ValueError(f'Required pinned test input changed: {source} ({manifest.name})')
            yield source, relative


def plan(source, destination, userdata=None):
    source, destination = source.resolve(), destination.resolve()
    if source == destination:
        raise ValueError('Donor and destination must be different projects')
    for root in (source, destination):
        if not (root / 'project.godot').is_file():
            raise ValueError(f'Not a prepared Godot project: {root}')
    source_tracked, destination_tracked = tracked(source), tracked(destination)
    safe_destination(destination, MANIFEST)
    records = {}
    def add(path, relative, category):
        relative = Path(relative)
        if relative.as_posix() in destination_tracked:
            return  # A target revision owns its tracked files, even if the donor differs.
        safe_destination(destination, relative)
        row = {'source': str(path.resolve()), 'path': relative.as_posix(), 'category': category,
               'sha256': digest(path), 'bytes': path.stat().st_size}
        if relative.as_posix() in records and records[relative.as_posix()]['sha256'] != row['sha256']:
            raise ValueError(f'Conflicting staged sources: {relative}')
        records[relative.as_posix()] = row
    generated = source / 'assets/lol2/generated'
    native = source / 'scripts/lol2/native_scripts'
    for area in LIQUID_AREAS:
        for required in (generated / f'liquid/{area}.json', native / f'{area}.json'):
            if not required.is_file():
                raise ValueError(f'Missing prepared donor input: {required}')
    for path in files(generated):
        add(path, Path('assets/lol2/generated') / path.relative_to(generated), 'generated_media')
    for path in sorted(native.glob('*.json')):
        add(path, path.relative_to(source), 'native_script')
    # Untracked region-mover tables (tools/prepare_region_mover.py), e.g. L10_DC.moved.json for a geometry move: without
    # them the tracker falls back to the original table under moved floors (r19m/r19n, 2026-11-14). Tracked ones are the
    # target revision's own (add() skips them); prepare_lane_worktree's geometry-move check is the backstop.
    for path in sorted((source / 'scripts/lol2/region_mover').glob('*.json')):
        if path.relative_to(source).as_posix() not in source_tracked:
            add(path, path.relative_to(source), 'generated_media')
    for path in files(source / 'assets'):
        relative = path.relative_to(source)
        if relative.parts[:3] == ('assets', 'lol2', 'generated') or relative.as_posix() in source_tracked:
            continue
        add(path, relative, 'untracked_material')
    # Copy chain/checkpoint JSON, not launchers, binaries, nested projects, profiles or regression logs.
    temporary = source / 'tmp'
    if temporary.is_dir():
        for parent, directories, names in os.walk(temporary):
            directories[:] = sorted(d for d in directories if 'userdata' not in d.lower()
                                     and d not in ('regressions', '.godot', 'build', '.git')
                                     and not (Path(parent) / d / 'project.godot').exists())
            for name in sorted(names):
                path = Path(parent) / name
                relative = path.relative_to(source)
                if name.endswith('.json') and (name.endswith('_save.json') or 'anchor' in name or '_chain_' in name
                        or 'owner_saves' in relative.parts or any('qualified' in p for p in relative.parts)):
                    add(path, relative, 'chain_save')
    # Literal JSON fixtures also cover names that do not follow the chain naming convention.
    for script in sorted((destination / 'tests').glob('*.gd')):
        for literal in re.findall(r'''["'](res://tmp/[^"'\n]+)["']''', script.read_text()):
            relative = literal.removeprefix('res://')
            if relative.endswith('.json'):
                pattern = re.sub(r'%[-+0-9.]*[sdif]', '*', relative)
            elif relative.endswith('_'):
                pattern = relative + '*.json'
            elif (source / relative).is_dir():
                pattern = relative.rstrip('/') + '/**/*.json'
            else:
                continue
            if '..' in Path(pattern).parts:
                raise ValueError(f'Unsafe fixture reference in {script}')
            for path in sorted(source.glob(pattern)):
                if path.is_file():
                    add(path, path.relative_to(source), 'chain_save')
    # Prefer immutable pinned anchors; only use a producer output if its expected digest matches.
    anchors = destination / 'docs/earned-regression-anchors.json'
    if anchors.is_file():
        for row in json.loads(anchors.read_text())['anchors']:
            candidate = source / row['anchor']
            if not candidate.is_file():
                candidate = source / row['source']
            if not candidate.is_file() or digest(candidate) != row['sha256']:
                raise ValueError(f'Missing or changed qualified anchor: {row["anchor"]} (producer {row["producer"]})')
            add(candidate, row['anchor'], 'pinned_anchor')
    if userdata is None:
        candidates = [source / USERDATA / user_relative(source),
                      source / 'tmp/userdata' / user_relative(source),
                      Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / user_relative(source)]
        userdata = next((p for p in candidates if (p / 'tests').is_dir()), None)
    elif not (userdata / 'tests').is_dir():
        raise ValueError('--userdata must name a Godot user directory containing tests/')
    if userdata is None:
        raise ValueError('Missing donor user://tests directory; supply --userdata <Godot-user-directory>')
    for path in files(userdata / 'tests'):
        add(path, USERDATA / user_relative(destination) / 'tests' / path.relative_to(userdata / 'tests'), 'user_tests')
    # An explicit immutable test pin takes precedence over a donor's mutable
    # producer output with the same tmp name. Existing destination saves still
    # receive the unchanged refusal below; no overwrite is authorized here.
    for path, relative in pinned_test_inputs(destination):
        records.pop(relative.as_posix(), None)
        add(path, relative, 'pinned_test_input')
    rows = [records[key] for key in sorted(records)]
    # All conflicts are checked before any input is installed. Existing earned saves are never overwritten.
    for row in rows:
        target = safe_destination(destination, Path(row['path']))
        if target.exists() and (not target.is_file() or digest(target) != row['sha256']):
            raise ValueError(f'Existing destination differs; preserved: {target}')
    return rows, str(userdata) if userdata else None


MEDIA_PIN = Path('tests/fixtures/generic_prop_media_manifest.json')
MEDIA_ROOT = Path('assets/lol2/generated/generic_props')


def required_selector_media(destination):
    """A source revision requiring selectors cannot silently run with the old props."""
    pin = destination / MEDIA_PIN
    if not pin.is_file():
        return []
    expected = json.loads(pin.read_text())
    actual = safe_destination(destination, MEDIA_ROOT / 'manifest.json')
    if not actual.is_file() or digest(actual) != digest(pin):
        raise ValueError('Required generic selector media is missing/changed; run tools/stage_worktree.sh for this revision')
    paths = [actual]
    for relative, row in expected['files'].items():
        path = safe_destination(destination, MEDIA_ROOT / relative)
        if not path.is_file() or digest(path) != row['sha256'] or path.stat().st_size != row['bytes']:
            raise ValueError(f'Required generic selector output missing/changed: {path}')
        paths.append(path)
    return paths


def ensure_selector_media(destination):
    if not (destination / MEDIA_PIN).is_file():
        return []
    if not (destination / MEDIA_ROOT / 'manifest.json').is_file():
        output = safe_destination(destination, MEDIA_ROOT)
        if output.exists():
            raise ValueError(f'Incomplete generic selector folder preserved: {output}')
        executable = Path(os.environ.get('LOL2_ORIGINAL_GAME_EXE', '~/lol2_runtime_root/LOLG.EXE')).expanduser()
        if not executable.is_file():
            raise ValueError('Missing selector media donor; set LOL2_ORIGINAL_GAME_EXE to your own LOLG.EXE for the existing producer')
        subprocess.run([sys.executable, str(destination / 'tools/prepare_generic_prop_media.py'),
                        '--game', str(executable.resolve().parent), '--output', str(output)], check=True)
    return required_selector_media(destination)


def stage(source, destination, userdata=None, dry_run=False):
    destination = destination.resolve()
    rows, source_user = plan(source, destination, userdata)
    manifest = {'format': 'lol2-worktree-stage-v1', 'source': str(source.resolve()),
                'destination': str(destination), 'source_userdata': source_user,
                'xdg_data_home': str(destination / USERDATA), 'files': rows}
    if dry_run:
        return manifest
    for row in rows:
        target = safe_destination(destination, Path(row['path']))
        if target.exists():
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        descriptor, name = tempfile.mkstemp(prefix='.stage-', dir=target.parent)
        os.close(descriptor)
        temporary = Path(name)
        try:
            shutil.copy2(row['source'], temporary)
            if digest(temporary) != row['sha256'] or digest(Path(row['source'])) != row['sha256']:
                raise ValueError(f'Donor changed while staging: {row["source"]}')
            temporary.replace(target)
        finally:
            temporary.unlink(missing_ok=True)
    # The qualified selector pack is required by this revision. A donor from
    # before G02 may omit it; chain the existing producer from the player's copy.
    known = {row['path'] for row in rows}
    for path in ensure_selector_media(destination):
        relative = path.relative_to(destination).as_posix()
        if relative not in known:
            rows.append({'source': str(path.resolve()), 'path': relative,
                         'category': 'generated_media', 'sha256': digest(path), 'bytes': path.stat().st_size})
    rows.sort(key=lambda row: row['path'])
    path = safe_destination(destination, MANIFEST)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(prefix='.manifest-', dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, 'w') as stream:
            json.dump(manifest, stream, indent=2)
            stream.write('\n')
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)
    return manifest


def staged_environment(root, environment):
    result = dict(environment)
    path = root / MANIFEST
    if path.is_file():
        saved = json.loads(path.read_text())
        expected = str(root.resolve() / USERDATA)
        if saved.get('format') != 'lol2-worktree-stage-v1' or saved.get('destination') != str(root.resolve()) or saved.get('xdg_data_home') != expected:
            raise ValueError(f'Wrong or invalid worktree stage manifest: {path}')
        result['XDG_DATA_HOME'] = expected
    return result


def check(destination):
    required_selector_media(destination)
    staged_environment(destination, {})
    manifest = json.loads((destination / MANIFEST).read_text())
    for row in manifest['files']:
        path = safe_destination(destination, Path(row['path']))
        if not path.is_file() or digest(path) != row['sha256']:
            raise ValueError(f'Staged input missing or changed: {path}')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--from', dest='source', type=Path, default=ROOT, help='Prepared donor; default: this tool\'s project')
    parser.add_argument('--userdata', type=Path, help='Donor Godot user directory; only tests/ is copied')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--check', action='store_true', help='Verify the existing staged manifest and every input digest')
    args = parser.parse_args()
    try:
        manifest = check(args.destination.resolve()) if args.check else stage(args.source, args.destination, args.userdata, args.dry_run)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Staging failed: {error}\n')
    counts = {}
    for row in manifest['files']:
        counts[row['category']] = counts.get(row['category'], 0) + 1
    print(('PLAN' if args.dry_run else 'PASS') + f' worktree inputs: {counts}')
    print(f'Manifest: {args.destination.resolve() / MANIFEST}')
    print('Regression runner uses the staged private user://tests directory automatically.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
