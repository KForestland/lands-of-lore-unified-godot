import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import run_regressions
from stage_worktree import LIQUID_AREAS, MANIFEST, USERDATA, check, digest, stage, staged_environment, required_selector_media


class StageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        base = Path(self.temporary.name)
        self.source, self.target = base / 'source', base / 'target'
        for root in (self.source, self.target):
            root.mkdir()
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            self.write(root, 'project.godot', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="fixture"\n')
            self.write(root, 'scripts/game.gd', root.name)
            subprocess.run(['git', '-C', str(root), 'add', 'project.godot', 'scripts/game.gd'], check=True)
        for area in LIQUID_AREAS:
            self.write(self.source, f'assets/lol2/generated/liquid/{area}.json', '{}')
            self.write(self.source, f'scripts/lol2/native_scripts/{area}.json', '{}')
        self.write(self.source, 'assets/lol2/generated/image.png', 'media')
        self.write(self.source, 'assets/lol2/doors/untracked.png', 'material')
        self.write(self.source, 'tmp/route_earned_save.json', '{"earned":true}')
        self.write(self.source, 'tmp/owner_saves/owner.json', '{"owner":true}')
        self.write(self.source, 'tmp/godot_host.sh', 'old launcher with wrong --path')
        self.user = self.source / 'tmp/userdata/fixture'
        self.write(self.user, 'tests/restart.json', '{"checkpoint":true}')
        self.write(self.user, 'saves/personal.json', 'private save')
        self.write(self.user, 'settings.cfg', 'private settings')
        self.write(self.target, 'tests/input_test.gd', 'extends SceneTree\nvar path="res://tmp/special_checkpoint.json"\nvar dynamic="res://tmp/l14_chain_"\n')
        self.write(self.source, 'tmp/special_checkpoint.json', '{"special":true}')
        self.write(self.source, 'tmp/l14_chain_stairs.json', '{"chain":true}')

    def pinned_manifest(self, data='{"published":true}'):
        path = self.write(Path(self.temporary.name), 'published/input.json', data)
        manifest = {'format': 'lol2-pinned-test-inputs-v1', 'files': [
            {'path': 'tmp/published_input.json', 'source': str(path), 'sha256': digest(path)}]}
        self.write(self.target, 'tests/fixtures/pilot_inputs_manifest.json', json.dumps(manifest))
        return path

    def selector_producer(self):
        frame = b'qualified pixel fixture'
        expected = {'version': 1, 'files': {'L10_DC/frame.png': {
            'sha256': hashlib.sha256(frame).hexdigest(), 'bytes': len(frame)}}}
        self.write(self.target, 'tests/fixtures/generic_prop_media_manifest.json', json.dumps(expected))
        self.write(self.target, 'tools/prepare_generic_prop_media.py',
                   'import argparse,pathlib,shutil\n'
                   'p=argparse.ArgumentParser();p.add_argument("--game");p.add_argument("--output");a=p.parse_args()\n'
                   'out=pathlib.Path(a.output);(out/"L10_DC").mkdir(parents=True)\n'
                   f'(out/"L10_DC/frame.png").write_bytes({frame!r})\n'
                   'shutil.copyfile(pathlib.Path(__file__).parents[1]/"tests/fixtures/generic_prop_media_manifest.json",out/"manifest.json")\n')
        return self.write(Path(self.temporary.name), 'own_game/LOLG.EXE', 'own game fixture')

    def test_missing_donor_selectors_chain_the_producer_and_enter_the_manifest(self):
        game = self.selector_producer()
        with patch.dict(os.environ, {'LOL2_ORIGINAL_GAME_EXE': str(game)}):
            result = stage(self.source, self.target)
            self.assertEqual(check(self.target), result)
        rows = [r for r in result['files'] if 'generic_props/' in r['path']]
        self.assertEqual(len(rows), 2)
        self.assertTrue(all(r['category'] == 'generated_media' for r in rows))
        frame = self.target / 'assets/lol2/generated/generic_props/L10_DC/frame.png'
        frame.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'selector output missing/changed'):
            required_selector_media(self.target)

    def test_source_only_environment_does_not_require_selector_graphics(self):
        stage(self.source, self.target)
        self.selector_producer()
        self.assertIn('XDG_DATA_HOME', staged_environment(self.target, {}))
        with self.assertRaisesRegex(ValueError, 'Required generic selector media'):
            check(self.target)

    def test_missing_selectors_and_original_fail_clearly(self):
        self.selector_producer()
        with patch.dict(os.environ, {'LOL2_ORIGINAL_GAME_EXE': '/absent/LOLG.EXE'}):
            with self.assertRaisesRegex(ValueError, 'set LOL2_ORIGINAL_GAME_EXE'):
                stage(self.source, self.target)
        self.assertFalse((self.target / MANIFEST).exists())

    def test_selector_dry_run_never_launches_a_producer(self):
        self.selector_producer()
        with patch('stage_worktree.subprocess.run', wraps=subprocess.run) as run:
            stage(self.source, self.target, dry_run=True)
        self.assertFalse(any('prepare_generic_prop_media.py' in str(c) for c in run.call_args_list))
        self.assertFalse((self.target / 'assets/lol2/generated/generic_props').exists())

    def test_incomplete_selector_output_is_preserved(self):
        self.selector_producer()
        self.write(self.target, 'assets/lol2/generated/generic_props/keep.png', 'existing')
        with self.assertRaisesRegex(ValueError, 'Incomplete generic selector folder preserved'):
            stage(self.source, self.target)
        self.assertEqual((self.target / 'assets/lol2/generated/generic_props/keep.png').read_text(), 'existing')

    def test_published_input_stages_without_a_lane_donor_copy(self):
        self.pinned_manifest()
        manifest = stage(self.source, self.target)
        row = next(r for r in manifest['files'] if r['path'] == 'tmp/published_input.json')
        self.assertEqual(row['category'], 'pinned_test_input')
        self.assertEqual((self.target / row['path']).read_text(), '{"published":true}')
        self.assertEqual(check(self.target)['files'], manifest['files'])

    def test_changed_or_missing_published_input_refuses_before_copy(self):
        for missing in [False, True]:
            with self.subTest(missing=missing):
                path = self.pinned_manifest()
                if missing: path.unlink()
                else: path.write_text('changed')
                with self.assertRaisesRegex(ValueError, 'Required pinned test input'):
                    stage(self.source, self.target)
                self.assertFalse((self.target / 'assets').exists())

    def test_published_pin_wins_over_mutable_donor_output(self):
        self.pinned_manifest()
        self.write(self.source, 'tmp/published_input.json', '{"mutable":"different"}')
        manifest = stage(self.source, self.target)
        self.assertEqual((self.target / 'tmp/published_input.json').read_text(), '{"published":true}')
        self.assertEqual(next(r for r in manifest['files'] if r['path'] == 'tmp/published_input.json')['category'], 'pinned_test_input')

    def test_immutable_alias_survives_a_legacy_producer_overwrite(self):
        self.pinned_manifest()
        pin = self.target / 'tests/fixtures/pilot_inputs_manifest.json'
        data = json.loads(pin.read_text())
        data['files'][0]['path'] = 'tmp/generic_l10_inputs/published_input.json'
        pin.write_text(json.dumps(data))
        stage(self.source, self.target)
        self.write(self.target, 'tmp/published_input.json', 'new legacy producer output')
        self.assertEqual((self.target / data['files'][0]['path']).read_text(), '{"published":true}')
        check(self.target)

    def write(self, root, relative, text):
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def test_all_categories_private_userdata_and_code_preservation(self):
        result = stage(self.source, self.target)
        self.assertEqual({r['category'] for r in result['files']},
                         {'generated_media', 'native_script', 'untracked_material', 'chain_save', 'user_tests'})
        self.assertEqual((self.target / 'scripts/game.gd').read_text(), 'target')
        self.assertFalse((self.target / 'tmp/godot_host.sh').exists())
        user = self.target / USERDATA / 'fixture'
        self.assertTrue((user / 'tests/restart.json').is_file())
        self.assertFalse((user / 'saves').exists())
        self.assertFalse((user / 'settings.cfg').exists())
        self.assertTrue((self.target / 'tmp/special_checkpoint.json').is_file())
        self.assertTrue((self.target / 'tmp/l14_chain_stairs.json').is_file())
        self.assertEqual(check(self.target), result)
        self.assertEqual(staged_environment(self.target, {'PATH':'keep','XDG_DATA_HOME':'old'}),
                         {'PATH':'keep','XDG_DATA_HOME':str(self.target / USERDATA)})

    def test_identical_repeat_and_changed_input_detection(self):
        first = stage(self.source, self.target)
        self.assertEqual(stage(self.source, self.target), first)
        (self.target / 'tmp/route_earned_save.json').write_text('changed by a producer')
        with self.assertRaisesRegex(ValueError, 'missing or changed'):
            check(self.target)
        with self.assertRaisesRegex(ValueError, 'preserved'):
            stage(self.source, self.target)

    def test_conflict_preflight_does_not_install_other_files(self):
        self.write(self.target, 'tmp/owner_saves/owner.json', 'keep this owner save')
        with self.assertRaisesRegex(ValueError, 'preserved'):
            stage(self.source, self.target)
        self.assertFalse((self.target / 'assets/lol2/generated/image.png').exists())
        self.assertEqual((self.target / 'tmp/owner_saves/owner.json').read_text(), 'keep this owner save')

    def test_destination_link_cannot_write_to_donor(self):
        link = self.target / 'assets/lol2/generated'
        link.parent.mkdir(parents=True)
        link.symlink_to(self.source / 'assets/lol2/generated', target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            stage(self.source, self.target)
        self.assertFalse((self.target / MANIFEST).exists())

    def test_tracked_target_media_wins(self):
        path = self.write(self.target, 'assets/lol2/doors/untracked.png', 'new tracked revision')
        subprocess.run(['git','-C',str(self.target),'add',str(path)], check=True)
        stage(self.source, self.target)
        self.assertEqual(path.read_text(), 'new tracked revision')

    def test_missing_liquid_or_userdata_fails_before_install(self):
        missing = self.source / 'assets/lol2/generated/liquid/L8_SJ.json'
        missing.unlink()
        with self.assertRaisesRegex(ValueError, 'Missing prepared donor'):
            stage(self.source, self.target)
        self.write(self.source, str(missing.relative_to(self.source)), '{}')
        with self.assertRaisesRegex(ValueError, 'containing tests'):
            stage(self.source, self.target, self.source)
        self.assertFalse((self.target / MANIFEST).exists())

    def test_pinned_anchor_fallback_and_digest(self):
        text = '{"qualified":true}'
        self.write(self.source, 'tmp/producer.json', text)
        self.write(self.target, 'docs/earned-regression-anchors.json', json.dumps({'anchors':[
            {'source':'tmp/producer.json','anchor':'tmp/pinned.json','sha256':hashlib.sha256(text.encode()).hexdigest(),'producer':'earned_test'}]}))
        stage(self.source, self.target)
        self.assertEqual((self.target / 'tmp/pinned.json').read_text(), text)
        (self.source / 'tmp/producer.json').write_text('not the qualified save')
        with self.assertRaisesRegex(ValueError, 'qualified anchor'):
            stage(self.source, self.target)

    def test_dry_run_and_manifest_cannot_redirect_environment(self):
        result = stage(self.source, self.target, dry_run=True)
        self.assertTrue(result['files'])
        self.assertFalse((self.target / MANIFEST).exists())
        stage(self.source, self.target)
        manifest = json.loads((self.target / MANIFEST).read_text())
        manifest['xdg_data_home'] = '/different/project'
        (self.target / MANIFEST).write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, 'invalid worktree'):
            staged_environment(self.target, {})

    def test_runner_uses_staged_user_inputs(self):
        stage(self.source, self.target)
        def fixture(command, timeout, environment, logfile):
            self.assertEqual(environment['XDG_DATA_HOME'], str(self.target / USERDATA))
            self.assertTrue((Path(environment['XDG_DATA_HOME']) / 'fixture/tests/restart.json').exists())
            return 0, 'PASS staged input', False, .01
        with patch.object(run_regressions, 'ROOT', self.target), patch.object(run_regressions, 'run_one', fixture), patch('sys.argv',
                ['runner','--suite','portable','--godot','fixture','--out',str(self.target / 'tmp/report')]):
            self.assertEqual(run_regressions.main(), 0)

    def test_invalid_registered_long_walk_budgets_refuse(self):
        registry = self.target / 'tests/registry'
        registry.mkdir(parents=True)
        row = {'name': 'input_test', 'suite': 'portable', 'mode': 'headless', 'order': 1}
        for budget in [0, -1, float('inf'), float('nan'), True, '5400']:
            with self.subTest(budget=budget):
                (registry / 'input_test.json').write_text(json.dumps({**row, 'timeout_seconds': budget}))
                with patch.object(run_regressions, 'ROOT', self.target), \
                        patch.object(run_regressions, 'REGISTRY', registry), \
                        patch.object(run_regressions, 'TIMEOUTS', {}), \
                        self.assertRaisesRegex(ValueError, 'timeout_seconds must be finite and positive'):
                    run_regressions._load_registry()

    def test_runner_applies_and_reports_registered_long_walk_budget(self):
        stage(self.source, self.target)
        def fixture(command, timeout, environment, logfile):
            self.assertEqual(timeout, 14400)
            return 0, 'PASS registered budget', False, .01
        name = run_regressions.PORTABLE[0][0]
        output = self.target / 'tmp/long_report'
        with patch.object(run_regressions, 'ROOT', self.target), \
                patch.object(run_regressions, 'TIMEOUTS', {name: 14400}), \
                patch.object(run_regressions, 'run_one', fixture), \
                patch('sys.argv', ['runner', '--suite', 'portable', '--test', name, '--timeout', '1500',
                                   '--godot', 'fixture', '--out', str(output)]):
            self.assertEqual(run_regressions.main(), 0)
        self.assertEqual(json.loads((output / 'report.json').read_text())['tests'][0]['timeout_seconds'], 14400)


if __name__ == '__main__':
    unittest.main()
