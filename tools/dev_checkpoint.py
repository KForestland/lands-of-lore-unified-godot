#!/usr/bin/env python3
"""Named development checkpoints (docs/dev-checkpoints.md).

Places one catalogued, sha256-pinned earned save at its area's production resume path inside a FRESH, isolated
userdata, then starts the production original-game gate, where "Resume <area>" loads it through the normal path.
No game code, no state editing. Works only on a disposable project copy that this tool prepared and owns: main,
candidates and owner playtests are never written, not even transiently.

  dev_checkpoint.py list
  dev_checkpoint.py prepare --from SOURCE_PROJECT --to NEW_COPY
  dev_checkpoint.py run NAME --project COPY [--prepare-from SOURCE_PROJECT] [--dry-run] [--script res://tests/x.gd]
                    [--display :N] [--timeout S]

Flatpak Godot ignores XDG_DATA_HOME, so isolation uses the copy's override.cfg
(application/config/use_custom_user_dir + a unique custom_user_dir_name). override.cfg is restored byte-exact
(or removed again if it did not exist) only after every owned Godot process has exited.
"""
import argparse
import datetime
import fcntl
import hashlib
import json
import os
import re
import secrets
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

CATALOG = Path(__file__).resolve().with_name('dev_checkpoints.json')
FLATPAK_DATA = Path.home() / '.var/app/org.godotengine.Godot/data'
# --die-with-parent: the sandboxed Godot dies with the launcher instead of being orphaned.
GODOT = ['flatpak', 'run', '--die-with-parent', 'org.godotengine.Godot']
GATE = 'res://scenes/lol2/original_game_gate.tscn'
ORIGINAL_EXE = '~/lol2_runtime_root/LOLG.EXE'
MARKER = '; dev_checkpoint.py isolated userdata'
OWNER_FILE = '.dev_checkpoint_owner.json'
LOCK_FILE = '.dev_checkpoint.lock'
# Not copied into a disposable copy: VCS, scratch output and caches that the game does not read.
PREPARE_IGNORE = ('.git', 'tmp', '.pytest_cache', OWNER_FILE, LOCK_FILE)
NAME_RE = re.compile(r'^[a-z0-9][a-z0-9-]{0,62}$')
STAMP_RE = re.compile(r'^[0-9]{8}T[0-9]{6}Z$')
SHA_RE = re.compile(r'^[0-9a-f]{64}$')
# The gate's production resume paths (DEFAULT_PATH of each area's save owner).
RESUME_PATHS = {
    'Museum': 'user://saves/museum_quicksave.json',
    'Jungle': 'user://saves/jungle_quicksave.json',
    'Hive': 'user://saves/hive_quicksave.json',
    'Darker Jungle': 'user://saves/darker_jungle_quicksave.json',
}


class Refused(Exception):
    pass


class OwnedProcessAlive(Exception):
    """Owned game processes survived termination; the isolation config must stay in place."""

    def __init__(self, survivors, code):
        super().__init__(f'owned processes still alive: {sorted(survivors)}')
        self.survivors = survivors
        self.code = code


def load_catalog(path=CATALOG):
    data = json.loads(Path(path).read_text())
    if data.get('schema') != 1 or not isinstance(data.get('checkpoints'), dict):
        raise Refused(f'{path}: unsupported catalog')
    for name, entry in data['checkpoints'].items():
        validate_entry(name, entry)
    return data['checkpoints']


def validate_entry(name, entry):
    if not NAME_RE.match(name):
        raise Refused(f'unsafe checkpoint name {name!r}')
    area = entry.get('area')
    if area not in RESUME_PATHS:
        raise Refused(f'{name}: unknown area {area!r}')
    if entry.get('resume_path') != RESUME_PATHS[area]:
        raise Refused(f'{name}: resume_path {entry.get("resume_path")!r} is not the {area} production path {RESUME_PATHS[area]}')
    if not SHA_RE.match(str(entry.get('sha256', ''))):
        raise Refused(f'{name}: sha256 is not 64 lowercase hex digits')
    if not Path(str(entry.get('source', ''))).is_absolute():
        raise Refused(f'{name}: source must be an absolute archive path')


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def source_status(entry):
    source = Path(entry['source'])
    if not source.is_file():
        return 'missing'
    return 'ok' if digest(source) == entry['sha256'] else 'bad-hash'


