"""Development exports using the established staging tools; no release certification."""
import hashlib
import os
from pathlib import Path
import signal
import subprocess
import sys

from regression_source import snapshot, changes
from verify_demo_stage import inputs, verify, TEMPLATES, PACKAGE_DOCS

TOOLS = ('verify_project.py', 'verification_build.py', 'prepare_standalone_demo.py',
         'verify_demo_stage.py')


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def build_inputs(root, templates):
    """Pin media, templates and orchestration in addition to regression source."""
    result = snapshot(root)
    result.update({name: digest(path) for name, path in inputs(root).items()})
    result.update({f'tools/{name}': digest(root / 'tools' / name) for name in TOOLS})
    result.update({f'templates/{name}': digest(templates / name) for name in TEMPLATES})
    result.update({name: digest(root / name) for name in PACKAGE_DOCS.values()})
    return result


def logged(command, log, timeout):
    """Keep complete output and reap the owned process group on timeout/interruption."""
    with log.open('x') as stream:
        process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt):
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            raise
    errors = [line for line in log.read_text(errors='replace').splitlines()
              if line.lstrip().startswith(('ERROR:', 'SCRIPT ERROR:'))]
    if code != 0 or errors:
        raise ValueError(f'{log.name}: exit {code}; engine errors {errors[:5]}')


def build(root, folder, templates, before, timeout, save_progress):
    """Called only after successful regressions; fresh candidate output only."""
    if changes(before, build_inputs(root, templates)):
        raise ValueError('Build inputs changed during regressions')
    output = folder / 'build'
    output.mkdir(exist_ok=False)
    logs = folder / 'build_logs'
    logs.mkdir(exist_ok=False)
    steps = []

    def step(name, command):
        row = {'name': name, 'status': 'running', 'log': f'build_logs/{name}.log',
               'command': command}
        steps.append(row)
        save_progress(steps)
        try:
            logged(command, folder / row['log'], timeout)
        except BaseException:
            row['status'] = 'failed'
            save_progress(steps)
            raise
        row['status'] = 'passed'
        save_progress(steps)

    for tool, name in [('prepare_standalone_demo.py', 'stage'), ('verify_demo_stage.py', 'stage_verify')]:
        step(name, [sys.executable, str(root / 'tools' / tool), '--output', str(output),
                    '--templates', str(templates)])
    # Re-read the staged inputs before export. Do not trust a child's exit code alone.
    initial = verify(root, output, templates)
    if changes(before, build_inputs(root, templates)):
        raise ValueError('Build inputs changed during staging')
    artifacts = {}
    for platform, ext in [('Linux', 'x86_64'), ('Windows', 'exe')]:
        target = output / platform / f'LoL2-Cavern.{ext}'
        step(platform.lower(), ['flatpak', 'run', 'org.godotengine.Godot', '--headless',
                                '--path', str(output / 'project'), '--export-release',
                                platform, str(target)])
        for path in (target, target.with_suffix('.pck')):
            if not path.is_file() or not path.stat().st_size:
                raise ValueError(f'Missing or empty export: {path}')
            artifacts[path.relative_to(output).as_posix()] = digest(path)
    if artifacts['Linux/LoL2-Cavern.pck'] != artifacts['Windows/LoL2-Cavern.pck']:
        raise ValueError('Linux and Windows packs differ')
    final = verify(root, output, templates)
    for key in ('source', 'assets', 'templates', 'staged_inputs', 'project_sha256', 'export_presets_sha256', 'package_docs'):
        if initial[key] != final[key]:
            raise ValueError(f'Staged inputs changed during export: {key}')
    if changes(before, build_inputs(root, templates)):
        raise ValueError('Build inputs changed during export')
    (output / 'SHA256SUMS').write_text(''.join(f'{value}  {name}\n' for name, value in artifacts.items()))
    return {'passed': True, 'steps': steps, 'artifacts': artifacts,
            'input_manifest': 'build/source_asset_manifest.json',
            'scope': 'Selected regressions, verified staged inputs and Linux/Windows exports only. '
                     'Not packed-asset audit, packaged runtime, earned campaign, native Windows execution '
                     'or release/content/owner acceptance.'}
