#!/usr/bin/env python3
"""Decode the two EXEC damage-event sequences without assigning playback seconds."""
import hashlib,json,struct
from pathlib import Path
from PIL import Image
from lol2_creature_sprite_format import group_frames,lcw,decode_blocks  # published decoders (same code as the former RE copies)
from lol2_material_format import sections,rgb_palette

def write_frames(b,states,out):
    """Decode selector11/12 frames into out. states[selector].views[0].resource_reference is asserted; frame_events and
    native_interval are copied when present (native audit), else None (published state table)."""
    assert hashlib.sha256(b).hexdigest()=='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'
    s=sections(b);po=struct.unpack_from('<I',b,4)[0];pal=rgb_palette(b[po:po+768],6)
    descriptors={i:struct.unpack_from('<6H11I',b,s[2]+i*56) for i in range((s[3]-s[2])//56)}
    groups={g['base']:g for g in group_frames({i:d for i,d in descriptors.items() if d[3]==0x1246})}
    out.mkdir(exist_ok=True)
    clips=[]
    for selector,resource,count in [(11,704,18),(12,771,17)]:
        assert groups[resource]['count']==count
        state=states[selector];assert state['views'][0]['resource_reference']==resource
        frames=[]
        for index,r in enumerate(groups[resource]['frames']):
            d=descriptors[r];payload=b[s[3]+d[7]:s[3]+d[7]+d[12]]
            book_index=struct.unpack_from('<I',payload,8)[0]
            offset,allocation,packed=struct.unpack_from('<III',b,s[9]+book_index*12)
            assert s[8]<=offset and offset+allocation<=s[9] and 0<packed<=allocation
            book=lcw(b[offset:offset+packed]);w,h,pixels,used,tail=decode_blocks(payload,book)
            assert (w,h)==(320,200)
            rgba=bytes(c for i in pixels for c in (*pal[i*3:i*3+3],255 if i else 0))
            filename=f'selector_{selector}_frame_{index:02}.png'
            Image.frombytes('RGBA',(w,h),rgba).save(out/filename)
            frames.append(dict(frame=index,file=filename,resource=r,payload_sha256=hashlib.sha256(payload).hexdigest(),
                               indices_sha256=hashlib.sha256(pixels).hexdigest(),codebook_sha256=hashlib.sha256(book).hexdigest(),unread_tail_bytes=tail))
        clips.append(dict(selector=selector,base=resource,frames=frames,events=state.get('frame_events'),native_interval=state.get('native_interval')))
    return clips

def legacy():
    from verify_hive_attack_events import main as verify  # native audit, legacy path only
    proof=verify()
    b=Path('~/lol2_out/hive_geometry_20260914/texture.bin').read_bytes()
    out=Path('~/lol2_out/hive_executioner_attacks_20260915')
    clips=write_frames(b,proof['states'],out)
    (out/'review.json').write_text(json.dumps(dict(clips=clips,archive_sha256=proof['archive_sha256'],
        scope='All35 source frames; source group ordinals, palette and codebooks checked. Index0 alpha is a review interpretation. Frame positions verified for damage requests; native clock seconds and applied health loss remain unverified.'),indent=2)+'\n')
    page='''<!doctype html><meta charset="utf-8"><title>EXEC damage-event frames</title>
<style>body{background:#252b31;color:#eee;font:18px sans-serif;max-width:900px;margin:32px auto;padding:16px}img{width:800px;max-width:100%;background:#46505a;image-rendering:pixelated}input{width:90%}button,select{font:inherit;padding:8px}strong{color:#ffca75}</style>
<h1>Executioner damage-event frames</h1><p>The original frame events request damage on selector11 frame8 and selector12 frames7/11. These are requests, not verified health loss. No playback speed is assumed.</p>
<label>Sequence <select id="clip"><option value="0">Selector11 · resource704 ·18 frames</option><option value="1">Selector12 · resource771 ·17 frames</option></select></label>
<p id="label"></p><img id="image" alt="Original executioner animation frame"><p><input id="frame" aria-label="Animation frame" type="range" min="0" value="0"></p><p id="events"></p>
<p>Each kind1 event requests floor(base byte A6 ×50/100), subject to attack gates. Target armor, resistance and health handling are not replayed.</p>
<script>const clips=DATA;const choose=document.getElementById('clip'),slider=document.getElementById('frame');function show(){const clip=clips[+choose.value],n=+slider.value;document.getElementById('image').src=clip.frames[n].file;document.getElementById('label').textContent='Selector '+clip.selector+' · frame '+n+' of '+(clip.frames.length-1);const hits=clip.events.filter(e=>e.frame===n);document.getElementById('events').textContent=hits.map(e=>e.kind===1?'DAMAGE REQUEST ·50% scaling':'Source sound event '+e.value_word).join(' / ')||'No frame event';}choose.onchange=()=>{slider.max=clips[+choose.value].frames.length-1;slider.value=0;show();};slider.oninput=show;choose.onchange();</script>'''
    (out/'review.html').write_text(page.replace('DATA',json.dumps(clips)))
    print('Exported35 original attack-event frames:',out/'review.html')

if __name__!='export_hive_attack_review':  # runpy.run_path (prepare_hive_executioner_sprites legacy) or direct run
    legacy()