def user_path(root, resource):
    """user://saves/<file>.json under root only: no absolute, traversing or nested components."""
    if not isinstance(resource, str) or not resource.startswith('user://'):
        raise Refused(f'not a user:// path: {resource!r}')
    rel = resource[len('user://'):]
    parts = rel.split('/')
    if rel.startswith('/') or '\\' in rel or len(parts) != 2 or parts[0] != 'saves' \
            or not re.match(r'^[A-Za-z0-9_][A-Za-z0-9_.-]*\.json$', parts[1]) or '..' in parts[1]:
        raise Refused(f'unsafe resume path {resource!r}; expected user://saves/<file>.json')
    path = Path(root) / rel
    if not path.resolve().is_relative_to(Path(root).resolve()):
        raise Refused(f'{resource!r} resolves outside the checkpoint userdata')
    return path


# ---- project ownership -------------------------------------------------------------------------------------------

def _read_nofollow(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as f:
        return f.read()


def _write_nofollow(path, data, mode=None):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o664)
    with os.fdopen(fd, 'wb') as f:
        if mode is not None:
            os.fchmod(f.fileno(), mode)
        f.write(data)


def prepare(source, dest, out=print, dry_run=False):
    """Create a NEW disposable copy of a Godot project and mark it as owned by this tool."""
    source, dest = Path(source).resolve(), Path(os.path.abspath(dest))
    if not (source / 'project.godot').is_file():
        raise Refused(f'{source}: not a Godot project')
    if os.path.lexists(dest):
        raise Refused(f'{dest}: already exists; prepare always creates a new copy')
    if dest.parent.resolve() != dest.parent or Path(dest.parent).is_symlink():
        raise Refused(f'{dest.parent}: parent must be a real directory path (no symlinks)')
    if dest.is_relative_to(source):
        raise Refused(f'{dest}: inside the source project')
    out(f'prepare: copy {source} -> {dest} (without {", ".join(PREPARE_IGNORE)})')
    if dry_run:
        return dest
    shutil.copytree(source, dest, symlinks=True, ignore=shutil.ignore_patterns(*PREPARE_IGNORE))
    owner = {'tool': 'dev_checkpoint.py', 'schema': 1, 'project': str(dest), 'source': str(source),
             'created_utc': datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ'),
             'token': secrets.token_hex(16)}
    _write_nofollow(dest / OWNER_FILE, (json.dumps(owner, indent=2) + '\n').encode())
    out(f'prepare: owned disposable copy {dest}')
    return dest


def check_owned(project):
    """Refuse anything that is not a disposable copy prepared by this tool at exactly this path."""
    given = Path(os.path.abspath(project))
    if given.is_symlink() or given.resolve() != given:
        raise Refused(f'{given}: project path must not be or contain a symlink')
    if not (given / 'project.godot').is_file():
        raise Refused(f'{given}: not a Godot project')
    if (given / '.git').exists():
        raise Refused(f'{given}: has .git; use a disposable copy (prepare), never the shared checkout')
    marker = given / OWNER_FILE
    if not marker.is_file() or marker.is_symlink():
        raise Refused(f'{given}: no {OWNER_FILE}; only copies made by `dev_checkpoint.py prepare` are used '
                      '(candidates, main and playtests are never modified)')
    try:
        owner = json.loads(_read_nofollow(marker))
    except (OSError, ValueError) as error:
        raise Refused(f'{marker}: unreadable ({error})')
    if owner.get('tool') != 'dev_checkpoint.py' or owner.get('project') != str(given):
        raise Refused(f'{marker}: owned copy was made for {owner.get("project")!r}, not {str(given)!r}')
    return given


