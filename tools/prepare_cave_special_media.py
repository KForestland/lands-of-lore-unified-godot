#!/usr/bin/env python3
"""Prepare both existing Cave special-index sprite packs from explicit originals."""
import argparse,hashlib,json,struct
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix,u32
from lol2_material_format import sections
from lol2_creature_sprite_format import decode_rows,require
HASH='102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97'
EXE_HASH='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
def sha(data):return hashlib.sha256(data).hexdigest()
def fixups(exe, le, page):
    """Decode only the internal offset records used by the requested pages."""
    u = lambda o: struct.unpack_from('<I', exe, le + o)[0]
    start, end = struct.unpack_from('<II', exe, le + u(0x68) + page * 4)
    pos, stop = le + u(0x6c) + start, le + u(0x6c) + end
    result = {}
    while pos < stop:
        kind, flags = exe[pos:pos + 2]
        require(kind == 7 and flags in (0, 16), 'Unsupported fixup form')
        length = 9 if flags == 16 else 7
        require(pos + length <= stop, 'Truncated fixup')
        source = struct.unpack_from('<h', exe, pos + 2)[0]
        require(source not in result, 'Duplicate source fixup')
        result[source] = dict(target_object=exe[pos + 4],
            target_offset=int.from_bytes(exe[pos + 5:pos + length], 'little'),
            record_file_offset=pos, record_hex=exe[pos:pos + length].hex())
        pos += length
    return result

