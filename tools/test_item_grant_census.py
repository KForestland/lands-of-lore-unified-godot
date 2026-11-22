import json
from pathlib import Path
import tempfile
import unittest
import sys
import copy
import shutil
from contextlib import contextmanager

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))

from tools.check_item_grant_census import check, functions, operation_sites, scan

ROOT=Path(__file__).resolve().parents[1]


class ItemGrantCensusTest(unittest.TestCase):
    @contextmanager
    def mirror(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name)
            for folder in ['scripts','scenes']:
                for source in (ROOT/folder).rglob('*'):
                    if source.suffix not in ('.gd','.tscn','.tres'):continue
                    target=root/source.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);target.symlink_to(source)
            shutil.copytree(ROOT/'tests/fixtures/saves_d5da60a',root/'tests/fixtures/saves_d5da60a')
            for row in self.fixture().get('runtime_baselines',{}).get('files',[]):
                target=root/row['path'];target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(ROOT/row['path'],target)
            self.assertEqual(check(root,self.fixture()),[],"Each mutation starts from a passing complete mirror")
            yield root

    def fixture(self):return json.loads((ROOT/'tests/fixtures/item_grant_census_742dcab.json').read_text())

    def test_removed_writer_fails(self):
        with self.mirror() as root:
            path=root/'scripts/lol2/item_grants.gd';text=path.read_text()
            self.assertIn('if added: inventory.append(id)',text)
            path.unlink();path.write_text(text.replace('if added: inventory.append(id)','if added: pass'))
            self.assertIn('source sites changed scripts/lol2/item_grants.gd::grant',check(root,self.fixture()))

    def test_removed_api_call_fails(self):
        with self.mirror() as root:
            path=root/'scripts/lol2/museum_prism.gd';text=path.read_text()
            call='Grants.grant(host,ITEM,{"cap":false,"duplicate":"allow"})'
            self.assertIn(call,text)
            path.unlink();path.write_text(text.replace(call,'pass'))
            self.assertIn('pinned derived/reader function changed scripts/lol2/museum_prism.gd::_collect',check(root,self.fixture()))

    def test_changed_history_hash_fails(self):
        with self.mirror() as root:
            path=root/'scripts/lol2/l12_frozen_bow.gd';text=path.read_text()
            self.assertIn('You catch the blue bow.',text)
            path.unlink();path.write_text(text.replace('You catch the blue bow.','Intentionally changed text.'))
            self.assertIn('pinned derived/reader function changed scripts/lol2/l12_frozen_bow.gd::take',check(root,self.fixture()))

    def test_reclassified_builder_fails(self):
        fixture=self.fixture();key=fixture['must_remain_builders'][0]
        next(r for r in fixture['functions'] if r['file']+'::'+r['function']==key)['kind']='add'
        self.assertIn('pure builder misclassified '+key,check(ROOT,fixture))

    def test_golden_change_fails(self):
        with self.mirror() as root:
            path=root/'tests/fixtures/saves_d5da60a/areas/L10_DC.json'
            path.write_bytes(path.read_bytes()+b' ')
            self.assertIn('golden save bytes changed L10_DC',check(root,self.fixture()))

    def test_relative_and_scene_module_references_fail(self):
        for relative,source in [('scripts/lol2/probe.gd','extends Node\nconst Grant=preload("item_grants.gd")\n'),
                                ('scripts/lol2/split_probe.gd','extends Node\nconst G=preload("item_"+"grants.gd")\n'),
                                ('scenes/lol2/probe.tscn','[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/lol2/item_grants.gd" id="1"]\n')]:
            with self.subTest(relative=relative),self.mirror() as root:
                path=root/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(source)
                self.assertIn('unlisted production module user '+relative,check(root,self.fixture()))

    def test_r108_wrapped_pack_and_parameter_mutators(self):
        for source,spelling in [
            ('func f():\n var p={"collected":host.carried_collected}\n State.take(state,p)\n','State . take'),
            ('func f(xs):\n xs.call(which,id)\n','call'),
            ('func f():\n var p=host.carried_collected\n p.call_deferred(which,id)\n','call_deferred'),
            ('func f(xs):\n xs.pop_at(0)\n','pop_at'),
            ('func f(arbitrary:Array):\n arbitrary.resize(0)\n','resize'),
            ('func f(xs):\n var renamed=xs\n renamed.append(id)\n','renamed . append'),
            ('func f():\n host.call("set","carried_collected",next_pack)\n','call'),
        ]:
            with self.subTest(source=source):
                self.assertTrue(any(spelling in x for x in operation_sites(source)))

    def test_direct_alias_getter_and_parameter_sites(self):
        for expression in [
            'host.carried_collected.append(id)',
            'var renamed=host.carried_collected\n renamed.append(id)',
            'var renamed=host.get("carried_collected")\n renamed.append(id)',
            'host.get("carried_inventory").collected.append(id)',
            'host.set_deferred("carried_collected", next_pack)',
            'unknown(host.carried_collected)',
            'items.append(id)',
            'inventory.duplicate().append(id)',
        ]:
            with self.subTest(expression=expression):
                self.assertTrue(operation_sites('func take(items:Array):\n '+expression))

    def test_comments_and_strings_are_not_code(self):
        self.assertEqual(operation_sites('''func f():
 print("host.carried_collected.append(id); inventory.erase(id)")
 # host.carried_collected.append(id)
 var text="""inventory.append(id)
carried.clear()"""
'''),[])

    def test_multiline_getter_binding_is_not_lost(self):
        sites=operation_sites('''func f():
 var renamed = (
   host.get("carried_collected")
 )
 renamed.append(id)
''')
        self.assertTrue(any('renamed . append' in x for x in sites))

    def test_scalar_result_is_not_tainted_as_an_array_alias(self):
        sites=operation_sites('''func f():
 var scalar=Catalog.slot(host.carried_collected)
 scalar.health=10
''')
        self.assertFalse(any('scalar . health' in x for x in sites))

    def test_inner_class_engine_callback_is_scanned(self):
        owners=functions('''extends Node
class A:
\textends Node
\tfunc _ready():
\t\thost.carried_collected.append(id)
class B:
\textends Node
\tfunc _ready():
\t\thost.get("carried_inventory").collected.append(id)
''')
        self.assertEqual(set(owners),{'A._ready','B._ready'})
        self.assertTrue(all(operation_sites(body) for body in owners.values()))

    def test_current_production_and_mutation_probe(self):
        fixture=json.loads((ROOT/'tests/fixtures/item_grant_census_742dcab.json').read_text())
        self.assertEqual(check(ROOT,fixture),[])
        # Individual source files are linked read-only into a throwaway tree;
        # probe writes never modify the actual production checkout.
        with self.mirror() as root:
            target=root/'scripts/lol2/census_mutation_probe.gd'
            for source in ['func f():\n host.carried_collected.append(id)\n',
                           'class Inner:\n\tfunc _ready():\n\t\tvar p=host.get("carried_collected")\n\t\tp.append(id)\n',
                           'func f():\n host.set_deferred("carried_collected",items)\n',
                           'func f(xs):\n xs.call(which,id)\n']:
                target.write_text(source)
                failures=check(root,fixture)
                self.assertTrue(any('source sites changed scripts/lol2/census_mutation_probe.gd' in x for x in failures),failures)

    def test_runtime_baselines_and_inventory_are_pinned(self):
        fixture=self.fixture();fixture.pop('runtime_baselines')
        self.assertIn('runtime baseline fixture inventory missing',check(ROOT,fixture))
        with self.mirror() as root:
            relative='tests/fixtures/item_grant_site_baseline_20c7797.json'
            path=root/relative;path.write_bytes(path.read_bytes()+b' ')
            self.assertIn('runtime baseline changed '+relative,check(root,self.fixture()))

    def test_additional_golden_variant_is_pinned(self):
        with self.mirror() as root:
            relative='tests/fixtures/saves_d5da60a/areas/L1_DC_v1.json'
            path=root/relative;path.write_bytes(path.read_bytes()+b' ')
            self.assertIn('additional golden save bytes changed '+relative,check(root,self.fixture()))


if __name__=='__main__':unittest.main()