def project_processes(project, proc_root='/proc'):
    """(pid, starttime) of live processes whose command line names this exact project (`--path <project>`)."""
    found = set()
    target = str(project)
    for entry in os.listdir(proc_root):
        if not entry.isdigit():
            continue
        try:
            args = Path(proc_root, entry, 'cmdline').read_bytes().split(b'\0')
        except OSError:
            continue
        args = [a.decode(errors='replace') for a in args]
        if any(a == '--path' and i + 1 < len(args) and args[i + 1] == target for i, a in enumerate(args)):
            ident = _ident(int(entry), proc_root)
            if ident:
                found.add(ident)
    return found


def _ident(pid, proc_root='/proc'):
    try:
        stat = Path(proc_root, str(pid), 'stat').read_text()
    except OSError:
        return None
    fields = stat[stat.rindex(')') + 2:].split()
    if fields[0] == 'Z':
        return None
    return (pid, int(fields[19]))


def _alive(ident):
    return _ident(ident[0]) == ident


def descendants(pid, proc_root='/proc'):
    children = {}
    for entry in os.listdir(proc_root):
        if entry.isdigit():
            try:
                stat = Path(proc_root, entry, 'stat').read_text()
            except OSError:
                continue
            ppid = int(stat[stat.rindex(')') + 2:].split()[1])
            children.setdefault(ppid, []).append(int(entry))
    result, stack = set(), [pid]
    while stack:
        for child in children.get(stack.pop(), []):
            ident = _ident(child, proc_root)
            if ident and ident not in result:
                result.add(ident)
                stack.append(child)
    return result


# ---- override.cfg -------------------------------------------------------------------------------------------------

def read_override(project):
    """Exact state of <project>/override.cfg: refuses symlinks and non-regular files."""
    path = project / 'override.cfg'
    if path.is_symlink():
        raise Refused(f'{path}: is a symlink; refusing (it could redirect writes outside the copy)')
    if not os.path.lexists(path):
        return {'path': path, 'existed': False, 'bytes': b'', 'mode': None, 'sha256': None}
    if not path.is_file():
        raise Refused(f'{path}: not a regular file')
    if path.resolve().parent != project:
        raise Refused(f'{path}: resolves outside the project copy')
    data = _read_nofollow(path)
    return {'path': path, 'existed': True, 'bytes': data, 'mode': path.stat().st_mode & 0o7777,
            'sha256': hashlib.sha256(data).hexdigest()}


def restore_override(state):
    path = state['path']
    if state['existed']:
        _write_nofollow(path, state['bytes'], state['mode'])
        if path.is_symlink() or _read_nofollow(path) != state['bytes']:
            raise Refused(f'{path}: restore did not reproduce the original bytes')
    else:
        if path.is_symlink() or path.exists():
            os.unlink(path)
        if os.path.lexists(path):
            raise Refused(f'{path}: could not remove the run override')


# ---- launching ----------------------------------------------------------------------------------------------------

class OwnedLauncher:
    """Runs Godot bounded by `timeout`, tracks every process it owns (descendants and processes on this exact
    project), and on exit/timeout/error terminates only those. Raises OwnedProcessAlive if any survives."""

    def __init__(self, project, timeout=None, grace=10.0, poll=0.25):
        self.project, self.timeout, self.grace, self.poll = project, timeout, grace, poll

    def __call__(self, command, env=None):
        proc = subprocess.Popen(command, env=env, start_new_session=True)
        owned, start, code = set(), time.monotonic(), None
        try:
            while code is None:
                owned |= descendants(proc.pid) | project_processes(self.project)
                try:
                    code = proc.wait(timeout=self.poll)
                except subprocess.TimeoutExpired:
                    if self.timeout is not None and time.monotonic() - start >= self.timeout:
                        code = 124
        finally:
            survivors = self.stop(proc, owned)
            if survivors:
                raise OwnedProcessAlive(survivors, code)
        return code

    def stop(self, proc, owned):
        owned = owned | descendants(proc.pid) | project_processes(self.project)
        for sig, wait in ((signal.SIGTERM, self.grace), (signal.SIGKILL, 5.0)):
            if proc.poll() is not None and not any(_alive(i) for i in owned):
                break
            if proc.poll() is None:  # leader not reaped, so its group id cannot have been reused
                try:
                    os.killpg(proc.pid, sig)
                except (ProcessLookupError, PermissionError):
                    pass
            for ident in owned:
                if _alive(ident):
                    try:
                        os.kill(ident[0], sig)
                    except (ProcessLookupError, PermissionError):
                        pass
            deadline = time.monotonic() + wait
            while time.monotonic() < deadline:
                if proc.poll() is not None and not any(_alive(i) for i in owned):
                    break
                time.sleep(0.05)
        survivors = {i for i in owned | project_processes(self.project) if _alive(i)}
        if proc.poll() is None:
            survivors.add((proc.pid, -1))
        return survivors