def verify(exe, blob):
    require(sha(exe) == EXE_HASH and sha(blob) == HASH, 'Source hash changed')
    mz = 0x39024
    le = mz + struct.unpack_from('<I', exe, mz + 0x3c)[0]
    require(exe[le:le + 2] == b'LE', 'Missing LE')
    u = lambda o: struct.unpack_from('<I', exe, le + o)[0]
    objects = le + u(0x40)
    size, base, flags, first, pages, _ = struct.unpack_from('<6I', exe, objects + 3 * 24)
    require((size, base, pages) == (0x14200, 0x160000, 0), 'Object4 changed')
    evidence = []
    for address, target_object, target_offset in [
            (0x12b441, 4, 0x4000), (0x12b75e, 4, 0x4000),
            (0x12b43c, 4, 0), (0x12b759, 4, 0), (0x9d9b4, 4, 0),
            (0x9d9c6, 5, 0x223e0), (0x9dbc6, 5, 0x223e0)]:
        code_offset = address - 0x59024
        record = fixups(exe, le, 1 + code_offset // 4096)[code_offset % 4096]
        require((record['target_object'], record['target_offset']) ==
                (target_object, target_offset), 'Unexpected relocation target')
        evidence.append(dict(analysis_address=hex(address), **record))
    # Hash-pinned native instructions: header read, table pointer assignment,
    # seek(header+0x18, SET), read(handle, table_base, 0x4200).
    witnesses = {
        0x9d8ec: '68a20600008d542404525089c3e822af0700',
        0x9d9b3: 'b800000000', 0x9d9c5: 'a3e0230200',
        0x9dbaf: '6a008b4c241c5153e830b0070083c40c68004200008b3de02302005753e84fac0700'}
    for address, code in witnesses.items():
        expected = bytes.fromhex(code)
        require(exe[address + 0x37000:address + 0x37000 + len(expected)] == expected,
                'Loader instruction witness changed')
    s = sections(blob)
    require(struct.unpack_from('<I', blob, 0x18)[0] == s[4], 'Shade offset mismatch')
    require(s[5] - s[4] == 0x4200, 'Shade section extent changed')
    table = blob[s[4] + 0x4000:s[4] + 0x4100]
    return table, dict(executable_sha256=EXE_HASH, cache_sha256=HASH,
        le_header=le, object4_virtual_size=size, object4_file_pages=pages,
        relocations=evidence, loader_instruction_hex={hex(k): v for k, v in witnesses.items()},
        shade_section_offset=s[4], shade_load_bytes=0x4200,
        remap_row=64, remap_file_offset=s[4] + 0x4000, remap_sha256=sha(table),
        scope='Static loader provenance: initial table is cache shade row64. No live capture or proof against subsequent runtime modification. Ordinary source shade selection remains outside this fixture.')
def prepare(game,texture,output):
 require(not output.exists(),'Output must be fresh')
 for source in (game,texture):require(output!=source and output not in source.parents and source not in output.parents,'Output overlaps input')
 mix=(game/'DAT/L1_DC.MIX').read_bytes();require(sha(mix)=='6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345','Unsupported Cave archive')
 entries={e['key']:e for e in parse_mix(mix)}
 geo,raw=[mix[entries[k]['offset']:entries[k]['offset']+entries[k]['size']] for k in (2971673856,2971019266)]
 blob=texture.read_bytes();remap,binding=verify((game/'LOLG.DAT').read_bytes(),blob)
 out=output/'assets/lol2/generated/special_prop_review'
 off,count=u32(raw,8),u32(raw,0x40);so=off+count*55+4;fo=so+u32(raw,so-4)*16+4;state=frame=0;states={};chosen={50:474,51:475,52:476}
 for t in range(count):
  template=raw[off+t*55:off+(t+1)*55];n=template[46]+template[47]
  for selector in range(n):
   s=raw[so+state*16:so+(state+1)*16];c=struct.unpack_from('<b',s,13)[0]
   if t in chosen:
    f=raw[fo+frame*12:fo+(frame+1)*12];require(n==1 and c==1 and template[50]==0 and struct.unpack_from('<h',f)[0]==chosen[t],'State binding changed')
    states[t]=dict(descriptor=chosen[t],left=-s[14]/2+f[5],right=s[14]/2-f[7],bottom=f[8],top=s[15]-f[6],frame_flags=f[2],template_source_offset=off+t*55,state_source_offset=so+state*16,frame_source_offset=fo+frame*12,state_hex=s.hex(),frame_hex=f.hex())
   state+=1;frame+=1 if c<0 else c
 props=[]
 for k in range(u32(geo,0x60)):
  pos=u32(geo,0x14)+k*37;d=geo[pos:pos+37];t=struct.unpack_from('<H',d,32)[0]
  if t not in chosen:continue
  require(d[35]==0,'Nonzero placement selector');x,y,z=(struct.unpack_from('<h',d,o)[0] for o in (0,2,6))
  props.append(dict(record=k,template=t,region=struct.unpack_from('<H',d,10)[0],position_native=[x,z,-y],placement_source_offset=pos,placement_hex=d.hex(),**states[t]))
 require({v['record'] for v in props}=={1051,1057,1058},'Placement set changed')
 sections_=sections(blob);out.mkdir(parents=True)
 for k in chosen.values():
  v=struct.unpack_from('<6H11I',blob,sections_[2]+k*56);require(v[3]==0x28e and v[4]==1,'Unexpected sprite descriptor');w,h,pixels,_=decode_rows(blob[sections_[3]+v[7]:sections_[3]+v[7]+v[12]],allow_special=True)
  Image.frombytes('L',(w,h),pixels).save(out/f'sprite_{k}.png')
 Image.frombytes('L',(256,1),remap).save(out/'remap.png')
 report=dict(props=props,count=len(props),mix_sha256=sha(mix),cache_sha256=HASH,binding=binding,scope='Single-state/frame static table bindings and original positions/bounds. Fixed-Y billboard remains preview convention; no spawn, interaction, native lighting or draw-order parity. Templates82/86/87 deliberately outside this three-prop export.')
 (out/'props.json').write_text(json.dumps(report,indent=2)+'\n');print([(v['record'],v['descriptor'],v['left'],v['right'],v['top']) for v in props])

 out=output/'assets/lol2/generated/special_cave_review';out.mkdir(parents=True)
 s=sections(blob);v=struct.unpack_from('<6H11I',blob,s[2]+474*56)
 require(v[3]==0x28e and v[4]==1,'Descriptor changed')
 w,h,indices,_=decode_rows(blob[s[3]+v[7]:s[3]+v[7]+v[12]],allow_special=True)
 Image.frombytes('L',(w,h),indices).save(out/'sprite_474.png');Image.frombytes('L',(256,1),remap).save(out/'remap.png')
 (out/'manifest.json').write_text(json.dumps(dict(descriptor=474,width=w,height=h,special_pixels=indices.count(1),indices_sha256=sha(indices),binding=binding,scope='Original pixels and initial remap; diagnostic placement, scale and overlap are not native placement evidence.'),indent=2)+'\n')

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ('game','texture','output-root'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args()
 try:prepare(a.game.resolve(),a.texture.resolve(),a.output_root.resolve())
 except (ValueError,OSError,KeyError,IndexError,struct.error) as error:p.error(str(error))
if __name__=='__main__':main()
