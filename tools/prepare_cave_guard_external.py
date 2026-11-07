"""Extract original Cave guard region markers and delayed voice from explicit game root."""
import argparse,json,struct
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_creature_audio_clips import stage_clips
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();game=a.game.resolve();out=a.out.resolve()
if out.exists() or game==out or game in out.parents or out in game.parents:p.error('Output must be fresh and must not overlap game root')
area,arc,e,g,owners,streams=source_area('L1_DC',game);offset,_,records=section(g,12,0x58,44);rows=[]
for id,flags in [(10,3),(29,35)]:
 raw=records[id*44:(id+1)*44];assert raw[28]==flags;rows.append(dict(id=id,raw_hex=raw.hex(),archive_offset=e['offset']+offset+id*44,flags=raw[28]))
offset,_,props=section(g,0x14,0x60,37);raw=props[515*37:516*37];x,y,heading,z=struct.unpack_from('<hhHh',raw);timer=next(o for o in owners if o['owner_kind']=='prop' and o['owner']==515);o=timer['archive_offset'];record=arc[o:o+arc[o]];assert record.hex()=='0a02ba13300102007800';assert [r['raw_hex'] for r in streams[1][5050]]==['0e03030204000000','140303024301ff5dfafa']
data=dict(source=area['source'],regions=rows,timer=dict(placement=raw.hex(),position=[x,z,-y],record_hex=record.hex(),archive_offset=o,initial_countdown=120,request=323),audio=stage_clips(out,'cave_guard_timer',[323],game=game));target=out/'scripts/lol2/cave_guard_external_source.json';target.parent.mkdir(parents=True);target.write_text(json.dumps(data,indent=2)+'\n');print('PASS original region flags, stopped120tick timer and original delayed sound323')