class ProjectLock:
    def __init__(self, project):
        self.path = project / LOCK_FILE

    def __enter__(self):
        if self.path.is_symlink():
            raise Refused(f'{self.path}: is a symlink')
        self.fd = os.open(self.path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o664)
        try:
            fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            os.close(self.fd)
            raise Refused(f'{self.path}: another checkpoint run holds this project copy')
        return self

    def __exit__(self, *exc):
        fcntl.flock(self.fd, fcntl.LOCK_UN)
        os.close(self.fd)


def plan(name, entry, project, data_root, stamp):
    if not NAME_RE.match(name):
        raise Refused(f'unsafe checkpoint name {name!r}')
    if not STAMP_RE.match(stamp):
        raise Refused(f'unsafe stamp {stamp!r}; expected YYYYMMDDTHHMMSSZ')
    validate_entry(name, entry)
    project = check_owned(project)
    override = read_override(project)
    try:
        text = override['bytes'].decode('utf-8')
    except UnicodeDecodeError:
        raise Refused(f'{override["path"]}: not UTF-8')
    if MARKER in text:
        raise Refused(f'{override["path"]}: a previous run did not restore it; restore it before running again')
    if '[application]' in text:
        raise Refused(f'{override["path"]}: already has an [application] section; refusing to merge')
    status = source_status(entry)
    if status != 'ok':
        raise Refused(f'{name}: source {status}: {entry["source"]}')
    userdir = f'lol2-checkpoint-{name}-{stamp}'
    data_root = Path(data_root).resolve()
    root = data_root / userdir
    if root.resolve().parent != data_root:
        raise Refused(f'{root}: userdata escapes {data_root}')
    if os.path.lexists(root):
        raise Refused(f'{root}: userdata already exists; checkpoints always start fresh')
    return {'project': project, 'override': override, 'userdir': userdir, 'root': root,
            'save': user_path(root, entry['resume_path'])}


