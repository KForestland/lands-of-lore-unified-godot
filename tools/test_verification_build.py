import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import verification_build as vb
import verify_project as vp


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.manifest = {key: {} for key in ('source', 'assets', 'templates', 'staged_inputs',
                                            'project_sha256', 'export_presets_sha256', 'package_docs')}
        self.commands = []
        self.progress = []

    def fake_logged(self, command, log, timeout):
        self.commands.append(command)
        log.write_text('PASS\n')
        if '--export-release' in command:
            target = Path(command[-1])
            target.parent.mkdir(exist_ok=True)
            target.write_bytes(b'executable')
            target.with_suffix('.pck').write_bytes(b'pack')

    def run_build(self, launcher=None, **kw):
        with patch.object(vb, 'build_inputs', return_value={'input': 'hash'}), \
             patch.object(vb, 'verify', return_value=self.manifest), \
             patch.object(vb, 'logged', side_effect=launcher or self.fake_logged):
            return vb.build(self.folder, self.folder, self.folder, {'input': 'hash'}, 1,
                            lambda steps: self.progress.append(json.loads(json.dumps(steps))), **kw)

    def test_success_reports_ordered_steps_and_hashes(self):
        result = self.run_build()
        self.assertTrue(result['passed'])
        self.assertEqual([s['name'] for s in result['steps']], ['stage', 'stage_verify', 'linux', 'windows'])
        self.assertEqual(len(result['artifacts']), 4)
        self.assertTrue((self.folder / 'build/SHA256SUMS').is_file())
        self.assertEqual(self.progress[0][0]['status'], 'running')
        self.assertTrue(all(s['status'] == 'passed' for s in self.progress[-1]))

    def test_stage_failure_stops_before_export(self):
        def fail(command, log, timeout):
            self.commands.append(command)
            raise ValueError('stage failed')
        with self.assertRaisesRegex(ValueError, 'stage failed'):
            self.run_build(fail)
        self.assertEqual(len(self.commands), 1)
        self.assertEqual(self.progress[-1][-1]['status'], 'failed')

    def test_missing_exports_fail_even_with_zero_exit(self):
        with self.assertRaisesRegex(ValueError, 'Missing or empty export'):
            self.run_build(lambda *args: None)
        self.assertFalse((self.folder / 'build/SHA256SUMS').exists())

    def test_differing_packs_fail(self):
        def changed(command, log, timeout):
            self.fake_logged(command, log, timeout)
            if '--export-release' in command and 'Windows' in command:
                Path(command[-1]).with_suffix('.pck').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'packs differ'):
            self.run_build(changed)

    def test_source_drift_stops_before_staging(self):
        with patch.object(vb, 'build_inputs', return_value={'input': 'changed'}):
            with self.assertRaisesRegex(ValueError, 'changed during regressions'):
                vb.build(self.folder, self.folder, self.folder, {'input': 'hash'}, 1, lambda _: None)
        self.assertFalse((self.folder / 'build').exists())

    def test_logged_rejects_engine_error_with_zero_exit(self):
        with self.assertRaisesRegex(ValueError, 'engine errors'):
            vb.logged([sys.executable, '-c', 'print("SCRIPT ERROR: broken")'], self.folder / 'error.log', 2)

    def test_logged_timeout_keeps_evidence(self):
        with self.assertRaises(subprocess.TimeoutExpired):
            vb.logged([sys.executable, '-c', 'import time; print("started", flush=True); time.sleep(30)'],
                      self.folder / 'timeout.log', 0.3)
        self.assertIn('started', (self.folder / 'timeout.log').read_text())

    def test_regression_failure_never_builds(self):
        target = self.folder / 'run'
        def regression(command, cwd):
            report = target / 'regressions/report.json'
            report.parent.mkdir()
            report.write_text('{}')
            return subprocess.CompletedProcess(command, 1)
        with patch.object(vp, 'snapshot', return_value={'input': 'hash'}), \
             patch.object(vb, 'build_inputs', return_value={'input': 'hash'}), \
             patch.object(vp.subprocess, 'run', side_effect=regression), \
             patch.object(vb, 'build') as build:
            code = vp.main(['--out', str(target), '--build', '--templates', str(self.folder)])
        self.assertEqual(code, 1)
        build.assert_not_called()
        self.assertEqual(json.loads((target / 'verification.json').read_text())['status'], 'failed')


if __name__ == '__main__':
    unittest.main()
