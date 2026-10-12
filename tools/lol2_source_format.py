"""Shared, standard-library-only LoL2 archive and command framing.

Moved from the project RE readers without changing their accepted formats.
SIZES describes command framing, not execution or gameplay semantics.
Original game data is supplied locally and is not bundled here.
"""
import struct

def u32(b,o): return struct.unpack_from('<I',b,o)[0]

def parse_mix(b):
    if len(b)<6: raise ValueError('Truncated MIX header')
    count,total=struct.unpack_from('<HI',b)
    base=6+12*count
    if base>len(b) or base+total!=len(b): raise ValueError('MIX size mismatch')
    entries=[]
    for i in range(count):
        key,off,size=struct.unpack_from('<III',b,6+12*i)
        if off+size>total: raise ValueError('Entry exceeds MIX data')
        entries.append(dict(index=i,key=key,offset=base+off,size=size))
    spans=sorted((e['offset'],e['offset']+e['size']) for e in entries)
    if any(a[1]>c[0] for a,c in zip(spans,spans[1:])): raise ValueError('Overlapping MIX entries')
    return entries

SIZES = {0: 4, 1: 6, 2: 6, 3: 12, 5: 6, 6: 6, 7: 6, 8: 8, 9: 6,
         11: 8, 12: 6, 13: 8, 14: 8, 15: 8, 16: 6, 17: 6, 18: 18,
         19: 10, 20: 10, 21: 6, 22: 18, 23: 6, 24: 10, 196: 12,
         197: 6, 198: 6, 199: 6, 200: 6, 201: 6, 204: 8, 205: 8,
         206: 6, 207: 6, 208: 8, 209: 10, 210: 6, 240: 6}
