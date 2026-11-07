#!/usr/bin/env python3
"""Functional paletted VPTR decoder from LOLG.DAT 17D3D4–17D858.

Zero in transparent commands leaves the destination unchanged. Runs cannot cross
block rows in this source format. Codebook entries are 4x4 palette indices.
"""
import struct


def decode_vectors(source, codebook, width, height, destination=None):
    assert width%4 == height%4 == 0
    out = bytearray(destination if destination is not None else bytes(width*height))
    assert len(out) == width*height and len(codebook)%16 == 0
    cursor = block = 0
    columns = width//4
    total = columns*(height//4)
    def word():
        nonlocal cursor
        assert cursor+2 <= len(source), 'Truncated vector command'
        value = struct.unpack_from('<H',source,cursor)[0]
        cursor += 2
        return value
    def emit(data, count=1, transparent=False):
        nonlocal block
        assert 0 < count <= columns-block%columns and block+count <= total, 'Vector run outside row'
        for _ in range(count):
            x, y = (block%columns)*4, (block//columns)*4
            for row in range(4):
                for col in range(4):
                    value = data[row*4+col]
                    if value or not transparent: out[(y+row)*width+x+col] = value
            block += 1
    def entry(index):
        assert index*16+16 <= len(codebook), 'Vector outside codebook'
        return codebook[index*16:index*16+16]
    while block < total:
        command = word()
        if command < 0x8000:
            emit(entry(command))
            continue
        kind, value = command>>12, command&0xfff
        if kind == 0xa:
            repeated = word()
            if repeated < 0x8000: emit(entry(repeated),value)
            elif repeated&0xc000 == 0x8000: emit(bytes([repeated&255])*16,value,True)
            else: emit(entry(repeated&0xfff),value,True)
        elif kind == 0xb:
            emit(bytes([value&255])*16,value>>8,True)
        elif kind == 0xc:
            assert value%2 == 0, 'Odd paired-color run'
            for _ in range(value//2):
                pair = word()
                emit(bytes([pair>>8])*16,transparent=True)
                emit(bytes([pair&255])*16,transparent=True)
        elif kind == 0xe: emit(entry(value),transparent=True)
        elif kind == 0xf: emit(bytes([value&255])*16,transparent=True)
        else: raise ValueError(f'Unsupported vector command {command:04x}')
    assert cursor == len(source), ('Trailing vector data',cursor,len(source))
    return bytes(out)
