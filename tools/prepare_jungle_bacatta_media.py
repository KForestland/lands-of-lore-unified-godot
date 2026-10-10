#!/usr/bin/env python3
"""Stage original Bacatta-branch media (local only) from the pinned L4_HJ data.

- prop552 template85 selectors0-14, Bacatta (BACL4) selectors1/2 and guard60 (GGuard def9) selectors8-11
  are texture type0x342 VQA references (names come from scripts/lol2/jungle_bacatta_source.json).
  Each clip is decoded through the exit-movie helpers (every VQFR frame and SND2 sample asserted),
  keyed (0,0,255) → transparent like the existing guard pose clips, and given its own voice WAV.
- BACL4 definition5 frames through the shared creature preparer (walk/idle/pose7).
- Sound requests through the shared AUD-bank stager (tools/prepare_creature_audio_clips.py).
Output: assets/lol2/generated/jungle_bacatta_media/ (ignored, never published).
"""
import argparse,hashlib,json,sys
from pathlib import Path
from PIL import Image
from prepare_jungle_exit_movies import decode,audio,sha,res,ROOT,KEY,TEXTURE,GAME,lookup_movie,parse_vqa_chunks
from lol2.map_video_inventory import vqhd_fields
from prepare_museum_creature_sprites import stage
from prepare_creature_audio_clips import stage_clips
OUT=ROOT/'assets/lol2/generated/jungle_bacatta_media'
CACHE=ROOT/'tmp/jungle_bacatta_media'
SOURCE=ROOT/'scripts/lol2/jungle_bacatta_source.json'

def fetch(name):
    """SPHERE1 entry (the Act One level path sphere1\\l4_hj); a SPHERE2 twin is reported, never chosen."""
    found=lookup_movie(GAME,'L4_HJ',name)
    if found['status']=='exact':
        assert found['prefix']=='SPHERE1' and found['archive']=='DAT/L4_HJI.MIX',name
        hit=dict(sha256=found['sha256'],offset=found['offset'],length=found['length'],twin=None)
    else:
        assert found['status']=='ambiguous',(name,found['status'])
        ones=[c for c in found['candidates'] if c['prefix']=='SPHERE1'];twins=[c for c in found['candidates'] if c['prefix']!='SPHERE1']
        assert len(ones)==1 and ones[0]['wvqa'],name
        hit=dict(sha256=ones[0]['sha256'],offset=ones[0]['offset'],length=ones[0]['length'],twin=[(c['prefix'],c['sha256']) for c in twins])
    archive=(GAME/'DAT/L4_HJI.MIX').read_bytes();assert sha(archive)==found['archive_sha256']
    blob=archive[hit['offset']:hit['offset']+hit['length']];assert sha(blob)==hit['sha256']
    chunks=parse_vqa_chunks(blob);head=vqhd_fields(blob);assert head
    assert sum(k==b'VQFR' for k,v in chunks)==head['count']
    path=CACHE/name;path.write_bytes(blob)
    return dict(sha256=hit['sha256'],prefix='SPHERE1',sphere2_twin=hit['twin']),path,head,sum(len(v)*2 for k,v in chunks if k==b'SND2')