def run(name, project, dry_run=False, script=None, display=None, data_root=FLATPAK_DATA, catalog=CATALOG,
        exe=ORIGINAL_EXE, launcher=None, stamp=None, out=print, timeout=None, prepare_from=None):
    entries = load_catalog(catalog)
    if name not in entries:
        raise Refused(f'unknown checkpoint {name!r}; known: {", ".join(sorted(entries))}')
    entry = entries[name]
    if prepare_from:
        prepare(prepare_from, project, out=out, dry_run=dry_run)
        if dry_run:
            out('  dry run: copy not made, so the run plan below is not validated against it')
            return 0
    stamp = stamp or datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    p = plan(name, entry, project, data_root, stamp)
    launcher = launcher or OwnedLauncher(p['project'], timeout)
    original = p['override']['bytes']
    sep = b'' if not original or original.endswith(b'\n') else b'\n'
    override_new = original + sep + (f'{MARKER}\n[application]\nconfig/use_custom_user_dir=true\n'
                                      f'config/custom_user_dir_name="{p["userdir"]}"\n').encode()
    command = GODOT + ['--path', str(p['project'])]
    command += ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility']
    command += ['--script', script] if script else [GATE]
    command += ['--', '--dev-diagnostics', f'--original-game-exe={exe}', f'--checkpoint={name}']
    receipt = {'checkpoint': name, 'area': entry['area'], 'scene': entry['scene'], 'gate_button': entry['gate_button'],
               'resume_path': entry['resume_path'], 'source': entry['source'], 'sha256': entry['sha256'],
               'provenance': entry['provenance'], 'supplied': entry['supplied'], 'userdata': str(p['root']),
               'project': str(p['project']), 'override_existed': p['override']['existed'],
               'override_sha256': p['override']['sha256'], 'created_utc': stamp}
    out(f'checkpoint {name}: {entry["area"]}, {entry["provenance"]["kind"]} ({entry["provenance"]["campaign"]}, leg {entry["provenance"]["leg"]})')
    out(f'  source ok: {entry["source"]} sha256 {entry["sha256"]}')
    out(f'  owned copy: {p["project"]}')
    out(f'  fresh userdata: {p["root"]}')
    out(f'  copy save to: {p["save"]}')
    out(f'  override.cfg: add use_custom_user_dir ({p["override"]["path"]}, '
        f'{"sha256 " + p["override"]["sha256"] if p["override"]["existed"] else "absent"}); restored byte-exact after the run')
    out(f'  launch: {" ".join(command)}' + (f' (DISPLAY={display})' if display else ''))
    if dry_run:
        out('  dry run: nothing written, nothing launched')
        return 0
    with ProjectLock(p['project']):
        if project_processes(p['project']):
            raise Refused(f'{p["project"]}: a process is already running on this project copy')
        p['save'].parent.mkdir(parents=True, exist_ok=False)
        shutil.copyfile(entry['source'], p['save'])
        if digest(p['save']) != entry['sha256']:
            raise Refused(f'{p["save"]}: copy hash differs')
        (p['root'] / 'checkpoint.json').write_text(json.dumps(receipt, indent=2) + '\n')
        _write_nofollow(p['override']['path'], override_new)
        try:
            env = dict(os.environ)
            if display:
                env['DISPLAY'] = display
            code = launcher(command, env=env)
        except OwnedProcessAlive as alive:
            # Never restore the isolation config while our game may still write user://.
            raise Refused(f'{alive}; override.cfg left with the isolation marker; stop them, then restore '
                          f'{p["override"]["path"]} (original sha256 {p["override"]["sha256"]})')
        except BaseException:
            restore_override(p['override'])
            raise
        restore_override(p['override'])
    if digest(entry['source']) != entry['sha256']:
        raise Refused(f'{entry["source"]}: source changed during the run')
    out(f'  exit {code}; override.cfg restored byte-exact; source unchanged')
    return code


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('list')
    pr = sub.add_parser('prepare')
    pr.add_argument('--from', dest='source', required=True)
    pr.add_argument('--to', dest='dest', required=True)
    pr.add_argument('--dry-run', action='store_true')
    r = sub.add_parser('run')
    r.add_argument('name')
    r.add_argument('--project', required=True)
    r.add_argument('--prepare-from', help='first make --project as a new owned copy of this project')
    r.add_argument('--dry-run', action='store_true')
    r.add_argument('--script')
    r.add_argument('--display')
    r.add_argument('--timeout', type=float, help='stop owned Godot processes after S seconds (exit 124)')
    args = parser.parse_args(argv)
    try:
        if args.command == 'list':
            for name, entry in sorted(load_catalog().items()):
                print(f'{name}\t{entry["area"]}\t{entry["provenance"]["kind"]}\t{source_status(entry)}\t{entry["source"]}')
            return 0
        if args.command == 'prepare':
            prepare(args.source, args.dest, dry_run=args.dry_run)
            return 0
        return run(args.name, args.project, args.dry_run, args.script, args.display, timeout=args.timeout,
                   prepare_from=args.prepare_from)
    except Refused as error:
        print(f'REFUSED: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
