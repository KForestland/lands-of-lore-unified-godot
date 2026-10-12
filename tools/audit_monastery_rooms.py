#!/usr/bin/env python3
"""Recover room DLL calls and original movie patches, without executing the DLLs."""
import hashlib
import json
import struct
import sys
from pathlib import Path
from build_game_atlas import ROOT, parse_mix, section
from audit_game_transition_owners import GAME, collect_owners
from audit_game_actor_scripts import groups
import re_helper_root
re_helper_root.insert('tools', 'draracle')  # LOL2_RE_ROOT (see re_helper_root.py)
from lol2_westwood_hash import ww_hash_v1
import capstone


PINNED = {'MENT': '82e11faf2a4922922048fe446d5b665c70612d709ad689a85fd59c91525478e4', 'MLIB': '507f68e917665df64430a1bac2ec5267af1597ace5aabf9218c86d9861044f94', 'MOFF': '642956adf4ee24c7bf3230ef7521ebcc419a9a076e4674692c8ba3bf63fc2a45'}


def digest(b):
    return hashlib.sha256(b).hexdigest()


def extract(archive, name):
    row = next(e for e in parse_mix(archive) if e['key'] == ww_hash_v1(name))
    data = archive[row['offset']:][:row['size']]
    return data, dict(row, name=name, sha256=digest(data))


def movie(archive, name):
    data, result = extract(archive, name)
    at = data.index(b'VQHD')
    header = data[at+8:at+8+42]
    frames, width, height = struct.unpack_from('<HHH', header, 4)
    x, y = struct.unpack_from('<HH', header, 18)
    result.update(frames=frames, width=width, height=height, fps=header[12], x=x, y=y)
    assert frames and width and height and result['fps'] == 15
    return result


def calls(image, start, end, slots):
    """Literal call arguments only; branches are retained in separate disassembly."""
    decoder = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    decoder.detail = True
    pushes = []
    result = []
    for i in decoder.disasm(image[start:end], start):
        if i.mnemonic == 'push':
            pushes.append(i.operands[0].imm if i.operands[0].type == capstone.x86.X86_OP_IMM else i.op_str)
        elif i.mnemonic == 'call':
            op = i.operands[0]
            if op.type == capstone.x86.X86_OP_MEM and op.mem.disp in slots:
                kind, count = slots[op.mem.disp]
                args = list(reversed(pushes[-count:]))
                assert len(args) == count and None not in args, (hex(i.address), args)
                result.append(dict(address=hex(i.address), kind=kind, args=args))
            pushes = []
    return result


def main():
    result = dict(version=1, method='Static DLL disassembly; literal calls are not a native execution trace.', rooms={})
    for room, start, end, slots in [
        ('MENT', 0x47c, 0x730, {}),
        ('MLIB', 0xb0e, 0xc64, {0x116c:('movie',3),0x1238:('movie_flags',4),0x1160:('set_flag',1)}),
        ('MOFF', 0xfe4, 0x1213, {0x1430:('movie',3),0x14fc:('movie_flags',4),0x1424:('set_flag',1),0x141c:('give_item',2)})]:
        archive = (GAME/'DAT'/f'{room}.MIX').read_bytes()
        assert digest(archive) == PINNED[room], 'Room archive differs from audited source'
        dll, source = extract(archive, f'WOMS\\{room}_.WOM')
        version, size, entry, count = struct.unpack_from('<4I', dll, 32)
        assert dll[:32] == b'This is a linear executable dll\n' and version == 257 and entry == 52
        assert len(dll) == 48+size+count*4
        image = dll[48:48+size]
        sequence = calls(image, start, end, slots)
        movies = [movie(archive, f'WOMS\\{room}\\{row["args"][0]:02d}{row["args"][1]:03d}{row["args"][2]:02d}E.VQA') for row in sequence if row['kind'].startswith('movie')]
        if room == 'MLIB':
            assert [r['args'][1] for r in sequence if r['kind'].startswith('movie')] == list(range(750,765))
            assert image[0x1061:].split(b'\0')[0] == b'Met_Dawn'
        if room == 'MOFF':
            assert [r['args'][1] for r in sequence if r['kind'].startswith('movie')] == list(range(351,359))+list(range(360,375))
            assert image[0x1363:].split(b'\0')[0] == b'94-Iron flute'
            assert [r['args'] for r in sequence if r['kind']=='give_item'] == [[0x1363,'ebx']]
            assert image[0x11be:0x11c8].hex() == '8b1d2015000085db751d' # grant branch requires ebx == 0
        decoder = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
        disassembly = [f'{i.address:04x} {i.mnemonic} {i.op_str}' for i in decoder.disasm(image[0x47c:start if start>0x47c else end],0x47c)]
        result['rooms'][room] = dict(archive_sha256=digest(archive), dll=source, image_size=size, relocations=count,
            background=movie(archive,f'WOMS\\{room}\\{room}_.VQA'), first_visit_calls=sequence,
            first_visit_movies=movies, setup_disassembly=disassembly)
    area = next(a for a in json.loads((ROOT/'docs/game-source-inventory.json').read_text())['areas'] if a['id']=='L4_HJ')
    archive = (GAME/area['source']['file']).read_bytes()
    assert digest(archive) == area['source']['sha256']
    entry = next(e for e in parse_mix(archive) if e['key']==area['source']['geometry_key'])
    raw = archive[entry['offset']:][:entry['size']]
    owners,_ = collect_owners(raw,entry['offset'],area['counts']['regions'])
    bound = [o for o in owners if o['owner_kind']=='region' and o['owner']==3148 and o['event']==2 and o['group']==5510]
    assert bound
    _,_,stream = section(raw,0x3c,0x84,1)
    commands = [d.hex() for _,d in dict(groups(stream))[5510]]
    assert '0c03ab010300' in commands
    geometry = json.loads(Path('/home/bob/lol2_out/jungle_geometry_20260914/geometry.json').read_text())
    region = geometry['regions'][3148]
    polygon = [[geometry['vertices_fixed'][v][0]/65536,-geometry['vertices_fixed'][v][1]/65536] for v in region['vertex_indices']]
    assert polygon == [[4164,2540],[4324,2190],[4364,2210],[4204,2560]]
    result['jungle_entry'] = dict(owners=bound,commands=commands,room_index=3,room='MENT',polygon=polygon,
        note='Opcode12 room selection matched to executable room-name table; functional interpretation, not native launch replay.')
    result['limits'] = ['Movie flag arguments 0x80/0xa0/0xe0 set temporary host flags; precise presentation effects remain unbound. See monastery-movie-callback.json.',
        'Library Dawn requires GV_MET_BACATTA and further absence checks; entering the library alone is insufficient.',
        'First-visit live room entry/movie composition/flute grant are integrated; Bacatta producer and Hive-to-flute route now work; later visits, rune/death branches and full Act1 remain open.']
    out = ROOT/'docs/monastery-room-source.json'
    out.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: 3 room DLLs, 3 backgrounds, 38 first-visit movie references; source report:',out)

if __name__ == '__main__':
    main()
