"""Synthetic coverage for tools/run_sharded_sweep.py prepare_shard: a reused shard whose staged inputs no longer match
their manifest (tests rewrote chain saves; sweep 6d31407b, 2026-11-14) is rebuilt from scratch, never reused, and never
touched when it is not a sweep shard or a gate is live in it."""
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import run_sharded_sweep as sweep  # noqa: E402
import regression_source  # noqa: E402


class PrepareShardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / 'shards'
        self.shard = self.root / 'lol2_shard_1'
        (self.shard / 'tmp/staged_inputs').mkdir(parents=True)
        (self.shard / '.git').write_text('gitdir: elsewhere\n')
        (self.shard / 'tmp/staged_inputs/manifest.json').write_text('{}')
        self.calls = []

    def tearDown(self):
        self.tmp.cleanup()

    def run_prepare(self, staged_ok, live=None, path=None):
        def fake_git(*args, cwd=None):
            self.calls.append(args[:2])
            if args[:2] == ('worktree', 'remove'):
                import shutil
                shutil.rmtree(args[3])
            if args[:2] == ('worktree', 'add'):
                (Path(args[3]) / 'tmp').mkdir(parents=True, exist_ok=True)
                (Path(args[3]) / '.git').write_text('gitdir: elsewhere\n')
            return ''
        with mock.patch.object(sweep, 'git', fake_git), mock.patch.object(sweep, 'staged_ok', lambda p: staged_ok), \
                mock.patch.object(regression_source, 'gate_marker', lambda p: live), \
                mock.patch.object(sweep.subprocess, 'run') as run:
            sweep.prepare_shard(path or self.shard, 'abc', self.root)
            return run.call_args[0][0]

    def test_clean_shard_reused(self):
        command = self.run_prepare(staged_ok=True)
        self.assertNotIn(('worktree', 'remove'), self.calls)
        self.assertIn('--wrapper-only', command)

    def test_changed_inputs_rebuild(self):
        command = self.run_prepare(staged_ok=False)
        self.assertEqual(self.calls, [('checkout', '--detach'), ('worktree', 'remove'), ('worktree', 'add')])
        self.assertIn('--from', command)  # freshly staged from the donor

    def test_live_gate_refused(self):
        with self.assertRaises(SystemExit):
            self.run_prepare(staged_ok=False, live={'pid': 1})
        self.assertNotIn(('worktree', 'remove'), self.calls)

    def test_not_a_shard_refused(self):
        other = Path(self.tmp.name) / 'lol2_r18'
        (other / 'tmp/staged_inputs').mkdir(parents=True)
        (other / '.git').write_text('x')
        (other / 'tmp/staged_inputs/manifest.json').write_text('{}')
        with self.assertRaises(SystemExit):
            self.run_prepare(staged_ok=False, path=other)
        self.assertNotIn(('worktree', 'remove'), self.calls)


if __name__ == '__main__':
    unittest.main()
