import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import verify_project as verify

class VerificationTests(unittest.TestCase):
    def report(self):
        return dict(complete=True, passed=True, source_stable=True,
                    tests=[dict(name='check', passed=True)], source_start={'a':'hash'}, source_end={'a':'hash'})
    def test_stable_complete_selection(self):
        self.assertEqual(verify.assess(self.report(), ['check']), [])
    def test_fail_closed(self):
        for field, value in [('complete',False), ('passed',False), ('source_stable',False),
                             ('tests',[]), ('source_start',{}), ('source_end',{'a':'changed'})]:
            with self.subTest(field=field):
                report=self.report(); report[field]=value
                self.assertTrue(verify.assess(report,['check']))
        self.assertTrue(verify.assess(self.report(),['different']))
    def test_status_never_runs_commands(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(verify.subprocess,'run') as run:
            p=Path(tmp)
            verify.write(p/'verification.json',dict(profile='quick',status='running',selected_tests=['check']))
            self.assertEqual(verify.main(['--status',tmp]),0)
            run.assert_not_called()
    def test_existing_evidence_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(verify.subprocess,'run') as run:
            p=Path(tmp)/'sentinel'; p.write_text('keep')
            with self.assertRaises(SystemExit): verify.main(['--out',tmp])
            self.assertEqual(p.read_text(),'keep'); run.assert_not_called()

if __name__ == '__main__': unittest.main()
