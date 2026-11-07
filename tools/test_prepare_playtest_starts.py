#!/usr/bin/env python3
"""Refusal controls for tools/prepare_playtest_starts.py (no Godot needed except the last test).

python3 tools/test_prepare_playtest_starts.py  [LOL2_GODOT="tmp/godot_host_starts.sh" also runs the game-validator control]
"""
import json
import os
import shlex
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_playtest_starts as tool  # noqa: E402

NEVER = ['/nonexistent/godot-must-not-run']


class Refusals(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp(prefix='pts_test_'))
        self.addCleanup(shutil.rmtree, self.dir, True)
        self.src = self.dir / 'src'
        self.dest = self.dir / 'dest'
        self.src.mkdir()
        self.save = self.src / 'a.json'
        self.save.write_text('{"format": "lol2-restoration-hive", "version": 1}\n')
        self.entry = {'id': 'a', 'title': 'A', 'act': 1, 'area': 'Hive', 'resume': 'hive', 'save': 'a.json',
                      'sha256': tool.digest(self.save), 'source': {'test': 't', 'commit': '0' * 40, 'input_sha256': None},
                      'identities': {'contains': {'quests.x': [1]}, 'excludes': {}, 'values': {}}}

    def manifest(self, *entries):
        path = self.dir / 'm.json'
        path.write_text(json.dumps({'schema': 1, 'entries': list(entries)}))
        return path

    def refused(self, manifest, only=(), source=None):
        with self.assertRaises(tool.Refused) as caught:
            tool.stage(source or self.src, NEVER, only, manifest=manifest, dest=self.dest, out=lambda *_: None)
        self.assertFalse(self.dest.exists(), 'nothing staged on refusal')
        return str(caught.exception)

    def test_unknown_id(self):
        self.assertIn('not in the manifest', self.refused(self.manifest(self.entry), only=['b']))

    def test_missing_file(self):
        self.assertIn('missing', self.refused(self.manifest(self.entry), source=self.dir / 'empty'))

    def test_changed_bytes(self):
        self.save.write_text('{}')
        self.assertIn('differs from the manifest pin', self.refused(self.manifest(self.entry)))

    def test_unsafe_name_and_kind(self):
        self.assertIn('unsafe save name', self.refused(self.manifest(dict(self.entry, save='../a.json'))))
        self.assertIn('unknown resume kind', self.refused(self.manifest(dict(self.entry, resume='map'))))
        self.assertIn('duplicate', self.refused(self.manifest(self.entry, dict(self.entry, id='b'))))
        self.assertIn('source missing commit', self.refused(self.manifest(dict(self.entry, source={'test': 't', 'input_sha256': None}))))
        self.assertIn('missing identities', self.refused(self.manifest({k: v for k, v in self.entry.items() if k != 'identities'})))

    def test_committed_manifest_loads(self):
        entries = tool.load_manifest()
        self.assertEqual(len(entries), 11)
        self.assertTrue(all(e['act'] == 1 for e in entries))

    @unittest.skipUnless(os.environ.get('LOL2_GODOT'), 'set LOL2_GODOT to run the game-validator control')
    def test_game_validator_refuses_wrong_format(self):
        # Pinned (sha matches) but not a valid Hive save: the game's own validator must refuse it.
        self.assertIn('game validator refused', str(self._stage_with_godot()))

    def _stage_with_godot(self):
        with self.assertRaises(tool.Refused) as caught:
            tool.stage(self.src, shlex.split(os.environ['LOL2_GODOT']), manifest=self.manifest(self.entry),
                       dest=self.dest, out=lambda *_: None)
        self.assertFalse(self.dest.exists())
        return caught.exception


if __name__ == '__main__':
    unittest.main()
