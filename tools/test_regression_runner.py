"""Exercise success, hung assertion, ordinary error and timeout handling."""
import os
import sys
import unittest
from run_regressions import run_one

class RunnerTests(unittest.TestCase):
    def run_script(self, code, timeout=5):
        return run_one([sys.executable, '-u', '-c', code], timeout, os.environ.copy())
    def test_success(self):
        code, log, expired, _ = self.run_script("print('PASS normal')")
        self.assertEqual((code, log.strip(), expired), (0, 'PASS normal', False))
    def test_hung_script_error_preserves_trace(self):
        code, log, expired, elapsed = self.run_script("import time; print('SCRIPT ERROR: Assertion failed.'); print('at: fixture.gd:12'); time.sleep(30)")
        self.assertEqual(code, 1)
        self.assertFalse(expired)
        self.assertIn('fixture.gd:12', log)
        self.assertLess(elapsed, 2)
    def test_timeout(self):
        code, _, expired, _ = self.run_script('import time; time.sleep(30)', 0.1)
        self.assertEqual(code, 124)
        self.assertTrue(expired)
    def test_ordinary_error_keeps_following_output(self):
        code, log, expired, _ = self.run_script("print('ERROR: diagnostic'); print('PASS following check')")
        self.assertEqual(code, 0)
        self.assertFalse(expired)
        self.assertIn('PASS following check', log)
    def test_closed_output_still_times_out(self):
        code, _, expired, _ = self.run_script('import os,time; os.close(1); os.close(2); time.sleep(30)', 0.1)
        self.assertEqual(code, 124)
        self.assertTrue(expired)

if __name__ == '__main__': unittest.main()
