"""Staging integrity checks with tiny local files; no original assets or Godot needed."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('verify_demo_stage', ROOT / 'tools/verify_demo_stage.py')
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)


class StageIntegrity(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.source, self.output, self.templates = root / 'source', root / 'out', root / 'templates'
        for folder in ('scripts', 'scenes', 'tools', 'assets/lol2/generated/dummy_creatures'):
            (self.source / folder).mkdir(parents=True)
        (self.source / 'project.godot').write_text(
            '[application]\nconfig/name="Lands of Lore Unified Godot"\n'
            'run/main_scene="res://scenes/lol2/setup.tscn"\n')
        (self.source / 'scripts/game.gd').write_text('extends Node\n')
        (self.source / 'scripts/light.gdshaderinc').write_text('// included shader input\n')
        (self.source / 'scenes/setup.tscn').write_text('[gd_scene format=3]\n')
        (self.source / 'assets/lol2/generated/dummy_creatures/creatures.json').write_text('{}\n')
        # These are identity-only fixtures, not claimed decodable image/audio files.
        (self.source / 'assets/picture.png').write_bytes(b'picture fixture')
        (self.source / 'assets/sound.wav').write_bytes(b'sound fixture')
        self.templates.mkdir()
        for name in VERIFIER.TEMPLATES:
            (self.templates / name).write_bytes(name.encode())
        shutil.copy2(ROOT / 'tools/prepare_standalone_demo.py', self.source / 'tools')
        subprocess.run([sys.executable, str(self.source / 'tools/prepare_standalone_demo.py'),
                        '--output', str(self.output), '--templates', str(self.templates)],
                       check=True, capture_output=True)
        self.stage = self.output / 'project'

    def verify(self):
        return VERIFIER.verify(self.source, self.output, self.templates)

    def test_recipe_and_shader_include_are_pinned(self):
        result = self.verify()
        self.assertEqual(len(result['assets']), 3)
        self.assertEqual(result['source']['scripts/light.gdshaderinc'],
                         VERIFIER.digest(self.source / 'scripts/light.gdshaderinc'))
        self.assertEqual(set(result['templates']), set(VERIFIER.TEMPLATES))

    def test_modified_runtime_is_rejected(self):
        (self.stage / 'scripts/game.gd').write_text('extends Node3D\n')
        with self.assertRaisesRegex(ValueError, 'Staged content differs'):
            self.verify()

    def test_missing_and_extra_files_are_rejected(self):
        path = self.stage / 'assets/picture.png'
        path.rename(path.with_suffix('.extra'))
        with self.assertRaisesRegex(ValueError, 'missing=.*picture.png.*extra=.*picture.extra'):
            self.verify()

    def test_raw_import_rule_is_required(self):
        (self.stage / 'assets/sound.wav.import').write_text('[remap]\nimporter="wav"\n')
        with self.assertRaisesRegex(ValueError, 'keep-import'):
            self.verify()

    def test_launch_gate_must_match(self):
        path = self.stage / 'project.godot'
        path.write_text(path.read_text().replace('original_game_gate.tscn', 'setup.tscn'))
        with self.assertRaisesRegex(ValueError, 'Staged project differs'):
            self.verify()

    def test_template_path_must_match(self):
        path = self.stage / 'export_presets.cfg'
        path.write_text(path.read_text().replace('linux_release.x86_64', 'different.x86_64'))
        with self.assertRaisesRegex(ValueError, 'supplied template'):
            self.verify()

    def test_required_export_feature_cannot_be_dropped(self):
        path = self.stage / 'export_presets.cfg'
        path.write_text(path.read_text().replace('original_game_required', ''))
        with self.assertRaisesRegex(ValueError, 'custom_features'):
            self.verify()

    def test_cli_preserves_existing_manifest(self):
        path = self.output / 'source_asset_manifest.json'
        path.write_text('{"existing":true}\n')
        result = subprocess.run([sys.executable, str(ROOT / 'tools/verify_demo_stage.py'),
                                 '--source', str(self.source), '--output', str(self.output),
                                 '--templates', str(self.templates)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('Refusing to replace', result.stderr)
        self.assertEqual(json.loads(path.read_text()), {'existing': True})


if __name__ == '__main__':
    unittest.main()
