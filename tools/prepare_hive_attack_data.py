#!/usr/bin/env python3
"""Prepare the complete existing Hive attack data pack without native replay."""
import argparse, csv, hashlib, io, json, struct
from pathlib import Path
from lol2_source_format import parse_mix, u32
from lol2_material_format import sections
from lol2_creature_sprite_format import parse_states, read_events, group_frames

ARCHIVE='a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
GLOBAL='1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd'
EXE='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
TEXTURE='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'


def sha(b): return hashlib.sha256(b).hexdigest()

def require(value,message):
    if not value: raise ValueError(message)

def entry(archive,key):
    rows=[e for e in parse_mix(archive) if e['key']==key]
    require(len(rows)==1,'Expected unique archive entry')
    e=rows[0]
    return e,archive[e['offset']:e['offset']+e['size']]

def csv_table(archive,key,name,count,columns):
    e,raw=entry(archive,key)
    rows=list(csv.reader(io.StringIO(raw.decode('ascii'))))[1:count+1]
    table=[[int(v) if v else 0 for v in r[1:columns+1]] for r in rows]
    require(len(table)==count and all(len(r)==columns for r in table),'CSV extent differs')
    require(all(-128<=v<=255 for r in table for v in r),'CSV byte value out of range')
    source=dict(name=name,entry=e,sha256=sha(raw))
    parsed=bytes(v&255 for r in table for v in r)
    return table,source,dict(source,rows=count,columns=columns,parsed_sha256=sha(parsed))

