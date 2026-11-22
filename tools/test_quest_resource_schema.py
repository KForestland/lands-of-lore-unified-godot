#!/usr/bin/env python3
"""R131 negative source probes; no engine, no changed runtime inputs."""
import copy
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from build_quest_resource_policy import build, ROOT
from quest_resource_schema import literal, resolve

class SourceShapes(unittest.TestCase):
    def test_real_owner_paths_and_receipts_are_qualified(self):
        policy=build()
        self.assertEqual(len(policy['obligations']),15)
        self.assertTrue(all(row['done'] for row in policy['obligations']))
        self.assertIn('scripts/lol2/l14_chamber_voices.gd',policy['source_pins'])
        self.assertEqual(policy['obligations'][-1]['quantity_profiles']['with_serum_before_initiation']['need'],3)
    def changed_build(self,file,old,new):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            shutil.copytree(ROOT/'scripts/lol2',root/'scripts/lol2',ignore=shutil.ignore_patterns('*.json','*.uid','native_scripts','region_mover','height_boundary','act2_movement','actor_media'))
            path=root/'scripts/lol2'/file
            text=path.read_text();self.assertIn(old,text);path.write_text(text.replace(old,new))
            return build(root)
    def test_removed_completion_field_fails_build(self):
        with self.assertRaisesRegex(ValueError,'Unknown quest policy state path'):
            self.changed_build('l14_chamber_voices.gd','"offered":false','"offered_elsewhere":false')
    def test_removed_recoverable_shape_fails_build(self):
        with self.assertRaisesRegex(ValueError,'lacks slots'):
            self.changed_build('l13_exit_lock_state.gd','"slots":{}','"different_slots":{}')
    def test_definition_numbers_cannot_silently_enter_exact_ending(self):
        text=(ROOT/'scripts/lol2/l20_finale.gd').read_text()
        import re
        old=re.search(r'^const WEAPONS[^\n]+',text,re.M)[0]
        with self.assertRaisesRegex(ValueError,'Exact identity obligation'):
            self.changed_build('l20_finale.gd',old,'const WEAPONS := [35,22]')
    def test_changed_owner_hash_is_not_hidden(self):
        before=build();after=self.changed_build('l20_finale.gd','extends Node3D','extends Node3D\n# audited-source-change')
        self.assertNotEqual(before['source_pins'],after['source_pins'])
    def test_hash_in_literal_string_is_not_a_comment(self):
        self.assertEqual(literal('"literal # marker" # real comment',ROOT/'scripts/lol2/l20_finale.gd'),'literal # marker')
    def test_missing_done_or_recoverable_key_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'Unknown quest policy state path'):
            resolve({'owner':{'slots':{}}},['owner','missing','committed'])

if __name__=='__main__':unittest.main()
