#!/usr/bin/env python3
"""Verify an export staging tree against its source and record immutable input hashes.

Requires locally prepared assets. This checks build inputs, not asset extraction,
gameplay, engine compatibility or byte-reproducible exports.
"""
import argparse
import configparser
import datetime
import hashlib
import json
from pathlib import Path


KEEP = '[remap]\n\nimporter="keep"\n'
TEMPLATES = ('linux_release.x86_64', 'windows_release_x86_64.exe')


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def inputs(root):
    return {p.relative_to(root).as_posix(): p
            for folder in ('scripts', 'scenes', 'assets')
            for p in (root / folder).rglob('*')
            if p.is_file() and p.suffix not in ('.import', '.uid')}


def verify(source, output, templates):
    source, output, templates = source.resolve(), output.resolve(), templates.resolve()
    stage = output / 'project'
    for folder in ('scripts', 'scenes', 'assets'):
        if not (source / folder).is_dir() or not (stage / folder).is_dir():
            raise ValueError(f'Missing source or staged {folder}/ directory')
    expected, actual = inputs(source), inputs(stage)
    missing, extra = sorted(expected.keys() - actual.keys()), sorted(actual.keys() - expected.keys())
    if missing or extra:
        raise ValueError(f'Staged file set differs: missing={missing[:10]}, extra={extra[:10]}')
    hashed, changed = {}, []
    for name, path in sorted(expected.items()):
        hashed[name] = digest(path)
        if digest(actual[name]) != hashed[name]:
            changed.append(name)
        if name.startswith('assets/') and path.suffix in ('.png', '.wav'):
            keep = actual[name].with_name(actual[name].name + '.import')
            if not keep.is_file() or keep.read_text() != KEEP:
                raise ValueError(f'Raw PNG/WAV keep-import rule missing or changed: {name}')
    if changed:
        raise ValueError(f'Staged content differs: {changed[:10]}')
    project = (source / 'project.godot').read_text()
    expected_project = project.replace('res://scenes/lol2/setup.tscn',
                                      'res://scenes/lol2/original_game_gate.tscn').replace(
                                          'Lands of Lore Unified Godot', 'LoL2 Cavern Walkthrough')
    if (stage / 'project.godot').read_text() != expected_project:
        raise ValueError('Staged project differs from prepare_standalone_demo.py transformation')
    if 'run/main_scene="res://scenes/lol2/original_game_gate.tscn"' not in expected_project:
        raise ValueError('Staged project does not start through the original-game gate')
    presets = configparser.ConfigParser(interpolation=None)
    presets.read(stage / 'export_presets.cfg')
    template_hashes = {}
    for index, name in enumerate(TEMPLATES):
        path = templates / name
        required = {'custom_features': '"original_game_required"',
                    'export_filter': '"all_resources"', 'exclude_filter': '""',
                    'include_filter': '"assets/*.json,assets/*.png,assets/*.wav,assets/*.ogv,assets/*.bin,scripts/lol2/*.json"'}
        for key, value in required.items():
            if presets.get(f'preset.{index}', key, fallback=None) != value:
                raise ValueError(f'Export preset {index} has an unexpected {key}')
        configured = presets.get(f'preset.{index}.options', 'custom_template/release', fallback='')
        if configured != json.dumps(str(path)):
            raise ValueError(f'Export preset {index} does not use the supplied template: {name}')
        template_hashes[name] = digest(path)
    # Tests and the runners are provenance only: they are not exported into the game.
    provenance = {**{k: v for k, v in hashed.items() if not k.startswith('assets/')},
                  'project.godot': digest(source / 'project.godot')}
    for path in (source / 'tests').rglob('*'):
        if path.is_file() and path.suffix in ('.gd', '.json', '.tscn', '.tres', '.gdshader', '.gdshaderinc'):
            provenance[path.relative_to(source).as_posix()] = digest(path)
    for name in ('prepare_standalone_demo.py', 'run_regressions.py',
                 'run_isolated_regressions.py', 'regression_source.py', 'run_act1_fresh_chain.py'):
        path = source / 'tools' / name
        if path.is_file():
            provenance[path.relative_to(source).as_posix()] = digest(path)
    return {
        'format': 'lol2-demo-inputs-v1',
        'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'source_root': str(source), 'output_root': str(output), 'template_root': str(templates),
        'source': dict(sorted(provenance.items())), 'templates': template_hashes,
        'assets': {k: v for k, v in hashed.items() if k.startswith('assets/')},
        'staged_inputs': hashed,
        'project_sha256': digest(stage / 'project.godot'),
        'export_presets_sha256': digest(stage / 'export_presets.cfg'),
        'verifier_sha256': digest(Path(__file__)),
        'scope': 'Staged inputs match local source, generated assets and selected templates. '
                 'Not asset extraction, gameplay, engine-version compatibility or byte-reproducible export proof.',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--templates', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, help='Default: <output>/source_asset_manifest.json; must not exist')
    args = parser.parse_args()
    target = args.manifest or args.output / 'source_asset_manifest.json'
    try:
        if target.exists():
            raise ValueError(f'Refusing to replace existing manifest: {target}')
        report = verify(args.source, args.output, args.templates)
        with target.open('x') as stream:
            json.dump(report, stream, indent=2)
            stream.write('\n')
    except (OSError, ValueError, configparser.Error) as error:
        parser.exit(1, f'Input verification failed: {error}\n')
    print(f'PASS {len(report["staged_inputs"])} staged inputs, '
          f'{len(report["assets"])} assets and {len(report["templates"])} templates: {target}')


if __name__ == '__main__':
    main()
