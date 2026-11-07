#!/usr/bin/env python3
"""Decode all frames of verified initial and completion selectors."""
import hashlib,json,struct
from pathlib import Path
from PIL import Image
from lol2_creature_sprite_format import group_frames,lcw,decode_blocks  # published decoders (same code as the former RE copies)
from lol2_material_format import sections,rgb_palette

def write_frames(blob,states,out):
    """Decode selector0/2 frames into out; states[selector].views[0].resource_reference is asserted."""
    assert hashlib.sha256(blob).hexdigest()=='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'
    s=sections(blob);po=struct.unpack_from('<I',blob,4)[0];palette=rgb_palette(blob[po:po+768],6)
    out.mkdir(exist_ok=True)
    descriptors={i:struct.unpack_from('<6H11I',blob,s[2]+i*56) for i in range((s[3]-s[2])//56)}
    groups={g['base']:g for g in group_frames({i:d for i,d in descriptors.items() if d[3]==0x1246})}
    rows=[]
    for selector,resource in [(0,688),(2,433)]:
        state=states[selector]
        assert state['views'][0]['resource_reference']==resource
        assert groups[resource]['count']==16
        frames=[]
        for frame,r in enumerate(groups[resource]['frames']):
            d=descriptors[r];payload=blob[s[3]+d[7]:s[3]+d[7]+d[12]]
            ci=struct.unpack_from('<I',payload,8)[0]
            offset,allocation,packed=struct.unpack_from('<III',blob,s[9]+ci*12)
            assert s[8]<=offset and offset+allocation<=s[9] and 0<packed<=allocation
            book=lcw(blob[offset:offset+packed])
            width,height,pixels,used,tail=decode_blocks(payload,book)
            assert (width,height)==d[1:3]==(320,200)
            rgba=bytes(c for index in pixels for c in (*palette[index*3:index*3+3],255 if index else 0))
            filename=f'selector_{selector}_frame_{frame:02}.png'
            image=Image.frombytes('RGBA',(width,height),rgba);image.save(out/filename)
            if frame==0:image.save(out/f'selector_{selector}_resource_{resource}.png')
            frames.append(dict(frame=frame,file=filename,resource=r,payload_sha256=hashlib.sha256(payload).hexdigest(),
                               codebook_sha256=hashlib.sha256(book).hexdigest(),rgba_sha256=hashlib.sha256(rgba).hexdigest(),unread_tail_bytes=tail))
        rows.append(dict(selector=selector,resource=resource,declared_frames=16,first_frame=frames[0]['file'],frames=frames))
    return rows

def legacy():
    from verify_hive_actor_binding import main as verify  # native audit, legacy path only
    proof=verify()
    blob=Path('~/lol2_out/hive_geometry_20260914/texture.bin').read_bytes()
    out=Path('~/lol2_out/hive_executioner_selectors_20260915')
    rows=write_frames(blob,proof['executioner']['states'],out)
    (out/'review.json').write_text(json.dumps(dict(archive_sha256=proof['archive_sha256'],poses=rows,
        scope='All32 source frames decoded; original source palette, index0 alpha interpretation. Decoder tail retained in report. Initial selector0 binding proven; completion requests selector2 unless behaviorA8=15. No idle/movement meaning or host playback speed is inferred.'),indent=2)+'\n')
    (out/'review.html').write_text('''<!doctype html><meta charset="utf-8"><title>Executioner selector binding</title>
<style>body{background:#252b31;color:#eee;font:18px sans-serif;margin:32px}main{display:flex;gap:24px;flex-wrap:wrap}img{width:640px;max-width:100%;image-rendering:pixelated;background:#46505a}section{max-width:640px}</style>
<h1>Executioner: initial and nest-completion selectors</h1><p>Actor36 binds EXEC. Source nest completion requests selector2 unless behavior byte A8 equals15. All32 frames are exported; first frames shown below. AI/attack meanings remain unverified.</p><main>'''+''.join(f'<section><h2>Selector {r["selector"]} · resource {r["resource"]}</h2><img src="{r["first_frame"]}"><p>{r["declared_frames"]} declared frames; first frame shown.</p></section>' for r in rows)+'</main>')
    print(out/'review.html')

if __name__!='export_hive_executioner_selectors':  # runpy.run_path (legacy preparer) or direct run
    legacy()
