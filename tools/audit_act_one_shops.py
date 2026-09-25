#!/usr/bin/env python3
"""Bind the missing Act1 shops and replay Rashar's entry/knowledge branches."""
import itertools,json,struct
from pathlib import Path
from audit_monastery_rooms import ROOT,GAME,digest,extract,movie,capstone,parse_mix,section,calls
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from audit_hive_rune_rooms import fixups,u32
from verify_creature_states import CreatureReplay
PINS={'MAGIC':'9233e3334fa696b82a9efb798491dfda2de47041c8ead86e03210a8ec80887e0','WPN':'3492035c2e1dbe94d39989ad65d2039fbf589d319db2136c84afd4569a96738e','WPNEXT':'7586a3ad38d895709a8f666ad2a74637eab6a2ba69286a64a99729e845412204'}
def replay(image,start,end,flags,held=''):
 cs=capstone.Cs(3,4);cs.detail=True
 ins={i.address:i for i in cs.disasm(image[start:end],start)}
 stops={p for p,i in ins.items() if i.mnemonic in ['call','ret']}|{end}
 m=CreatureReplay(ins,b'');m.regs['esp']=0x3ffffc if start==0x9f5 else 0x400000;pc=start;effects=[];bank=flags.copy()
 # The bounded offer branch inherits the handler's saved EBX stack slot.
 def args(n):return [m.readmem(m.regs['esp']+4*j,4) for j in range(n)]
 def string(p):return image[p:].split(b'\0')[0].decode()
 for _ in range(100):
  pc=m.execute(pc,stops)
  if pc==end:return {'boundary':hex(end),'effects':effects}
  i=ins[pc]
  if i.mnemonic=='ret':
   assert m.regs['esp']==0x400000
   return {'handled':m.regs['eax'],'effects':effects}
  slot=i.operands[0].mem.disp;result=0
  if slot==0x11fc:result=bank.get(str(args(1)[0]),0)
  elif slot==0x11f4:
   value=args(1)[0];bank[str(value)]=1;effects.append(['set_flag',value])
  elif slot==0x123c:result=int(held==string(args(1)[0]))
  elif slot==0x124c:effects.append(['set_global',string(args(2)[0]),args(2)[1]])
  elif slot in [0x1200,0x12cc]:effects.append(['movie' if slot==0x1200 else 'movie_flags']+args(3 if slot==0x1200 else 4))
  elif slot==0x11b0:pass # Original debug output, no gameplay effect.
  elif slot==0x12e8:result=100 # Supplied host result; stored ambient timer, not branch selector.
  elif slot in [0x1214,0x1230]:effects.append(['host_'+hex(slot)]+args(1))
  else:raise ValueError(hex(slot))
  m.regs['eax']=result;pc+=i.size
 raise AssertionError('callback budget')
