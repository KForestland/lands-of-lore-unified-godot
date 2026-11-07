#!/usr/bin/env python3
"""Convert source-identified chamber discussion and museum introduction movies.

  python3 tools/export_chamber_discussion.py --game-root GAME --re-root RE --out OUT --evidence EVIDENCE [--include-kenneth]

Default: Cave discussion and both museum introductions (production clips 3, 4, 5). --include-kenneth also prepares
kevin_entry6.ogv, the Kenneth clip that opens the Cave story (production clip 0). Every requested original entry, the
pinned companion-RE converter and ffmpeg/ffprobe are checked before anything is written; conversions are staged and
moved into OUT/EVIDENCE only after all succeed, so invalid inputs never overwrite earlier output. Use a fresh OUT for a
clean preparation (see docs/chamber-sequence.md).
"""
import argparse,hashlib,json,shutil,subprocess,sys,tempfile
from pathlib import Path

p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
p.add_argument('--game-root',type=Path,required=True)
p.add_argument('--re-root',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
p.add_argument('--evidence',type=Path,required=True)
p.add_argument('--include-kenneth',action='store_true',help='also prepare kevin_entry6.ogv (L1_DCI.MIX entry 6, Cave story clip 0)')
a=p.parse_args();sys.path[:0]=[str(a.re_root/'tools'),str(a.re_root/'tools/draracle')]
sha=lambda b:hashlib.sha256(b).hexdigest()
# Companion RE converter (KForestland/lands-of-lore-2-re, published 2791eb1), pinned so outputs stay comparable.
CONVERTER_SHA256='fd8a40bdd50b9394ac4a21574907562247cddd32ccded2491731c28922dde77d'
# name: (archive, entry index, entry key, entry size, entry sha256)
SOURCES={
 'kevin_entry6': ('L1_DCI.MIX',6,2902007471,14900260,'6bd39df40b4ed2517cc959fec347f8bbd40996c226c98ef7c8f5775e2e8a9642'),
 'chamber_discussion': ('L1_DCI.MIX',5,2902003377,36161114,'9f67c5abceab3f2c03dd84d6b13ce9d98bf44ee1a0ed861e9352fd47a11508a2'),
 'museum_introduction_a': ('L3_DHI.MIX',5,2902008005,10895686,'d4068caad97a9ca427a8a2940c33919572540ca92cbe2c680e7d310dd49102a7'),
 'museum_introduction_b': ('L3_DHI.MIX',6,2902008517,18107180,'4c06cd4be21b337c95c7b2ee4277564caa5b5b2a8a8518b5371b76b00695b757'),
}
names=(['kevin_entry6'] if a.include_kenneth else [])+['chamber_discussion','museum_introduction_a','museum_introduction_b']

# ---- preflight: nothing below writes until every check passes --------------------------------------------------------
converter=a.re_root/'tools/convert_cave_video_review.py'
if not converter.is_file() or sha(converter.read_bytes())!=CONVERTER_SHA256: p.error(f'{converter}: missing or not the pinned converter {CONVERTER_SHA256}')
for tool in ['ffmpeg','ffprobe']:
 if shutil.which(tool) is None: p.error(f'{tool} not found on PATH')
codecs=subprocess.run(['ffmpeg','-hide_banner','-encoders'],capture_output=True,text=True).stdout+subprocess.run(['ffmpeg','-hide_banner','-decoders'],capture_output=True,text=True).stdout
for codec in ['libtheora','libvorbis','vqavideo']:
 if codec not in codecs: p.error(f'ffmpeg lacks {codec}')
from lol2_extract_draracle_geometry import parse_mix
from convert_cave_video_review import convert
archives,raws={},{}
for name in names:
 archive,index,key,size,digest=SOURCES[name]
 if archive not in archives:
  path=a.game_root/'DAT'/archive
  if not path.is_file(): p.error(f'missing original {path}')
  archives[archive]=path.read_bytes()
 data=archives[archive];entries=parse_mix(data)
 if index>=len(entries): p.error(f'{archive} has no entry {index}')
 entry=entries[index];raw=data[entry['offset']:entry['offset']+entry['size']]
 if (entry['key'],entry['size'],sha(raw))!=(key,size,digest): raise ValueError('Chamber source movie differs: '+name)
 raws[name]=(archive,index,entry,raw)

# ---- convert into staging, then move into place --------------------------------------------------------------------
a.out.mkdir(parents=True,exist_ok=True);a.evidence.mkdir(parents=True,exist_ok=True)
rows=[];staged=[]
with tempfile.TemporaryDirectory(prefix='.chamber-staging-',dir=a.out) as tmp:
 stage=Path(tmp)
 for name in names:
  archive,index,entry,raw=raws[name]
  source=stage/f'{archive[:-4]}_entry{index}.vqa';source.write_bytes(raw)
  output=stage/f'{name}.ogv';convert(source,output)
  validation=json.loads(output.with_suffix('.json').read_text())
  # Record the final (not staging) paths, as the unstaged legacy run did.
  validation.update(source=str(a.evidence/source.name),output=str(a.out/output.name))
  output.with_suffix('.json').write_text(json.dumps(validation,indent=2)+'\n')
  rows.append(dict(file=output.name,sha256=sha(output.read_bytes()),source_sha256=sha(raw),source_archive=f'DAT/{archive}',source_archive_sha256=sha(archives[archive]),source_entry=entry,frames=validation['frames'],fps=validation['fps']))
  staged+=[(source,a.evidence/source.name),(output,a.out/output.name),(output.with_suffix('.json'),a.out/f'{name}.json')]
 scope='Original archive identities and full-frame conversion verified. Cave discussion follows Kenneth in reviewed reference previews. Museum introduction clips are prepared for destination integration, not a claim of an implemented museum map.'
 if a.include_kenneth: scope+=' --include-kenneth: kevin_entry6.ogv (L1_DCI.MIX entry 6) is the Kenneth clip that opens the Cave story.'
 (stage/'chamber_provenance.json').write_text(json.dumps(dict(clips=rows,scope=scope),indent=2)+'\n')
 staged.append((stage/'chamber_provenance.json',a.out/'chamber_provenance.json'))
 for source,target in staged: shutil.move(str(source),str(target))
print('prepared',[r['file'] for r in rows])