def prepare(game,texture,output):
    require(not output.exists(),'Output must be fresh')
    for source in (game,texture):
        require(output!=source and output not in source.parents and source not in output.parents,'Output overlaps an input')
    arc=(game/'DAT/L5_HC.MIX').read_bytes(); glob=(game/'GLOBAL.MIX').read_bytes()
    exe=(game/'LOLG.DAT').read_bytes(); blob=texture.read_bytes()
    require((sha(arc),sha(glob),sha(exe),sha(blob))==(ARCHIVE,GLOBAL,EXE,TEXTURE),'Unsupported originals or texture')
    _,geo=entry(arc,3776990464); _,meta=entry(arc,3776335874)
    entity=parse_states(meta)['entities'][1];require(entity['name']=='EXEC','Definition differs')
    outputs={}
    def put(name,data): outputs[name]=json.dumps(data,indent=2).encode()+b'\n'
    effects,effect_source,effect_full=csv_table(glob,3634660276,r'global\ai\EXEC\effector.csv',58,30)
    stats,stat_source,stat_full=csv_table(glob,3427340867,r'global\ai\EXEC\stat.csv',32,1)
    goals,goal_source,_=csv_table(glob,2034966871,r'global\ai\globalai.csv',14,30)
    put('adjustments.json',dict(version=1,rows={str(i):effects[i] for i in (7,8)},provenance=effect_full))
    put('ai_adjustments.json',dict(version=1,goals=goals,conditions=effects[9:58],sources=[goal_source,effect_source]))
    for filename,key,columns,output_name in [('actions.csv',303482539,15,'action_choice.json'),('goals.csv',1010172452,14,'goal_choice.json')]:
        table,source,_=csv_table(glob,key,'global\\ai\\EXEC\\'+filename,46,columns)
        require(all(-128<=v<=127 for r in table for v in r),'Signed choice weight differs')
        put(output_name,dict(version=1,weights=table[:30],goals=table[32:46],source=dict(source,global_sha256=GLOBAL)))
    # Preserve the constructor's historical total/minimum contract, pinned to the source executable.
    total=bytes.fromhex(entity['raw_hex'])[0x81]
    require(total==30 and sha(exe[0xa1d28+0x37000:0xa1d4d+0x37000])=='29a74402fae336facd3cf29531628560b705eb36ba8e3bf4a15d3a0121be7c68','Recorded constructor contract differs')
    values=[r[0]&255 for r in stats]
    put('initial_stats.json',dict(version=1,stats=values[:30],copied_tail=values[30:],total=total,minimum=3,source=stat_full))
    count,start=u32(geo,0xc4),u32(geo,0xc8);end=start+count*8
    require(start>=0xe0 and end+count*26==u32(geo,0xdc)<=len(geo),'Marker-bank extent differs')
    bank=geo[start:end];require(count==60,'Marker count differs');outputs['marker_bank.bin']=bank
    put('marker_bank.json',dict(version=1,count=count,bank_sha256=sha(bank),archive_sha256=ARCHIVE,geometry_key=3776990464,source_offset=start))
    start=u32(geo,0x1c)+36*56;record=geo[start:start+56]
    require(len(record)==56 and record[32]==1,'Actor36 definition differs')
    put('actor_marker.json',dict(version=1,actor=36,definition=1,initial_marker=struct.unpack_from('<H',record,39)[0],source_record_offset=start,source_record_sha256=sha(record),archive_sha256=ARCHIVE))
    # Read the existing byte-indexed effect window through initialized LE pages.
    le=0x39024+u32(exe,0x39060);ot=le+u32(exe,le+0x40);first=u32(exe,ot+108)
    def initialized(offset):
        page=le+u32(exe,le+0x48)+(first-1+offset//4096)*4
        require(exe[page+3]==0,'Unsupported LE page')
        physical=int.from_bytes(exe[page:page+3],'big')
        return exe[0x39024+u32(exe,le+0x80)+(physical-1)*4096+offset%4096]
    window=bytes(initialized(0xb95c+i) for i in range(1024))
    put('effect_condition_flags.json',dict(version=1,flags=list(window[3::4]),executable_sha256=EXE,window_sha256=sha(window)))
    count,offset=struct.unpack_from('<II',meta,0x50);sec=sections(blob)
    descriptors={i:struct.unpack_from('<6H11I',blob,sec[2]+i*56) for i in range((sec[3]-sec[2])//56)}
    grouped={g['base']:g for g in group_frames({i:d for i,d in descriptors.items() if d[3]==0x1246})}
    clips=[]
    for selector,resource,frames in [(0,688,16),(2,433,16),(11,704,18),(12,771,17)]:
        state=entity['states'][selector];require(len(state['views'])==1 and state['views'][0]['resource_reference']==resource,'Animation binding differs')
        d=descriptors[resource]
        actual=grouped[resource]['count'] if resource in grouped else d[4]
        require((resource in grouped or d[3] in (0x2c6,0x28e)) and actual==frames,'Frame count differs')
        raw=bytes.fromhex(state['raw_hex']);interval=struct.unpack_from('<i',raw,4)[0]>>8
        events,_=read_events(meta,offset,count,struct.unpack_from('<H',raw,8)[0])
        clips.append(dict(selector=selector,resource=resource,frames=actual,interval=interval,events=[dict(kind=e['kind'],frame=e['frame'],raw_hex=e['raw_hex']) for e in events]))
    put('attack.json',dict(version=1,clips=clips[2:],provenance=dict(executable_sha256=EXE,archive_sha256=ARCHIVE,texture_sha256=TEXTURE)))
    put('animation.json',dict(version=1,clips=[dict(c,action=entity['entries_bytes'][c['selector']][0]) for c in clips],provenance=dict(executable_sha256=EXE,archive_sha256=ARCHIVE)))
    require(len(outputs)==11,'Incomplete pack')
    target=output/'assets/lol2/generated/hive_attack';target.mkdir(parents=True)
    for name,data in outputs.items():(target/name).write_bytes(data)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game',type=Path,required=True);p.add_argument('--texture',type=Path,required=True);p.add_argument('--output-root',type=Path,required=True)
    a=p.parse_args()
    try:prepare(a.game.resolve(),a.texture.resolve(),a.output_root.resolve())
    except (ValueError,OSError,KeyError,IndexError,struct.error) as error:p.error(str(error))
    print('PASS complete 11-file Hive attack data pack')

if __name__=='__main__':main()