def main():
 exe=(GAME/'LOLG.DAT').read_bytes();assert digest(exe)=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
 le=0x39024+u32(exe,0x39060);names=[]
 for index in range(46):
  a=0xea6c+index*4;r=fixups(exe,le,306+a//4096)[a%4096];assert r['target_object']==5
  off=0x1c1024+r['target_offset'];name=exe[off:].split(b'\0')[0].decode();names.append(dict(index=index,name=name,relocation=r,file_offset=off))
 assert names[15]['name']=='magic_' and names[43]['name']=='wpnext_' and names[8]['name']=='wpn_'
 report=dict(executable_sha256=digest(exe),room_name_table=names,rooms={},entrances=[],cases=[])
 for name in PINS:
  arc=(GAME/'DAT'/f'{name}.MIX').read_bytes();dll,binding=extract(arc,f'WOMS\\{name}_.WOM');assert digest(dll)==PINS[name]
  image=dll[48:48+u32(dll,36)]
  report['rooms'][name]=dict(archive_sha256=digest(arc),dll=binding)
  if name=='MAGIC':
   # Bind reordered DLL callback slots through the original initializer and LE table.
   init=list(capstone.Cs(3,4).disasm(image[0xf6:0x47c],0xf6));bindings={}
   for slot,target in [(0x1214,0xef44c),(0x1230,0xef508),(0x124c,0xef640)]:
    n=next(n for n,i in enumerate(init) if i.op_str==f'dword ptr [{hex(slot)}], edx')
    offset=int(init[n-1].op_str.split('+ ')[1].split(']')[0],16)
    a=0xe92c+offset;r=fixups(exe,le,306+a//4096)[a%4096]
    assert r['target_object']==2 and r['target_offset']+0x59024==target
    bindings[hex(slot)]=dict(table_offset=offset,target=target,relocation=r)
   report['rooms'][name]['host_bindings']=bindings
   from unicorn import Uc,UC_ARCH_X86,UC_MODE_32
   from unicorn.x86_const import UC_X86_REG_ESP,UC_X86_REG_EAX
   vm=Uc(UC_ARCH_X86,UC_MODE_32);vm.mem_map(0x1000,0x200000)
   for lo,hi in [(0xef44c,0xef461),(0xd6a88,0xd6ae8)]:vm.mem_write(lo,exe[lo+0x37000:hi+0x37000])
   vm.mem_write(0x7ce80,b'\xc3');mana_cases=[]
   for mana in [0,1,20,999,1000,1001,2000]:
    vm.mem_write(0x22574+0x141,struct.pack('<II',2000,mana))
    vm.mem_write(0x180000,struct.pack('<II',0x1ffff0,1000));vm.reg_write(UC_X86_REG_ESP,0x180000)
    vm.emu_start(0xef44c,0x1ffff0,count=100)
    actual=int.from_bytes(vm.mem_read(0x22574+0x145,4),'little');assert actual==max(0,mana-1000)
    assert vm.reg_read(UC_X86_REG_EAX)==actual
    mana_cases.append(dict(before=mana,debit=1000,after=actual))
   report['rooms'][name]['mana_debit_cases']=mana_cases
   report['rooms'][name]['timer_binding']='Slot1230/table80 calls timer methods14FABD/14FA79, then stores returned counter+600 atDB4B8. Original counter cadence/hold integration remains unbound.'
   report['rooms'][name]['hotspots']=calls(image,0x48e,0x51d,{0x11c4:('hotspot',5)})
   report['rooms'][name]['background']=movie(arc,'WOMS\\MAGIC\\MAGIC_.VQA')
   report['rooms'][name]['idle']=movie(arc,'WOMS\\MAGIC\\3099906E.VQA')
   report['rooms'][name]['offer_disassembly']=[f'{i.address:x} {i.mnemonic} {i.op_str}' for i in capstone.Cs(3,4).disasm(image[0x960:0xa98],0x960)]
   for bits in itertools.product(range(2),repeat=5):
    flags=dict(zip(['52','55','56','57','58'],bits));out=replay(image,0xc9f,0xf5f,flags)
    lines=[e[2] for e in out['effects'] if e[0].startswith('movie')]
    expected=[] if flags['52'] or (flags['56'] and not flags['57']) else ([440,441] if flags['55'] and not flags['56'] else ([] if flags['58'] else list(range(400,415))+list(range(416,423))))
    # The second-visit branch precedes the third-visit/no-dialogue branch.
    if not flags['52'] and flags['55'] and not flags['56']:expected=[440,441]
    assert lines==expected,(flags,lines)
    report['cases'].append(dict(kind='entry',flags=flags,result=out))
   for held in ['12-Tho Broken','94-Iron flute','']:
    out=replay(image,0x9f5,0xa98,{},held)
    if held=='12-Tho Broken':
     assert out['effects'][-2:]==[['set_global','GV_KNOWLEDGE_OF_POWER_ORB',1],['movie',30,428,6]]
     assert [e[2] for e in out['effects'] if e[0].startswith('movie')]==list(range(423,429))
    else:assert not out['effects']
    report['cases'].append(dict(kind='broken_item_knowledge_branch',held=held,result=out,limits='Entered only after earlier dead/fixed-item checks; other offer branches not replayed.'))
   lines=sorted({e[2] for c in report['cases'] for e in c['result']['effects'] if e[0].startswith('movie')})
   report['rooms'][name]['movies']=[movie(arc,f'WOMS\\MAGIC\\30{line:03d}06E.VQA') for line in lines]
  elif name=='WPN':
   report['rooms'][name]['knowledge_writer']=[f'{i.address:x} {i.mnemonic} {i.op_str}' for i in capstone.Cs(3,4).disasm(image[0x81c:0x8ae],0x81c)]
   loose=(GAME/'WOMS/WPN_.WOM').read_bytes();report['rooms'][name]['loose_override_sha256']=digest(loose)
   report['rooms'][name]['limits']='Loose WPN differs from archive; both contain a knowledge writer. Runtime precedence and complete admission remain unverified.'
  else:
   assert image[0x70b:].split(b'\0')[0]==b'wpn_'
   report['rooms'][name]['nested_entry']=[f'{i.address:x} {i.mnemonic} {i.op_str}' for i in capstone.Cs(3,4).disasm(image[0x633:0x64e],0x633)]
 for a in json.loads((ROOT/'docs/game-source-inventory.json').read_text())['areas']:
  arc=(GAME/a['source']['file']).read_bytes();assert digest(arc)==a['source']['sha256']
  entry=next(e for e in parse_mix(arc) if e['key']==a['source']['geometry_key']);raw=arc[entry['offset']:][:entry['size']];assert digest(raw)==a['source']['geometry_sha256']
  owners,_=collect_owners(raw,entry['offset'],a['counts']['regions'])
  for stream,(of,cf) in enumerate([(0x3c,0x84),(0x44,0x8c)]):
   for group,cmds in groups(section(raw,of,cf,1)[2]):
    for at,b in cmds:
     if b[0]==12 and b[1]==3 and int.from_bytes(b[4:6],'little') in [8,15,43]:
      idx=int.from_bytes(b[4:6],'little');report['entrances'].append(dict(area=a['id'],source=a['source'],room=names[idx]['name'],stream=stream,group=group,command=b.hex(),commands=[d.hex() for _,d in cmds],owners=[o for o in owners if o['stream']==stream and o['group']==group]))
 assert len(report['entrances'])==5 and {r['area'] for r in report['entrances']}=={'L4_HJ'}
 geometry=json.loads(Path('/home/bob/lol2_out/jungle_geometry_20260914/geometry.json').read_text())
 for row in report['entrances']:
  for owner in row['owners']:
   if owner['owner_kind']=='region':
    reg=geometry['regions'][owner['owner']];owner['polygon']=[[geometry['vertices_fixed'][v][0]/65536,-geometry['vertices_fixed'][v][1]/65536] for v in reg['vertex_indices']];owner['floor_corners']=reg['floor_corners']
 report['scope']='Pinned executable room-name relocations, all15 source-map command streams and direct owners;32 entry replays and3 bounded knowledge-branch replays with explicit host boundaries. This establishes missing Huline Jungle shop content, not live room integration, route admission or full required-content closure. Host1214(1000) binds a clamped player mana debit (seven native wrapper cases);1230(600) binds a timer deadline, whose cadence and hold integration remain open.'
 (ROOT/'docs/act-one-shops-source.json').write_text(json.dumps(report,indent=2)+'\n')
 print('PASS',len(report['cases']),'Rashar cases;',len(report['entrances']),'Huline Jungle shop entrances;',len(report['rooms']['MAGIC']['movies']),'original dialogue clips')
if __name__=='__main__':main()
