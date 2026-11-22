#!/usr/bin/env python3
"""Build the fifteen native item-source policy tables; every shipped row is log/owner.

Catalog facts are exported by export_item_grant_catalog.gd through the guarded
engine. The independent Godot test compares commands directly with native input.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[1]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def encode(data):return (json.dumps(data,indent=2,sort_keys=True,ensure_ascii=False)+'\n').encode()
def callers(data):
    result={}
    for obj in data['objects']:
        for event in obj['events']:
            if 'group' not in event or 'stream' not in event:continue
            kind=int(event['kind'])
            raw=bytes.fromhex(event['raw_hex'])
            trigger=raw[6] if str(obj['ref']).startswith('region:') and len(raw)>6 else kind
            row={'object':obj['ref'],'event':trigger,'record_kind':kind}
            result.setdefault((int(event['stream']),int(event['group'])),[]).append(row)
    return result

def build(root,catalog,policy):
    defs_path=root/'assets/lol2/generated/items/definitions.json'
    definitions=json.loads(defs_path.read_text())['definitions']
    by_identity={int(row['identity']):row for row in definitions}
    assert catalog['definitions_sha256']==sha(defs_path),'Stale catalog definition input'
    assert catalog['placements_sha256']==sha(root/'scripts/lol2/act2_items_source.json'),'Stale placement catalog input'
    outputs={};hits=[0]*len(policy['owners'])
    for path in sorted((root/'scripts/lol2/native_scripts').glob('*.json')):
        data=json.loads(path.read_text());area=path.stem;links=callers(data);commands={}
        for group in data['groups']:
            for cmd in group['commands']:
                if int(cmd['opcode'])!=3 or int(cmd['kind'])!=1:continue
                raw=bytes.fromhex(cmd['raw_hex']);identity=struct.unpack_from('<I',raw,4)[0]
                definition=by_identity[identity];offset=int(cmd['file_offset']);key=str(offset)
                assert key not in commands,(area,'duplicate native command offset',offset)
                owners=sorted(links.get((int(group['stream']),int(group['group'])),[]),key=lambda r:(r['object'],r['event'],r['record_kind']))
                row={'file_offset':offset,'group':int(group['group']),'stream':int(group['stream']),
                     'object':owners[0]['object'] if len(owners)==1 else '',
                     'event':owners[0]['event'] if len(owners)==1 else -1,'callers':owners,
                     'identity':identity,'definition':int(definition['index']),'arg':int(raw[8]),'target':int(cmd['target']),
                     'id':f'act2:{area}:grant{offset}','action':'log','text':'','note':'',
                     'grade':'UNKNOWN callee 0x95B68 / vtable +0x6C; DEVIATIONS0191; log only',
                     'arg_grade':'UNKNOWN meaning; raw byte retained, never interpreted',
                     'blocked_by':[],'evidence':''}
                for index,rule in enumerate(policy['owners']):
                    if rule['area']!=area:continue
                    if 'definition' in rule and int(rule['definition'])!=row['definition']:continue
                    if 'group' in rule and int(rule['group'])!=row['group']:continue
                    if 'object' in rule and not any(c['object']==rule['object'] for c in owners):continue
                    owner='scripts/lol2/'+rule['owner'];assert (root/owner).is_file(),owner
                    row.update(action='owner',owner=owner,evidence=rule['evidence'],grade='Existing owner overlap; native callee/argument still UNKNOWN; no second grant')
                    hits[index]+=1
                commands[key]=row
        for row in commands.values():
            rivals={item['id'] for item in catalog['items'] if item['area']==area and int(item['definition'])==row['definition']}
            rivals.update(other['id'] for other in commands.values() if other['definition']==row['definition'] and other['id']!=row['id'])
            row['same_definition']=sorted(rivals)
        outputs[area]={'version':1,'area':area,'rule':'Default log only; named hand-written overlaps owner. Argument meaning UNKNOWN. No live native grants enabled.',
                       'native_sha256':sha(path),'catalog_facts_sha256':hashlib.sha256(encode(catalog)).hexdigest(),
                       'policy_sha256':hashlib.sha256(encode(policy)).hexdigest(),'commands':commands}
    assert len(outputs)==15,'Stage all fifteen native script exports first'
    assert all(hits),[(r,h) for r,h in zip(policy['owners'],hits) if not h]
    return outputs

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=ROOT)
    p.add_argument('--catalog',type=Path);p.add_argument('--policy',type=Path);p.add_argument('--out',type=Path);p.add_argument('--check',action='store_true');a=p.parse_args()
    catalog=json.loads((a.catalog or a.root/'tests/fixtures/item_grant_catalog_facts.json').read_text())
    policy=json.loads((a.policy or a.root/'tools/item_grant_owner_policy.json').read_text())
    outputs=build(a.root,catalog,policy);out=a.out or a.root/'scripts/lol2/item_grants'
    if not a.check:out.mkdir(parents=True,exist_ok=True)
    failed=[]
    for area,data in outputs.items():
        path=out/(area+'.json');raw=encode(data)
        if a.check:
            if not path.is_file() or path.read_bytes()!=raw:failed.append(area)
        else:path.write_bytes(raw)
        print(area,len(data['commands']),'commands',sum(r['action']=='owner' for r in data['commands'].values()),'owner, rest log')
    if failed:raise SystemExit('Stale item grant tables: '+', '.join(failed))
    print('PASS',sum(len(v['commands']) for v in outputs.values()),'native commands, deterministic tables; no live grants')
if __name__=='__main__':main()
