#!/usr/bin/env python3
"""Original 0x66AB0 CPU execution with explicit table/local/context inputs.

Requires Unicorn only to regenerate vectors. No original game process or renderer.
Opcode dispatch tables are relocated from pinned LE fixup records, not raw dwords.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_32
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EIP, UC_X86_REG_ESP

ROOT = Path(__file__).resolve().parents[1]

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--exe", type=Path, required=True)
    p.add_argument("--out", type=Path, default=ROOT / "tests/act2_predicate_vectors.json")
    a = p.parse_args()
    exe = a.exe.read_bytes()
    assert hashlib.sha256(exe).hexdigest() == "b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775"
    # Actor opcode13 arm4 dispatch and its call into the existing selector.
    for at, raw in {
        0x4e0a0: "07105802020bd40400",
        0xdd42f: "31f86a008a4705508b732853ff96b000000083c40c66c7437c0000b801000000",
        0x7edcc: "0710800902a0ed0400",
    }.items():
        assert exe[at:at+len(bytes.fromhex(raw))] == bytes.fromhex(raw), hex(at)
    fixups = []
    vm = Uc(UC_ARCH_X86, UC_MODE_32)
    vm.mem_map(0, 0x1000000)
    vm.mem_write(0x66ab0, exe[0x9dab0:0x9dcc0])
    for i in range(24):
        at = 0x3ef08 + i*7
        rec = exe[at:at+7]
        assert rec[:2] == b"\x07\x00" and rec[4] == 2
        slot = 0xd000 + int.from_bytes(rec[2:4], "little")
        target = 0x59024 + int.from_bytes(rec[5:], "little")
        assert slot == 0xda2c + i*4
        vm.mem_write(slot, struct.pack("<I", target))
        fixups.append(dict(file_offset=at, raw=rec.hex(), slot=slot, target=target))
    for cell, ptr in [(0x2b548,0x100000),(0x26e54,0x110000),(0x26e58,0x120000),(0xb7d80,0x130000)]:
        vm.mem_write(cell, struct.pack("<I", ptr))
    def execute(table, index, local, shared, context):
        vm.mem_write(0x100000, bytes.fromhex("".join(table)))
        vm.mem_write(0x110000, bytes(local))
        vm.mem_write(0x120000, bytes(shared))
        vm.mem_write(0x130025, bytes([context]))
        vm.mem_write(0x200000, struct.pack("<II",0xff0000,index))
        vm.reg_write(UC_X86_REG_ESP,0x200000)
        vm.emu_start(0x66ab0,0xff0000,count=10000)
        assert vm.reg_read(UC_X86_REG_EIP)==0xff0000
        return vm.reg_read(UC_X86_REG_EAX)
    vectors=[]
    for op in range(8):
        for left,right in [(0,0),(0,1),(1,0),(1,1),(3,9),(9,3),(255,1)]:
            table=[bytes([op,3,0,2,0]).hex()]
            vectors.append(dict(table=table,index=0,local=[left],shared=[right],context=9,expected=execute(table,0,[left],[right],9)))
    # Nested expressions, both recursive sides, and owner-state inequality.
    table=["0003000000","0105000009","0604000401","0704000401"]
    for local in [0,1]:
        for context in [0,9]:
            for index in [2,3]:
                vectors.append(dict(table=table,index=index,local=[local],shared=[0],context=context,expected=execute(table,index,[local],[0],context)))
    # Every supported operand type on both sides, including literal nonzero values.
    for kind in [0,2,3,4,5]:
        table=[bytes([0,kind,1,kind,1]).hex(),"0000070007"]
        vectors.append(dict(table=table,index=0,local=[0,7],shared=[0,7],context=7,expected=execute(table,0,[0,7],[0,7],7)))
    a.out.write_text(json.dumps(dict(scope="Original predicate instructions under explicit emulator inputs; not full-game runtime evidence",exe_sha256=hashlib.sha256(exe).hexdigest(),fixups=fixups,vectors=vectors),indent=2)+"\n")
    print("PASS original CPU predicate vectors:",len(vectors))

if __name__ == "__main__": main()
