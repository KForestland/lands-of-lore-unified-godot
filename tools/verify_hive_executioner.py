#!/usr/bin/env python3
"""Recover executioner36/nest317 source links and bounded native state transitions.

This is evidence preparation, not a claim that native AI or activation is restored.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path

import capstone

import re_helper_root; re_helper_root.insert('draracle', 'tools')  # LOL2_RE_ROOT; same order as the former sys.path[:0] list
from lol2_extract_draracle_geometry import parse_mix, u32
from lol2_verify_draracle_slopes import EXE_HASH
from lol2_wall_material_checkpoint import sections
from lol2_westwood_hash import ww_hash_v1
from verify_creature_states import CreatureReplay
from verify_special_pixel_table_binding import fixups
from normalize_hourglass_vqa import chunks

GAME = Path('/home/bob/lol2_out/museum_capture_20260913/game')
OUT = Path('/home/bob/lol2_out/hive_geometry_20260914')
ARCHIVE_SHA = 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'


def verify():
    archive = (GAME / 'DAT/L5_HC.MIX').read_bytes()
    exe = (GAME / 'LOLG.DAT').read_bytes()
    assert hashlib.sha256(archive).hexdigest() == ARCHIVE_SHA
    assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    entries = parse_mix(archive)
    ge, me = [next(e for e in entries if e['key'] == key) for key in (3776990464, 3776335874)]
    geo, meta = [archive[e['offset']:e['offset'] + e['size']] for e in (ge, me)]
    progress = json.loads(Path('/home/bob/lol2_out/hive_progression_20260914/progression.json').read_text())
    assert progress['archive_sha256'] == ARCHIVE_SHA
    groups = {group['offset']: group for group in progress['streams'][1]['groups']}
    event_start = u32(geo, 0x40)
    event_blob = geo[event_start:event_start + u32(geo, 0x88)]

    def owner(kind, index, offset, stride):
        start = u32(geo, offset) + index * stride
        record = geo[start:start + stride]
        cursor = struct.unpack_from('<H', record, 12)[0]
        beginning, events = cursor, []
        while event_blob[cursor] and event_blob[cursor + 1]:
            size, event_kind = event_blob[cursor:cursor + 2]
            assert size >= 2 and cursor + size <= len(event_blob)
            payload = event_blob[cursor:cursor + size]
            following = event_blob[cursor + size:cursor + size + 4]
            row = dict(kind=event_kind, raw_hex=payload.hex(), source_offset=ge['offset'] + event_start + cursor,
                       predicate=int.from_bytes(following[2:4], 'little') if following[1:2] == b'\x13' else None)
            if event_kind in (2, 3, 4, 5, 6, 9, 10):
                group = int.from_bytes(payload[2:4], 'little')
                assert group in groups
                row['group'] = group
            events.append(row)
            cursor += size
        x, y, heading, z = struct.unpack_from('<hhHh', record)
        return dict(kind=kind, index=index, position=[x, z, -y], heading=heading,
                    source_offset=ge['offset'] + start, raw_hex=record.hex(), events=events,
                    event_list_hex=event_blob[beginning:cursor + 2].hex())

    nest = owner('prop', 317, 0x14, 37)
    actor = owner('actor', 36, 0x1c, 56)
    assert bytes.fromhex(nest['raw_hex'])[32:34] == bytes([42, 0])
    assert bytes.fromhex(actor['raw_hex'])[32] == 1
    assert [(r['group'], r['predicate']) for r in actor['events'] if r['kind'] == 10] == [(10618, 207), (10648, 208)]
    relevant = []
    for stream, value in enumerate(progress['streams']):
        for group in value['groups']:
            if any((c['kind'], c['target']) in [(3, 317), (2, 36)] for c in group['commands']):
                for command in group['commands']:
                    payload = bytes.fromhex(command['raw_hex'])
                    assert archive[command['source_offset']:command['source_offset'] + len(payload)] == payload
                relevant.append(dict(stream=stream, **group))
    approach = [r for r in progress['region_event_links'] if r['group'] in {6646, 6664, 6682, 6700, 6742, 6760}]
    assert len(approach) == 6 and all(r['event'] == 2 and r['predicate'] == 26 for r in approach)

    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = True
    ins, code = {}, []
    for start, end in [(0x66ab0, 0x66cc0), (0xadde0, 0xadf33),
                       (0xb6b6e, 0xb6b95), (0xb5a3c, 0xb5a4c), (0x64887, 0x6489f)]:
        raw = exe[start + 0x37000:end + 0x37000]
        rows = list(md.disasm(raw, start))
        assert rows[-1].address + rows[-1].size == end
        ins.update({i.address: i for i in rows})
        code.append(dict(start=start, end=end, sha256=hashlib.sha256(raw).hexdigest()))
    machine = CreatureReplay(ins, b'')
    stack, local, obj, predicates, listing, command_pointer, source_pointer, command_groups = [0x400000 + 0x10000 * i for i in range(8)]
    table = geo[u32(geo, 0xbc):u32(geo, 0xbc) + u32(geo, 0xb8) * 5]
    machine.mem[predicates:predicates + len(table)] = table
    for address, pointer in [(0x26e54, local), (0xb7d80, obj), (0x2b548, predicates), (0x2b514, command_groups)]:
        machine.writemem(address, 4, pointer)
    le = 0x39024 + u32(exe, 0x39060)
    first = u32(exe, le + u32(exe, le + 0x40) + 36)
    relocations = []
    for slot, target in [(0xda38, 0x66b15), (0xda40, 0x66b3b), (0xda4c, 0x66b77),
                         (0xda6c, 0x66c43), (0xda70, 0x66c57), (0x5c878 + 15 * 4, 0xb5a3c)]:
        relocation = fixups(exe, le, first - 1 + slot // 4096)[slot % 4096]
        assert relocation['target_object'] == 2 and relocation['target_offset'] + 0x59024 == target
        machine.writemem(slot, 4, target)
        relocations.append(dict(slot=slot, target=target))

    def predicate(ref, state, variable, at):
        machine.writemem(obj + 0x25, 1, state)
        machine.writemem(local + 9, 1, 255-variable)
        machine.writemem(local + 6, 1, 255-variable)
        raw = table[ref*5:ref*5+5]
        if raw[1] == 3:
            machine.writemem(local + raw[2], 1, variable)
        machine.regs.update(esp=at)
        machine.writemem(at + 4, 4, ref)
        stop = machine.execute(0x66ab0, {0x66c45, 0x66c59})
        return int((machine.regs['ebx'] == machine.regs['esi']) == (stop == 0x66c45))

    predicate_proof = []
    for ref in [26, 50, 54, 207, 208, 209, 210]:
        raw = table[ref * 5:ref * 5 + 5]
        assert raw[0] in (0, 1) and raw[1] in (3, 5) and raw[3] == 0
        accepted = []
        for value in range(256):
            state, variable = (value, 255 - value) if raw[1] == 5 else (255 - value, value)
            result = predicate(ref, state, variable, stack)
            assert result == int((value == raw[4]) == (raw[0] == 0))
            if result:
                accepted.append(value)
        predicate_proof.append(dict(reference=ref, raw_hex=raw.hex(),
                                    operand='owner_state_byte25' if raw[1] == 5 else f'local_byte{raw[2]}',
                                    accepted=accepted))
    scanner_proof = []
    machine.writemem(0x23331, 1, 5)
    for source in (nest, actor):
        raw = bytes.fromhex(source['event_list_hex'])
        machine.mem[listing:listing + len(raw)] = raw
        for state in [0, 1, 2, 3, 4, 255]:
            for event in range(256):
                machine.regs.update(esp=stack)
                machine.writemem(stack + 4, 4, listing)
                machine.writemem(stack + 8, 4, event)
                pc, queued = 0xadde0, []
                while True:
                    stop = machine.execute(pc, {0xade75, 0xade9a, 0xadea5, 0xadf32})
                    if stop == 0xadf32:
                        break
                    if stop == 0xade75:
                        ref = machine.readmem(machine.regs['esp'], 4)
                        registers = dict(machine.regs)
                        result = predicate(ref, state, 0, stack + 0x1000)
                        machine.regs.update(registers)
                        machine.regs['eax'] = result
                        pc = 0xade7a
                    elif stop == 0xade9a:
                        queued.append(machine.readmem(machine.regs['esp'], 4) - command_groups)
                        machine.regs['eax'] = 0
                        pc = 0xade9f
                    else:
                        machine.regs['eax'] = 5  # Explicit MOVSX for the supplied Hive level.
                        pc = 0xadea8
                expected = []
                for row in source['events']:
                    payload = bytes.fromhex(row['raw_hex'])
                    if row['kind'] == 6 and payload[4] == event:
                        ref = row['predicate']
                        if ref is None or predicate(ref, state, 0, stack + 0x1000):
                            expected.append(row['group'])
                assert queued == expected, (source['index'], state, event, queued, expected)
                if queued:
                    scanner_proof.append(dict(owner_kind=source['kind'], owner=source['index'], state=state, event=event, groups=queued))

    writes = []
    for group in relevant:
        for command in group['commands']:
            payload = bytes.fromhex(command['raw_hex'])
            if command['opcode'] not in [16, 198]:
                continue
            if command['opcode'] == 16 and (command['kind'], command['target']) not in [(3, 317), (2, 36)]:
                continue
            machine.mem[command_pointer:command_pointer + len(payload)] = payload
            for previous in range(256):
                if command['opcode'] == 16:
                    machine.writemem(source_pointer, 4, command_pointer)
                    machine.writemem(obj + 0x25, 1, previous)
                    machine.regs.update(eax=source_pointer, ebx=obj, ebp=stack, edx=0)
                    machine.execute(0xb6b6e, 0xb5947)
                    assert machine.readmem(obj + 0x25, 1) == payload[4]
                else:
                    machine.writemem(local + payload[4], 1, previous)
                    machine.regs.update(ebx=command_pointer, esp=stack, edx=0)
                    machine.execute(0x64887, 0x6489e)
                    assert machine.readmem(local + payload[4], 1) == payload[5]
            writes.append(dict(stream=group['stream'], group=group['offset'], raw_hex=payload.hex(), checks=256))

    # Independently partition the prop templates to retain both original nest movies.
    base, count = u32(meta, 8), u32(meta, 0x40)
    so = base + count * 55 + 4
    fo = so + u32(meta, so - 4) * 16 + 4
    si = fi = 0
    nest_states = []
    for index in range(count):
        template = meta[base + index * 55:base + (index + 1) * 55]
        for selector in range(template[46] + template[47]):
            state = meta[so + si * 16:so + (si + 1) * 16]
            views = struct.unpack_from('<b', state, 13)[0]
            num = 1 if views < 0 else views
            if index == 42:
                view = meta[fo + fi * 12:fo + (fi + 1) * 12]
                nest_states.append(dict(selector=selector, state_hex=state.hex(), view_hex=view.hex(),
                                        resource=struct.unpack_from('<h', view)[0]))
            si += 1
            fi += num
    blob = (OUT / 'texture.bin').read_bytes()
    assert hashlib.sha256(blob).hexdigest() == 'c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'
    section = sections(blob)
    movie_archive = (GAME / 'DAT/L5_HCI.MIX').read_bytes()
    movies = []
    for state, filename, label, frame_count in zip(nest_states[:2], ['ex07.vqa', 'ex08.vqa'],
                                                ['HOthr000EXNesting', 'HAppr000EXNestToAttack'], [36, 28]):
        descriptor = struct.unpack_from('<6H11I', blob, section[2] + state['resource'] * 56)
        payload = blob[section[3] + descriptor[7]:][:descriptor[12]]
        assert descriptor[3] == 0x342 and payload[8:].split(b'\0')[0].decode() == filename
        name = 'SPHERE1\\L5_HC\\' + filename.upper()
        entry = next(e for e in parse_mix(movie_archive) if e['key'] == ww_hash_v1(name))
        raw = movie_archive[entry['offset']:entry['offset'] + entry['size']]
        top = {kind: value for _, kind, value in chunks(raw, 12) if kind in [b'VQHD', b'LINF', b'LNIN']}
        assert struct.unpack_from('<HHH', top[b'VQHD'], 4) == (frame_count, 320, 200) and top[b'VQHD'][12] == 15
        lind = next(value for _, kind, value in chunks(top[b'LINF']) if kind == b'LIND')
        assert list(struct.iter_unpack('<HH', lind)) == [(0, frame_count - 1)]
        names = next(value for _, kind, value in chunks(top[b'LNIN']) if kind == b'LNID')
        assert names.split(b'\0')[0].decode() == label
        movies.append(dict(**state, filename=name, entry=entry, source_sha256=hashlib.sha256(raw).hexdigest(),
                           label=label, frames=frame_count, width=320, height=200, fps=15, payload_hex=payload.hex()))
    report = dict(archive_sha256=ARCHIVE_SHA, executable_sha256=EXE_HASH, code=code, relocations=relocations,
                  nest=nest, actor=actor, approach_regions=approach, groups=relevant,
                  predicates=predicate_proof, predicate_cases=len(predicate_proof) * 256,
                  scanner_cases=2 * 6 * 256, scanner_witnesses=scanner_proof,
                  writes=writes, writer_cases=len(writes) * 256, nest_states=nest_states,
                  movie_archive_sha256=hashlib.sha256(movie_archive).hexdigest(), movies=movies,
                  scope='Pinned source ownership and structural prop template/movie links. Native predicates exhausted over byte inputs; '
                  'ADDE0 kind6 scanner composed with native predicates for both full lists, all event bytes and six owner states. '
                  'Opcode16 state-byte and opcode198 local-byte writes replayed with supplied resolved owner and zero-extended dispatch context. '
                  'Queue bodies, event producers, initial activation, property5/8/9 behavior, kind9/kind10 acceptance, creature definition '
                  'lookup and native AI/damage/navigation are not established. No new encounter is enabled by this audit.')
    (OUT / 'executioner_verified.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f"Executioner/nest verified: {report['predicate_cases']} predicate, {report['scanner_cases']} scanner, {report['writer_cases']} writer cases; two named source movies")
    return report


if __name__ == '__main__':
    verify()
