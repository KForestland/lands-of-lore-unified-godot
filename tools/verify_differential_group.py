#!/usr/bin/env python3
"""W8 differential script test (WORKFLOW_PLAN 2026-10-31): run an Act 1 group's opcode handlers in the ORIGINAL code (the bounded
native harness, ~/opus_work/prop223_native_20261017/native_harness.py: real LOLG.DAT functions copied instruction by
instruction, outside calls stubbed) on a synthetic object, and write the resulting object bytes as a receipt the Godot test
(tests/differential_group_test.gd) diffs against the host's staged fields for the same commands.

Case A: L7_DH door 57, group 13798's opcode 5 `052039000300` -> movable/control slot +0xB0 = 0x5D510(object, byte 4, byte 5):
        byte 5 == 0 stores byte 4 at object +0x3D (the host's selector_0x3d).
Case B: L7_DH door 57, group 13798's opcode 1 `012039006400` -> slot +0xAC = 0x63DAC(object, command): mode 6 (sar 24 of +0x50)
        stores (word +0x4E * byte 4) / 100 into the low word at +0x50 (the host's travel_0x50; 21845 for 100 %).
Usage: verify_differential_group.py --out docs/differential_group_receipt.json
"""
import argparse, json, struct, sys, tempfile
from pathlib import Path
sys.path.insert(0, '~/opus_work/prop223_native_20261017')
import native_harness as N

OBJ = 0xC000          # object image at region offset
CMD = 0xC200          # command bytes
AUX = 0xC400          # zeroed buffer the object's +0x2C points at (the selector path reads a count through it)
REAL = {'op5_movable': 0x5D510, 'op1_movable': 0x63DAC}


def run(out):
    # Addresses the handlers push to callees the harness stubs (0x23C68 the 0xE3924 sound request, 0xB7D70 / 0xB7D6C the list heads of
    # 0xB3B04 / 0xB3AC4 on the opcode-1 not-equal path) and the masks they use.
    h = N.Harness(REAL, cuts={}, tables={}, address_immediates=(0x23c68, 0xb7d70, 0xb7d6c), constants=(0x64, 0xffff, 0x20000000))
    region = bytearray(N.REGION_SIZE)
    obj = N.REGION + OBJ
    # Object image: mode 6 in the high byte of dword +0x50 (byte +0x53), word +0x4E = 21845 (the door's angle word), +0x3D = 0.
    region[OBJ + 0x53] = 6
    struct.pack_into('<I', region, OBJ + 0x28, N.VT)   # the object's vtable: every slot call goes to a logged harness stub
    struct.pack_into('<I', region, OBJ + 0x2C, N.REGION + AUX)
    struct.pack_into('<H', region, OBJ + 0x4E, 21845)
    cmd1 = bytes.fromhex('012039006400')
    region[CMD:CMD + len(cmd1)] = cmd1
    cases = [('op5_movable', [obj, 3, 0, 0], bytes(region)), ('op1_movable', [obj, N.REGION + CMD, 0, 0], bytes(region))]
    with tempfile.TemporaryDirectory() as tmp:
        images = h.build_and_run(tmp, list(REAL), cases)
    a, b = images
    result = dict(version=1, harness=h.code_receipt(),
                  case_a=dict(group=13798, command='052039000300', entry='0x5D510', selector_0x3d=a[OBJ + 0x3D], return_eax=struct.unpack_from('<I', a, N.RESULT)[0]),
                  case_b=dict(group=13798, command='012039006400', entry='0x63DAC', travel_0x50=struct.unpack_from('<H', b, OBJ + 0x50)[0], mode_byte=b[OBJ + 0x53], return_eax=struct.unpack_from('<I', b, N.RESULT)[0]),
                  object=dict(mode=6, angle_word=21845, selector_before=0, stub_calls_a=struct.unpack_from('<I', a, N.LOGCOUNT)[0], stub_calls_b=struct.unpack_from('<I', b, N.LOGCOUNT)[0]),
                  scope='Native handler stores on a synthetic movable object; stubs logged; the host test compares its staged fields.')
    Path(out).write_text(json.dumps(result, indent=1) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'harness'}))
    print('stubs:', result['harness']['stubs'], 'instructions:', result['harness']['instructions'])


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--out', type=Path, default=Path('docs/differential_group_receipt.json'))
    run(p.parse_args().out)
