#!/usr/bin/env python3
"""Unit tests for tools/dev_checkpoint.py (temporary directories only; never touches real userdata or saves).

Real child processes (`sh`, `sleep`) are used for the timeout/ownership tests; they are only ever this test's own."""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dev_checkpoint as dc  # noqa: E402

SAVE = b'{"format":"lol2-restoration-jungle","version":1}'
STAMP = '20261013T120000Z'
ROOT = f'lol2-checkpoint-jungle-from-museum-{STAMP}'


def tree(path):
    """Every path under `path` with its bytes (files) or link target (symlinks)."""
    result = {}
    for p in sorted(Path(path).rglob('*')):
        if p.is_symlink():
            result[str(p)] = ('link', os.readlink(p))
        elif p.is_file():
            result[str(p)] = ('file', p.read_bytes(), p.stat().st_mode)
        else:
            result[str(p)] = ('dir',)
    return result


class CheckpointTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name).resolve()
        self.source = self.base / 'archive/save.json'
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes(SAVE)
        self.main = self.base / 'main'
        (self.main / '.git').mkdir(parents=True)
        (self.main / 'tmp').mkdir()
        (self.main / 'tmp/big.bin').write_bytes(b'x')
        (self.main / 'project.godot').write_text('config_version=5\n')
        (self.main / 'override.cfg').write_text('[display]\nwindow/energy_saving/keep_screen_on=false\n')
        self.project = dc.prepare(self.main, self.base / 'copy', out=lambda *_: None)
        self.data = self.base / 'data'
        self.data.mkdir()
        self.catalog = self.base / 'catalog.json'
        self.write_catalog(hashlib.sha256(SAVE).hexdigest())
        self.calls = []
        self.spawned = []

    def tearDown(self):
        for proc in self.spawned:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
        self.tmp.cleanup()

    def write_catalog(self, sha, name='jungle-from-museum', **changes):
        entry = {'area': 'Jungle', 'format': 'lol2-restoration-jungle', 'scene': 'res://scenes/lol2/jungle_walkthrough.tscn',
                 'resume_path': 'user://saves/jungle_quicksave.json', 'gate_button': 'Resume jungle', 'source': str(self.source),
                 'sha256': sha, 'provenance': {'kind': 'earned', 'campaign': 'test', 'leg': 2}, 'supplied': []}
        entry.update(changes)
        self.catalog.write_text(json.dumps({'schema': 1, 'checkpoints': {name: entry}}))

    def launcher(self, command, env=None):
        # During the launch: override.cfg points at the fresh userdata and the save is in place.
        override = (self.project / 'override.cfg').read_bytes()
        self.calls.append({'command': command, 'override': override.decode()})
        return 0

    def run_checkpoint(self, name='jungle-from-museum', project=None, **kw):
        kw.setdefault('launcher', self.launcher)
        kw.setdefault('stamp', STAMP)
        return dc.run(name, project or self.project, data_root=self.data, catalog=self.catalog, out=lambda *_: None, **kw)

    def assert_no_userdata(self):
        self.assertEqual(list(self.data.iterdir()), [])

    # ---- normal path ----

    def test_run_places_verified_save_in_fresh_userdata_and_restores_override(self):
        before = (self.project / 'override.cfg').read_bytes()
        self.assertEqual(self.run_checkpoint(), 0)
        root = self.data / ROOT
        self.assertEqual((root / 'saves/jungle_quicksave.json').read_bytes(), SAVE)
        receipt = json.loads((root / 'checkpoint.json').read_text())
        self.assertEqual(receipt['provenance']['kind'], 'earned')
        self.assertEqual(receipt['override_sha256'], hashlib.sha256(before).hexdigest())
        self.assertEqual(len(self.calls), 1)
        self.assertIn(f'config/custom_user_dir_name="{ROOT}"', self.calls[0]['override'])
        self.assertIn('[display]', self.calls[0]['override'])
        self.assertIn(dc.GATE, self.calls[0]['command'])
        self.assertIn('--die-with-parent', self.calls[0]['command'])
        self.assertIn('--dev-diagnostics', self.calls[0]['command'])
        self.assertEqual((self.project / 'override.cfg').read_bytes(), before)
        self.assertEqual(self.source.read_bytes(), SAVE)

    def test_override_removed_when_it_did_not_exist(self):
        (self.project / 'override.cfg').unlink()
        self.run_checkpoint()
        self.assertTrue(self.calls)
        self.assertFalse(os.path.lexists(self.project / 'override.cfg'))

    def test_dry_run_writes_and_launches_nothing(self):
        before = tree(self.project)
        self.assertEqual(self.run_checkpoint(dry_run=True), 0)
        self.assertEqual(self.calls, [])
        self.assert_no_userdata()
        self.assertEqual(tree(self.project), before)

    # ---- lead control 1: empty / CRLF override.cfg must come back byte-exact ----

    def test_empty_override_is_kept_as_an_empty_file(self):
        (self.project / 'override.cfg').write_bytes(b'')
        self.run_checkpoint()
        self.assertIn('[application]', self.calls[0]['override'])
        self.assertTrue((self.project / 'override.cfg').is_file())
        self.assertEqual((self.project / 'override.cfg').read_bytes(), b'')

    def test_crlf_override_and_mode_restored_byte_exact(self):
        data = b'[display]\r\nwindow/energy_saving/keep_screen_on=false\r\n; no trailing newline'
        (self.project / 'override.cfg').write_bytes(data)
        os.chmod(self.project / 'override.cfg', 0o640)
        self.run_checkpoint()
        self.assertIn('; no trailing newline\n; dev_checkpoint.py', self.calls[0]['override'])
        self.assertEqual((self.project / 'override.cfg').read_bytes(), data)
        self.assertEqual((self.project / 'override.cfg').stat().st_mode & 0o7777, 0o640)

    # ---- lead control 2: symlink configs / symlinked project ----

    def test_refuses_symlink_override_and_leaves_target_untouched(self):
        outside = self.base / 'outside.cfg'
        outside.write_bytes(b'[display]\n')
        (self.project / 'override.cfg').unlink()
        (self.project / 'override.cfg').symlink_to(outside)
        before = tree(self.project)
        with self.assertRaisesRegex(dc.Refused, 'symlink'):
            self.run_checkpoint()
        self.assertEqual(outside.read_bytes(), b'[display]\n')
        self.assertEqual(tree(self.project), before)
        self.assertEqual(self.calls, [])
        self.assert_no_userdata()

    def test_refuses_dangling_symlink_override(self):
        (self.project / 'override.cfg').unlink()
        (self.project / 'override.cfg').symlink_to(self.base / 'would-be-created.cfg')
        with self.assertRaisesRegex(dc.Refused, 'symlink'):
            self.run_checkpoint()
        self.assertFalse(os.path.lexists(self.base / 'would-be-created.cfg'))

    def test_refuses_symlinked_project_path(self):
        link = self.base / 'link-to-copy'
        link.symlink_to(self.project)
        with self.assertRaisesRegex(dc.Refused, 'symlink'):
            self.run_checkpoint(project=link)
        self.assertEqual(self.calls, [])

    # ---- lead control 3: resume path / name / stamp ----

    def test_refuses_absolute_and_traversing_resume_paths(self):
        for bad in ('user:///tmp/checkpoint-outside.json', 'user://saves/../../outside.json', 'user://../x.json',
                    'user://saves/sub/x.json', 'user://saves/x.txt', '/tmp/x.json', 'user://saves/..json'):
            with self.subTest(bad=bad):
                with self.assertRaises(dc.Refused):
                    dc.user_path(self.data / 'root', bad)
                self.write_catalog(hashlib.sha256(SAVE).hexdigest(), resume_path=bad)
                with self.assertRaises(dc.Refused):
                    self.run_checkpoint()
                self.assert_no_userdata()
        self.assertEqual(self.calls, [])

    def test_refuses_resume_path_other_than_the_area_production_path(self):
        self.write_catalog(hashlib.sha256(SAVE).hexdigest(), resume_path='user://saves/hive_quicksave.json')
        with self.assertRaisesRegex(dc.Refused, 'production path'):
            self.run_checkpoint()

    def test_refuses_unsafe_name_and_stamp(self):
        for name in ('../escape', 'a/b', 'x"y', 'UPPER', ''):
            with self.subTest(name=name):
                self.write_catalog(hashlib.sha256(SAVE).hexdigest(), name=name)
                with self.assertRaisesRegex(dc.Refused, 'unsafe checkpoint name'):
                    self.run_checkpoint(name)
        self.write_catalog(hashlib.sha256(SAVE).hexdigest())
        for stamp in ('../../x', 'T1', '20261013T120000Z/..', '20261013T120000Z"'):
            with self.subTest(stamp=stamp):
                with self.assertRaisesRegex(dc.Refused, 'unsafe stamp'):
                    self.run_checkpoint(stamp=stamp)
        self.assert_no_userdata()

    # ---- lead control 4: ownership, not absence of .git ----

    def test_refuses_project_without_ownership_marker_and_never_touches_it(self):
        candidate = self.base / 'candidate'
        candidate.mkdir()
        (candidate / 'project.godot').write_text('config_version=5\n')
        (candidate / 'override.cfg').write_bytes(b'[display]\n')
        before = tree(candidate)
        with self.assertRaisesRegex(dc.Refused, 'prepare'):
            self.run_checkpoint(project=candidate)
        self.assertEqual(tree(candidate), before)
        self.assertEqual(self.calls, [])
        self.assert_no_userdata()

    def test_refuses_copied_ownership_marker(self):
        candidate = self.base / 'candidate'
        candidate.mkdir()
        (candidate / 'project.godot').write_text('config_version=5\n')
        (candidate / dc.OWNER_FILE).write_bytes((self.project / dc.OWNER_FILE).read_bytes())
        with self.assertRaisesRegex(dc.Refused, 'made for'):
            self.run_checkpoint(project=candidate)

    def test_refuses_shared_checkout(self):
        with self.assertRaisesRegex(dc.Refused, '.git'):
            self.run_checkpoint(project=self.main)
        self.assertEqual(self.calls, [])

    def test_prepare_makes_new_owned_copy_and_leaves_source_alone(self):
        before = tree(self.main)
        self.assertFalse((self.project / '.git').exists())
        self.assertFalse((self.project / 'tmp').exists())
        owner = json.loads((self.project / dc.OWNER_FILE).read_text())
        self.assertEqual(owner['project'], str(self.project))
        with self.assertRaisesRegex(dc.Refused, 'already exists'):
            dc.prepare(self.main, self.project, out=lambda *_: None)
        self.assertEqual(tree(self.main), before)

    def test_run_with_prepare_from_creates_and_uses_new_copy(self):
        fresh = self.base / 'fresh'
        self.assertEqual(self.run_checkpoint(project=fresh, prepare_from=self.main), 0)
        self.assertIn(str(fresh), self.calls[0]['command'])
        self.assertTrue((fresh / dc.OWNER_FILE).is_file())

    # ---- refusals kept from r1 ----

    def test_refuses_bad_hash(self):
        self.write_catalog('0' * 64)
        with self.assertRaisesRegex(dc.Refused, 'bad-hash'):
            self.run_checkpoint()
        self.assert_no_userdata()

    def test_refuses_missing_source(self):
        self.source.unlink()
        with self.assertRaisesRegex(dc.Refused, 'missing'):
            self.run_checkpoint()

    def test_refuses_unknown_name(self):
        with self.assertRaisesRegex(dc.Refused, 'unknown checkpoint'):
            self.run_checkpoint('nowhere')

    def test_refuses_existing_userdata(self):
        (self.data / ROOT).mkdir()
        with self.assertRaisesRegex(dc.Refused, 'already exists'):
            self.run_checkpoint()

    def test_refuses_unrestored_override(self):
        (self.project / 'override.cfg').write_text(dc.MARKER + '\n[application]\n')
        with self.assertRaisesRegex(dc.Refused, 'did not restore'):
            self.run_checkpoint()

    # ---- lead control 6: failure, timeout, descendants, concurrency ----

    def test_override_restored_when_launch_raises(self):
        before = (self.project / 'override.cfg').read_bytes()
        def boom(command, env=None):
            raise RuntimeError('launch failed')
        with self.assertRaises(RuntimeError):
            self.run_checkpoint(launcher=boom)
        self.assertEqual((self.project / 'override.cfg').read_bytes(), before)

    def test_override_restored_when_godot_binary_is_missing(self):
        before = (self.project / 'override.cfg').read_bytes()
        launch = dc.OwnedLauncher(self.project, timeout=5)
        with self.assertRaises(FileNotFoundError):
            self.run_checkpoint(launcher=lambda c, env=None: launch(['/nonexistent/godot-binary'], env=env))
        self.assertEqual((self.project / 'override.cfg').read_bytes(), before)

    def _pids_file(self):
        return self.base / 'pids.txt'

    def _child_script(self, detach):
        # A launcher that leaves a grandchild (optionally in its own session, like a sandboxed game) and blocks.
        start = 'setsid sleep 60' if detach else 'sleep 60'
        return ['sh', '-c', f'{start} & echo $! > {self._pids_file()}; sleep 60']

    def _wait_pid(self):
        for _ in range(100):
            if self._pids_file().exists() and self._pids_file().read_text().strip():
                return int(self._pids_file().read_text())
            time.sleep(0.02)
        self.fail('grandchild pid not written')

    def _assert_dead(self, pid):
        ident = dc._ident(pid)
        self.assertIsNone(ident, f'grandchild {pid} still alive')

    def test_timeout_stops_owned_descendants_then_restores(self):
        for detach in (False, True):
            with self.subTest(detach=detach):
                if self._pids_file().exists():
                    self._pids_file().unlink()
                (self.project / 'override.cfg').write_bytes(b'[display]\r\n')
                launch = dc.OwnedLauncher(self.project, timeout=0.8, grace=2.0, poll=0.05)
                seen = {}
                def launcher(command, env=None):
                    return launch(self._child_script(detach), env=env)
                stamp = '20261013T12000%dZ' % int(detach)
                code = self.run_checkpoint(launcher=launcher, stamp=stamp)
                seen['pid'] = self._wait_pid()
                self.assertEqual(code, 124)
                self._assert_dead(seen['pid'])
                self.assertEqual((self.project / 'override.cfg').read_bytes(), b'[display]\r\n')

    def test_r1_style_timeout_orphans_the_grandchild(self):
        # Negative control: what r1's subprocess.run(timeout) did (kill the direct child only). Its grandchild survives.
        proc = subprocess.Popen(self._child_script(False), start_new_session=True)  # session only for cleanup below
        try:
            proc.wait(timeout=0.5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        pid = self._wait_pid()
        try:
            self.assertIsNotNone(dc._ident(pid), 'expected the r1 method to orphan the grandchild')
        finally:
            os.killpg(proc.pid, 9)

    def test_surviving_owned_process_keeps_isolation_config(self):
        def stubborn(command, env=None):
            raise dc.OwnedProcessAlive({(4242, 1)}, 124)
        with self.assertRaisesRegex(dc.Refused, 'still alive'):
            self.run_checkpoint(launcher=stubborn)
        text = (self.project / 'override.cfg').read_text()
        self.assertIn(dc.MARKER, text)
        with self.assertRaisesRegex(dc.Refused, 'did not restore'):
            self.run_checkpoint(stamp='20261013T120001Z')

    def test_refuses_concurrent_run_on_same_copy(self):
        before = (self.project / 'override.cfg').read_bytes()
        with dc.ProjectLock(self.project):
            with self.assertRaisesRegex(dc.Refused, 'another checkpoint run'):
                self.run_checkpoint()
        self.assertEqual((self.project / 'override.cfg').read_bytes(), before)
        self.assertEqual(self.calls, [])

    def test_refuses_when_a_process_already_runs_on_the_copy(self):
        proc = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)', '--path', str(self.project)])
        self.spawned.append(proc)
        time.sleep(0.1)
        before = (self.project / 'override.cfg').read_bytes()
        with self.assertRaisesRegex(dc.Refused, 'already running'):
            self.run_checkpoint()
        self.assertEqual((self.project / 'override.cfg').read_bytes(), before)
        self.assertEqual(self.calls, [])

    def test_real_catalog_is_valid_and_earned(self):
        entries = dc.load_catalog()
        self.assertIn('jungle-from-museum', entries)
        for entry in entries.values():
            self.assertEqual(entry['resume_path'], dc.RESUME_PATHS[entry['area']])
            self.assertIn(entry['provenance']['kind'], ('earned', 'supplied'))
            self.assertEqual(entry['provenance']['kind'] == 'supplied', bool(entry['supplied']))


if __name__ == '__main__':
    unittest.main()
