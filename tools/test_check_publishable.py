"""Publish guard tests: a planted fake owner file is refused, by the check and by the snapshot export.

  python3 -m unittest tools.test_check_publishable
"""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from tools import check_publishable, export_snapshot

LIST = """# Local owner-derived test inputs
| Local test path | Source bundle | Contents |
|---|---|---|
| `tests/fixtures/listed_save.json` + `.provenance.json` | fake | planted |
| `tests/fixtures/gaps/a.json`, `b.json` | fake | planted |
"""


def write(root: Path, rel: str, text: str) -> None:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


class PublishGuardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.tree = self.root / 'tree'
        write(self.tree, 'scripts/game.gd', 'const SAVES := "user://saves"\n')
        write(self.tree, 'tests/fixtures/clean_fixture.json', '{"area": "L8_SJ"}\n')
        write(self.tree, 'tests/fixtures/OWNER_DERIVED.md', '')
        self.owner_list = self.root / 'OWNER_DERIVED.md'
        self.owner_list.write_text(LIST)
        self.patterns = self.root / 'patterns.txt'
        self.patterns.write_text('# test\nPrivate Name\n')
        self.saved_env = os.environ.get(check_publishable.PATTERNS_ENV)
        os.environ[check_publishable.PATTERNS_ENV] = str(self.patterns)

    def tearDown(self):
        if self.saved_env is None:
            os.environ.pop(check_publishable.PATTERNS_ENV, None)
        else:
            os.environ[check_publishable.PATTERNS_ENV] = self.saved_env
        self.tmp.cleanup()

    def problems(self):
        return check_publishable.check(self.tree, self.owner_list)

    def test_list_parsing(self):
        self.assertEqual(check_publishable.listed_paths(self.owner_list),
                         {'tests/fixtures/listed_save.json', 'tests/fixtures/listed_save.provenance.json',
                          'tests/fixtures/gaps/a.json', 'tests/fixtures/gaps/b.json'})

    def test_clean_tree_passes(self):
        self.assertEqual(self.problems(), [])

    def test_missing_pattern_list_refuses_everything(self):
        self.patterns.unlink()
        self.assertTrue(any('missing or empty' in p for p in self.problems()))

    def test_each_kind_is_refused(self):
        cases = {
            'tests/fixtures/listed_save.json': ('{}', 'owner-derived'),
            'tests/fixtures/gaps/b.json': ('{}', 'owner-derived'),
            'tests/fixtures/owner_fake_save.json': ('{}', 'unlisted owner-like fixture name'),
            'docs/notes.md': ('see /' + 'home/someone/x', 'local path'),
            'docs/bug.md': ('from report_' + '2026-11-17T14-50-30_123', 'F10 report id'),
            'tests/fixtures/slot.json': ('{"path": "user://saves/slot_01.json"}', 'user:// path in data'),
            'docs/credits.md': ('thanks to Private Name', 'private pattern'),
        }
        for rel, (text, kind) in cases.items():
            with self.subTest(rel=rel):
                write(self.tree, rel, text)
                problems = self.problems()
                self.assertTrue(any(kind in p and p.endswith(rel) for p in problems), problems)
                (self.tree / rel).unlink()
                self.assertEqual(self.problems(), [])

    def plant(self, rel: str, data: bytes) -> list:
        path = self.tree / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        try:
            return self.problems()
        finally:
            path.unlink()

    def secrets(self) -> str:
        return 'see /' + 'home/someone/x, report_' + '2026-11-17T14-50-30_1, Private Name'

    def assert_kinds(self, problems, rel, kinds):
        line = [p for p in problems if p.endswith(rel)]
        self.assertEqual(len(line), 1, problems)
        for kind in kinds:
            self.assertIn(kind, line[0])

    # Grok's review of 391a72c6 (2026-11-17): six kinds of file got past the guard. One planted file each.
    def test_nul_first_byte_is_still_scanned(self):
        rel = 'docs/nul.md'
        self.assert_kinds(self.plant(rel, b'\0' + self.secrets().encode()), rel, ['local path', 'F10 report id', 'private pattern'])

    def test_godot_folder_is_not_skipped(self):
        rel = '.godot/imported/x.md'
        self.assert_kinds(self.plant(rel, self.secrets().encode()), rel, ['local path', 'F10 report id', 'private pattern'])

    def test_utf16_with_and_without_bom(self):
        for rel, data in [('docs/u16bom.md', self.secrets().encode('utf-16')), ('docs/u16le.md', self.secrets().encode('utf-16-le')),
                          ('docs/u16be.md', self.secrets().encode('utf-16-be')), ('docs/u32.md', self.secrets().encode('utf-32'))]:
            with self.subTest(rel=rel):
                self.assert_kinds(self.plant(rel, data), rel, ['local path', 'F10 report id', 'private pattern'])

    def test_patterns_are_case_insensitive(self):
        cases = [('docs/a.md', b'Report_' + b'2026-11-17T14-50-30', 'F10 report id'), ('docs/b.md', b'/' + b'HOME/someone', 'local path'),
                 ('tests/fixtures/Owner_save.json', b'{}', 'unlisted owner-like fixture name'),
                 ('docs/c.md', b'PRIVATE NAME', 'private pattern'), ('tests/fixtures/s.json', b'{"p": "USER://x"}', 'user:// path'),
                 ('Tests/Fixtures/Listed_Save.json', b'{}', 'owner-derived')]
        for rel, data, kind in cases:
            with self.subTest(rel=rel):
                self.assert_kinds(self.plant(rel, data), rel, [kind])

    def test_binary_needs_allow_list_by_hash(self):
        import hashlib
        data = bytes(range(256)) * 4
        rel = 'assets/sprite.png'
        self.assert_kinds(self.plant(rel, data), rel, ['binary or undecodable, not allow-listed'])
        allow = self.root / 'allow.txt'
        allow.write_text(f'{hashlib.sha256(data).hexdigest()}  {rel}\n')
        path = self.tree / rel
        path.write_bytes(data)
        self.assertEqual(check_publishable.check(self.tree, self.owner_list, allow_file=allow), [])
        path.write_bytes(data + b'x')
        self.assertTrue(any('not allow-listed' in p for p in check_publishable.check(self.tree, self.owner_list, allow_file=allow)))
        path.unlink()

    def test_export_refuses_nul_first_and_godot_files(self):
        for rel, data in [('docs/nul.md', b'\0' + self.secrets().encode()), ('.godot/x.md', self.secrets().encode())]:
            with self.subTest(rel=rel):
                repo = self.root / ('repo_' + rel.replace('/', '_'))
                write(repo, 'tests/fixtures/OWNER_DERIVED.md', LIST)
                (repo / rel).parent.mkdir(parents=True, exist_ok=True)
                (repo / rel).write_bytes(data)
                git = ['git', '-c', 'user.name=t', '-c', 'user.email=t@example.invalid']
                subprocess.run(['git', 'init', '-q', str(repo)], check=True)
                subprocess.run(git + ['-C', str(repo), 'add', '-A', '-f'], check=True)
                subprocess.run(git + ['-C', str(repo), 'commit', '-qm', 'plant'], check=True)
                out = self.root / ('out_' + rel.replace('/', '_'))
                self.assertEqual(export_snapshot.export(repo, 'HEAD', out), 1)
                self.assertEqual(list(out.iterdir()), [])

    # Grok round 3 (a8f9831c): split patterns, backslash paths, symlinks.
    def test_pattern_split_by_line_break(self):
        for rel, data, kind in [('docs/n.md', b'Private\nName', 'private pattern'), ('docs/r.md', b'report_2026-11-17\nT14-50-30', 'F10 report id'),
                                ('docs/h.md', b'/ho\r\nme/someone', 'local path')]:
            with self.subTest(rel=rel):
                self.assert_kinds(self.plant(rel, data), rel, [kind])

    def test_backslash_path(self):
        rel = 'docs/win.md'
        self.assert_kinds(self.plant(rel, b'C:' + b'\\' + b'home' + b'\\' + b'someone' + b'\\x'), rel, ['local path'])

    def test_symlinks_refused(self):
        write(self.root, 'outside/secret.md', 'report_' + '2026-11-17T14-50-30')
        for rel, target in [('docs/rel_link.md', '../../outside/secret.md'), ('docs/abs_link.md', str(self.root / 'outside/secret.md'))]:
            with self.subTest(rel=rel):
                link = self.tree / rel
                link.parent.mkdir(parents=True, exist_ok=True)
                link.symlink_to(target)
                self.assertTrue(any(p == 'symlink (never published): ' + rel for p in self.problems()), self.problems())
                link.unlink()

    def test_export_refuses_symlinks(self):
        for name, target in [('rel', '../secret.md'), ('abs', str(self.root / 'secret_abs.md'))]:
            with self.subTest(name=name):
                repo = self.root / ('linkrepo_' + name)
                write(repo, 'tests/fixtures/OWNER_DERIVED.md', LIST)
                write(repo, 'secret.md', 'clean')
                (repo / 'docs').mkdir(parents=True, exist_ok=True)
                (repo / 'docs/link.md').symlink_to(target)
                git = ['git', '-c', 'user.name=t', '-c', 'user.email=t@example.invalid']
                subprocess.run(['git', 'init', '-q', str(repo)], check=True)
                subprocess.run(git + ['-C', str(repo), 'add', '-A'], check=True)
                subprocess.run(git + ['-C', str(repo), 'commit', '-qm', 'link'], check=True)
                out = self.root / ('linkout_' + name)
                self.assertEqual(export_snapshot.export(repo, 'HEAD', out), 1)
                self.assertEqual(list(out.iterdir()), [])

    def test_export_refuses_planted_owner_file_and_leaves_nothing(self):
        repo = self.root / 'repo'
        write(repo, 'scripts/game.gd', 'extends Node\n')
        write(repo, 'tests/fixtures/OWNER_DERIVED.md', LIST)
        git = ['git', '-c', 'user.name=t', '-c', 'user.email=t@example.invalid']
        subprocess.run(['git', 'init', '-q', str(repo)], check=True)
        subprocess.run(git + ['-C', str(repo), 'add', '-A'], check=True)
        subprocess.run(git + ['-C', str(repo), 'commit', '-qm', 'clean'], check=True)
        out = self.root / 'out'
        # The fake owner list holds no report ids or local paths, so a clean commit exports.
        self.assertEqual(export_snapshot.export(repo, 'HEAD', out), 0)
        write(repo, 'tests/fixtures/owner_planted_save.json', '{"fake": true}')
        subprocess.run(git + ['-C', str(repo), 'add', '-A'], check=True)
        subprocess.run(git + ['-C', str(repo), 'commit', '-qm', 'plant'], check=True)
        out2 = self.root / 'out2'
        self.assertEqual(export_snapshot.export(repo, 'HEAD', out2), 1)
        self.assertEqual(list(out2.iterdir()), [], 'a refused export leaves nothing behind')


if __name__ == '__main__':
    unittest.main()
