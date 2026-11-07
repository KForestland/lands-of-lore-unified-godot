#!/usr/bin/env python3
"""Reproduce Cave sky assets from pinned original archive/texture and geometry evidence."""
import argparse, hashlib, json, struct
from pathlib import Path
from PIL import Image

def sha(b): return hashlib.sha256(b).hexdigest()
def require(ok, message):
    if not ok: raise ValueError(message)
def prepare(archive, texture, geometry, out):
    require(not out.exists(), 'Output must be fresh')
    for source in (archive, texture, geometry):
        require(out.resolve() != source.resolve() and out.resolve() not in source.resolve().parents, 'Output overlaps input')
    mix, tex, geo = archive.read_bytes(), texture.read_bytes(), geometry.read_bytes()
    require(sha(mix)=='6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345','Unsupported archive')
    require(sha(tex)=='102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97','Unsupported texture')
    require(sha(geo)=='5d0f4a72a3d2f88f86288e724801402f20b9148240972a2af27982f81aa7d094','Unsupported geometry evidence')
    g=json.loads(geo); children=set(g['ceiling_subdivisions']['children']); owners=set(g['ceiling_subdivisions']['owners']); regions=[]
    for row in g['regions']:
        raw=bytes.fromhex(row['raw_hex']); at=row['source_offset']
        require(mix[at:at+len(raw)]==raw,'Region raw record mismatch')
        if row['id'] not in children and row['id'] not in owners and row.get('standalone_ceiling') and raw[34]==255: regions.append(row['id'])
    require(len(regions)==52 and {1262,688}<=set(regions),'Sky region coverage differs')
    # DEFAULT image bounds and native environment origin, as recovered in map_environment.py.
    base=86259
    require(struct.unpack_from('<II',tex,base)==(1,385392) and tex[base+16:base+24]==b'DEFAULT\0','DEFAULT record differs')
    require(struct.unpack_from('<II',tex,base+0x128)==(1280,300),'Panorama dimensions differ')
    pixels=tex[base+0x14c:base+0x14c+1280*300]
    require(sha(pixels)=='76fc8675500ba3dbf39a0106e976d9b154baffc685ebcf966eb55c7fa0eba151','Panorama pixels differ')
    entry=g['source']['entry']; raw_geometry=mix[entry['offset']:entry['offset']+entry['size']]
    env_at=struct.unpack_from('<I',raw_geometry,0x28)[0]; origin=struct.unpack_from('<i',raw_geometry,env_at+24)[0]
    require(origin==100,'Native sky origin differs')
    palette_at=struct.unpack_from('<I',tex,4)[0]; palette=tex[palette_at:palette_at+768]
    # DAC expansion follows map_materials.rgb_palette(...,6).
    require(len(palette)==768 and max(palette)<=63,"Invalid DAC palette")
    rgb=bytes((v*255+31)//63 for v in palette)
    image=Image.frombytes('P',(1280,300),pixels);image.putpalette(rgb)
    out.mkdir(parents=True)
    image.convert('RGB').save(out/'panorama.png')
    Image.frombytes('L',(1280,300),pixels).save(out/'panorama_indices.png')
    (out/'environment.json').write_text(json.dumps({'panorama':{'vertical_origin':origin,'width':1280,'height':300,'pixels_sha256':sha(pixels)}},indent=2)+'\n')
    (out/'manifest.json').write_text(json.dumps({'archive_sha256':sha(mix),'texture_sha256':sha(tex),'geometry_evidence_sha256':sha(geo),'open_regions':regions,'scope':'Verified standalone no-ceiling-material regions; other ceiling materials remain provisional.'},indent=2)+'\n')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--archive',type=Path,required=True);p.add_argument('--texture',type=Path,required=True);p.add_argument('--geometry',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();prepare(a.archive,a.texture,a.geometry,a.out)