def segments(blob,fps):
    """VQA LINF/LIND frame segments and LNIN names (opcode8 property9/10 play one segment)."""
    pos=12;found={}
    while pos+8<=len(blob):
        n=blob[pos:pos+4];size=int.from_bytes(blob[pos+4:pos+8],'big')
        if n not in found: found[n]=blob[pos+8:pos+8+size]
        pos+=8+size+(size&1)
    if b'LINF' not in found: return []
    l=found[b'LINF'];assert l[:4]==b'LINH';d=l.index(b'LIND');size=int.from_bytes(l[d+4:d+8],'big')
    pairs=[tuple(int.from_bytes(l[d+8+i*4+k:d+10+i*4+k],'little') for k in (0,2)) for i in range(size//4)]
    names=[]
    if b'LNIN' in found:
        n=found[b'LNIN'];names=[x.decode() for x in n[n.index(b'LNID')+8:].split(b'\0') if x]
    assert len(names) in (0,len(pairs))
    return [dict(index=i,first=a,last=b,frames=b-a+1,duration=(b-a+1)/fps,name=names[i] if names else '') for i,(a,b) in enumerate(pairs)]

def clip(name,key):
    found,path,head,samples=fetch(name)
    size=(head['width'],head['height']);folder=OUT/key
    frames=decode(path,CACHE/key,head['count'],size)
    folder.mkdir(parents=True,exist_ok=True)
    for old in folder.glob('*.png'):old.unlink()
    first=Image.open(frames[0]).convert('RGB');w,h=first.size
    corners={first.getpixel(c) for c in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)]}
    # Guard clips key pure blue; Bacatta/prop552 clips key VGA cyan (63*4-1 after decoding).
    assert len(corners)==1 and corners<={KEY,(0,251,251)},(name,corners);key=corners.pop()
    rows=[]
    for i,p in enumerate(frames):
        image=Image.open(p).convert('RGBA')
        image.putdata([(r,g,b,0) if (r,g,b)==key else (r,g,b,255) for r,g,b,_ in image.getdata()])
        target=folder/f'frame_{i:03d}.png';image.save(target);rows.append(res(target))
    voice=None;rate=0
    if samples:
        rate=audio(path,folder/'voice.wav',samples);voice=res(folder/'voice.wav')
    segs=segments(path.read_bytes(),head['fps'])
    assert all(seg['last']<head['count'] for seg in segs)
    return dict(segments=segs,vqa=name,vqa_sha256=found['sha256'],prefix=found['prefix'],sphere2_twin=found['sphere2_twin'],key=list(key),frames=head['count'],fps=head['fps'],width=size[0],height=size[1],
        frame_files=rows,audio=voice,audio_samples=samples,audio_rate=rate,duration=max(head['count']/head['fps'],samples/rate if rate else 0))

def main():
    OUT.mkdir(parents=True,exist_ok=True);CACHE.mkdir(parents=True,exist_ok=True)
    src=json.loads(SOURCE.read_text())
    clips={'prop552':{},'bacatta':{},'guard60':{}}
    names={}
    for owner,table in [('prop552',src['prop_selectors']),('bacatta',src['bacatta_poses']),('guard60',src['guard_poses'])]:
        for selector,row in table.items():
            if owner=='prop552' and selector=='0':continue  # selector0 duplicates selector1 (same resource), never requested
            key=f'{owner}_{selector}'
            if row['vqa'] not in names: names[row['vqa']]=clip(row['vqa'],key)
            clips[owner][selector]=dict(names[row['vqa']],resource=row['resource'],selector=int(selector))
    stage('DAT/L4_HJ.MIX',TEXTURE.read_bytes(),[5],OUT/'bacatta_sprites',game=GAME)
    requests=[int(q) for q in src['sounds']]
    stage_clips(ROOT,'jungle_bacatta_media/sounds',requests,{int(k):v for k,v in src['sounds'].items()},game=GAME)
    import wave
    sounds={}
    for q in requests:
        path=OUT/'sounds'/f'{q}.wav'
        with wave.open(str(path)) as w: frames=w.getnframes();rate=w.getframerate()
        sounds[str(q)]=dict(name=src['sounds'][str(q)],path=res(path),samples=frames,rate=rate,duration=frames/rate,wav_sha256=sha(path.read_bytes()))
    manifest=dict(version=1,archive='DAT/L4_HJI.MIX',source_sha256=sha(SOURCE.read_bytes()),
        clips=clips,sounds=sounds,sprites=res(OUT/'bacatta_sprites/sprites.json'),
        note='Original media, local only. Clip duration = max(frames/fps, voice length). Sprite poses run at the shared 8 fps adapter.')
    (OUT/'media.json').write_text(json.dumps(manifest,indent=1)+'\n')
    print('PASS clips',{o:{s:(c['vqa'],c['frames'],round(c['duration'],3)) for s,c in v.items()} for o,v in clips.items()})
    print('PASS sounds',{q:(s['name'],round(s['duration'],3)) for q,s in sounds.items()})
def cli():
    global ROOT,OUT,CACHE,GAME,TEXTURE,SOURCE
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--texture',type=Path,required=True)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--output-root',type=Path,required=True)
    args=parser.parse_args()
    if args.output_root.exists(): parser.error('--output-root must be a fresh directory')
    for path in [args.texture,args.source]:
        if not path.is_file(): parser.error('Missing input: '+str(path))
    GAME=args.game.resolve();TEXTURE=args.texture.resolve();SOURCE=args.source.resolve()
    ROOT=args.output_root.resolve();OUT=ROOT/'assets/lol2/generated/jungle_bacatta_media';CACHE=ROOT/'tmp/jungle_bacatta_media'
    # res() is the existing imported helper; keep its root synchronized.
    import prepare_jungle_exit_movies as shared
    shared.ROOT=ROOT
    main()
if __name__=='__main__':
    if len(sys.argv)>1: cli()
    else: main()
