import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import run_regressions
from regression_source import snapshot, changes


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
                self.assertEqual(run_regressions.main(), 0)
            report = json.loads((output / 'report.json').read_text())
            self.assertTrue(report['complete'] and report['passed'])
            self.assertIsNone(report['current_test'])
            self.assertFalse(report['source_stable'])
            self.assertEqual(report['source_changed_files'], ['scripts/actor.gd'])


if __name__ == '__main__':
    unittest.main()
