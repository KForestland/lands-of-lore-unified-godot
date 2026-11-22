import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import run_regressions
from regression_source import snapshot, changes, git_state, gate_marker, MARKER
import os, subprocess


class SourceTests(unittest.TestCase):
    def test_changes_and_media_exclusion(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ('scripts', 'scenes', 'tests/fixtures', 'assets', 'tmp'):
                (root / folder).mkdir(parents=True)
            (root / 'project.godot').write_text('config')
            (root / 'scripts/actor.gd').write_text('before')
            (root / 'scripts/lighting.gdshaderinc').write_text('before')
            (root / 'tests/fixtures/source.json').write_text('{}')
            (root / 'assets/original.wav').write_bytes(b'original')
            (root / 'tmp/save.json').write_text('personal')
            before = snapshot(root)
            self.assertEqual(before, json.loads(json.dumps(before)))
            self.assertFalse(any(p.startswith(('assets/', 'tmp/')) for p in before))
            (root / 'scripts/actor.gd').write_text('after')
            (root / 'scripts/lighting.gdshaderinc').write_text('after')
            (root / 'tests/fixtures/source.json').unlink()
            (root / 'scenes/new.tscn').write_text('scene')
            after = snapshot(root)
            self.assertEqual(changes(before, after), ['scenes/new.tscn', 'scripts/actor.gd', 'scripts/lighting.gdshaderinc', 'tests/fixtures/source.json'])
            self.assertEqual(changes(after, snapshot(root)), [])
            self.assertIsNone(after['tools/run_regressions.py'])

    def test_runner_reports_concurrent_source_change(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'scripts').mkdir()
            actor = root / 'scripts/actor.gd'
            actor.write_text('before')
            output = root / 'tmp/report'
            def run_and_edit(*args):
                active = json.loads((output / 'report.json').read_text())
                self.assertEqual(active['current_test']['name'], 'hive_attack_portable_test')
                self.assertFalse(active['complete'])
                self.assertEqual(active['current_test']['timeout_seconds'], 300)
                actor.write_text('after')
                return 0, 'PASS fixture', False, 0.01
            with patch.object(run_regressions, 'ROOT', root), patch.object(run_regressions, 'run_one', run_and_edit), patch('sys.argv', ['runner', '--suite', 'portable', '--godot', 'fixture', '--out', str(output)]):
                # Lead 2026-11-12: a source change during a run makes the whole run fail (SOURCE-UNSTABLE).
                self.assertEqual(run_regressions.main(), 1)
            report = json.loads((output / 'report.json').read_text())
            self.assertTrue(report['complete'] and not report['passed'])
            self.assertIsNone(report['current_test'])
            self.assertFalse(report['source_stable'])
            self.assertEqual(report['source_changed_files'], ['scripts/actor.gd'])


class GateTests(unittest.TestCase):
    def test_git_state_sees_head_and_scoped_status(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / 'scripts').mkdir(); (root / 'docs').mkdir()
            (root / 'scripts/a.gd').write_text('one'); (root / 'docs/report.json').write_text('{}')
            subprocess.run(['git', '-C', str(root), 'add', '.'], check=True)
            subprocess.run(['git', '-C', str(root), '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', 'x'], check=True)
            clean = git_state(root)
            self.assertTrue(clean['head']); self.assertEqual(clean['status'], '')
            (root / 'docs/report.json').write_text('{"written": "by a test"}')
            self.assertEqual(git_state(root), clean, 'docs/ is outside the scope (tests write check reports there)')
            (root / 'scripts/a.gd').write_text('two')
            self.assertNotEqual(git_state(root)['status'], clean['status'])

    def test_marker_live_and_stale(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertIsNone(gate_marker(root))
            (root / MARKER).parent.mkdir(parents=True)
            (root / MARKER).write_text(json.dumps({'pid': os.getpid(), 'out': 'x'}))
            self.assertEqual(gate_marker(root)['pid'], os.getpid())
            (root / MARKER).write_text(json.dumps({'pid': 2 ** 22 + 12345, 'out': 'x'}))
            self.assertIsNone(gate_marker(root), 'a marker whose process is gone is stale')


if __name__ == '__main__':
    unittest.main()
