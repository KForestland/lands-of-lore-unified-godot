"""Shared creature metadata and indexed-sprite readers.

Moved from the project RE helpers, preserving parsing and validation semantics.
No fixture paths, image writing, native emulators or game files are imported.
"""
import struct

def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)

def partition_entities(records, table):
    require(len(records) % 147 == 0, 'Partial entity record')
    rows = []
    cursor = 0
    for i in range(len(records) // 147):
        record = records[i*147:(i+1)*147]
        require(b'\0' in record[135:], 'Unterminated entity name')
        name = record[135:].split(b'\0', 1)[0].decode('ascii')
        offset = struct.unpack_from('<I', record, 55)[0]
        count = record[46]
        require(offset == cursor and offset + count*4 <= len(table), 'Table partition')
        entries = [list(table[offset+j*4:offset+(j+1)*4]) for j in range(count)]
        rows.append(dict(record=i, name=name, table_offset=offset, entry_count=count,
                         byte47=record[47], entries_bytes=entries))
        cursor += count*4
    require(cursor == len(table), 'Unconsumed table bytes')
    return rows

def extent(raw, offset, count, stride, label):
    require(0 <= offset <= len(raw) and 0 <= count <= (len(raw)-offset)//stride,
            f'{label} extent')
    return raw[offset:offset+count*stride]

def parse_states(raw):
    require(len(raw) >= 0x50, 'Truncated header')
    entity_offset, table_offset = struct.unpack_from('<II', raw, 0x10)
    count, table_size = struct.unpack_from('<II', raw, 0x48)
    require(table_offset + table_size == entity_offset, 'Table/entity boundary')
    records = extent(raw, entity_offset, count, 147, 'Entity')
    table = extent(raw, table_offset, table_size, 1, 'Four-byte table')
    entities = partition_entities(records, table)
    state_count_offset = entity_offset + len(records)
    ns = struct.unpack('<I', extent(raw, state_count_offset, 1, 4, 'State count'))[0]
    state_start = state_count_offset + 4
    states = extent(raw, state_start, ns, 16, 'State')
    frame_count_offset = state_start + len(states)
    nf = struct.unpack('<I', extent(raw, frame_count_offset, 1, 4, 'View count'))[0]
    frame_start = frame_count_offset + 4
    views = extent(raw, frame_start, nf, 12, 'View')
    si = vi = 0
    for entity in entities:
        entity['source_offset'] = entity_offset + entity['record']*147
        entity['raw_hex'] = records[entity['record']*147:(entity['record']+1)*147].hex()
        entity['states'] = []
        # A1D7B..A1D89 sums both bytes here; only byte46 counts the separate table.
        for selector in range(entity['entry_count'] + entity['byte47']):
            require(si < ns, 'Entity state partition overrun')
            state = states[si*16:(si+1)*16]
            signed_count = struct.unpack_from('<b', state, 13)[0]
            n = 1 if signed_count < 0 else signed_count
            require(vi+n <= nf, 'State view partition overrun')
            refs = []
            for slot in range(n):
                frame = views[(vi+slot)*12:(vi+slot+1)*12]
                refs.append(dict(slot=slot, record=vi+slot, source_offset=frame_start+(vi+slot)*12,
                                 resource_reference=struct.unpack_from('<h', frame)[0],
                                 flags_byte2=frame[2], raw_hex=frame.hex()))
            entity['states'].append(dict(selector=selector, record=si,
                source_offset=state_start+si*16, raw_hex=state.hex(),
                signed_view_count=signed_count, view_first=vi, views=refs))
            si += 1
            vi += n
    require(si == ns and vi == nf, 'Unconsumed state/view records')
    return dict(entity_offset=entity_offset, entity_count=count, state_count_offset=state_count_offset,
                state_offset=state_start, state_count=ns, view_count_offset=frame_count_offset,
                view_offset=frame_start, view_count=nf, end_offset=frame_start+len(views), entities=entities)

def read_events(raw, offset, count, first):
    require(0 <= first < count and 0 <= offset <= len(raw) and count <= (len(raw)-offset)//8, 'Event table extent/index')
    result=[]
    for index in range(first,count):
        row=raw[offset+index*8:offset+(index+1)*8]
        if row[0] == 0:
            return result,index
        result.append(dict(record=index,source_offset=offset+index*8,kind=row[0],frame=row[1],
                           value_word=struct.unpack_from('<H',row,2)[0],raw_hex=row.hex()))
    raise ValueError('Unterminated frame-event list')

def lcw(src):
    out=bytearray();pos=0
    def take(n):
        nonlocal pos
        require(pos+n<=len(src),'Truncated LCW command')
        data=src[pos:pos+n];pos+=n;return data
    while pos<len(src):
        cmd=take(1)[0]
        if cmd==0x80:
            require(pos==len(src),'LCW trailing bytes')
            return bytes(out)
        if cmd&0xc0==0x80:out.extend(take(cmd&63))
        elif cmd==0xfe:
            n=struct.unpack('<H',take(2))[0];out.extend(take(1)*n)
        else:
            if cmd<0x80:
                n=(cmd>>4)+3;ref=len(out)-(((cmd&15)<<8)|take(1)[0])
            else:
                n=struct.unpack('<H',take(2))[0] if cmd==0xff else (cmd&63)+3
                ref=struct.unpack('<H',take(2))[0]
            require(0<=ref<len(out),'Invalid LCW reference')
            for j in range(n):out.append(out[ref+j])
        require(len(out)<=1048576,'LCW output limit')
    raise ValueError('Missing LCW terminator')

def decode_blocks(data,codebook):
    require(len(data)>=24 and len(codebook)%16==0,'Block header/codebook extent')
    flags,w,h,size=struct.unpack_from('<4H',data)
    require(flags==0x1246 and size==len(data)-22,'1246 size convention')
    require(w%4==0 and h%4==0 and 0<w//4<256,'Block dimensions')
    first,last=data[22:24]
    require(first<=last<h//4,'Block row range')
    table_end=24+2*(last-first+1)
    require(table_end<=len(data),'Row table extent')
    pixels=bytearray(w*h);used=set();ends=[]
    for row in range(first,last+1):
        rel=struct.unpack_from('<H',data,24+2*(row-first))[0]
        if rel==0:continue
        pos=24+rel;require(table_end<=pos<len(data),'Row pointer')
        start=pos;x=0
        while x<w//4:
            require(pos+2<=len(data),'Row command extent')
            op,n=data[pos:pos+2];pos+=2
            require(n>0 and x+n<=w//4,'Block run extent')
            if op:
                require(pos+2*n<=len(data),'Block indices extent')
                for j in range(n):
                    index=struct.unpack_from('<H',data,pos)[0];pos+=2
                    require(index*16+16<=len(codebook),'Codebook index')
                    used.add(index)
                    for y in range(4):
                        offset=(row*4+y)*w+(x+j)*4
                        pixels[offset:offset+4]=codebook[index*16+y*4:index*16+y*4+4]
            x+=n
        ends.append((start,pos))
    # Referenced row streams must be contiguous; report unused record tails.
    cursor=table_end
    for start,end in sorted(set(ends)):
        require(start==cursor,'Row stream gap/overlap');cursor=end
    require(cursor<=len(data),'Frame stream extent')
    return w,h,bytes(pixels),len(used),len(data)-cursor

def decode_rows(data, expected_flags=0x28e, allow_special=False):
    flags,w,h,size=struct.unpack_from('<4H',data)
    require(flags==expected_flags and size==len(data)-8,'Unexpected sprite header')
    pixels=bytearray(w*h);pos=8;marked=0
    for y in range(h):
        require(pos+4<=len(data),'Truncated row header')
        control,n=struct.unpack_from('<HH',data,pos);pos+=4
        require(allow_special or not control&0x8000,'Unsupported row flag')
        x=control&0x3fff
        require(x+n<=w and pos+n<=len(data),'Row extent')
        row=data[pos:pos+n];pos+=n
        require(bool(control&0x4000)==(0 in row),'Transparency hint mismatch')
        if allow_special:require(bool(control&0x8000)==(1 in row),'Special pixel hint mismatch')
        marked+=bool(control&0x4000);pixels[y*w+x:y*w+x+n]=row
    require(pos==len(data),'Trailing sprite bytes')
    return w,h,bytes(pixels),marked

def group_frames(descriptors):
    groups={}
    for ordinal,v in descriptors.items():
        count,index=v[4]&255,v[4]>>8
        require(0<=index<count,'Invalid group ordinal')
        base=ordinal-index
        groups.setdefault(base,[]).append((index,ordinal,v))
    result=[]
    for base,rows in sorted(groups.items()):
        rows.sort();first=rows[0][2];count=first[4]&255
        require([r[0] for r in rows]==list(range(count)),'Incomplete group')
        for index,ordinal,v in rows:
            require(ordinal==base+index and v[0]==first[0]+index,'Resource sequence')
            require(v[1:4]==first[1:4] and v[6]==first[6] and v[4]&255==count,'Group identity mismatch')
        result.append(dict(base=base,count=count,name_hash_candidate=first[6],frames=[r[1] for r in rows]))
    return result

def sections(blob: bytes) -> tuple[int, ...]:
    require(len(blob) >= 8, "missing blob header")
    count = struct.unpack_from("<I", blob)[0]
    require(4 <= count <= 256 and 8 + 4 * count <= len(blob), "bad section count")
    offsets = struct.unpack_from("<" + "I" * count, blob, 8)
    require(all(v == 0 or 8 + 4 * count <= v <= len(blob) for v in offsets),
                  "section outside named blob")
    return offsets

def rgb_palette(dac: bytes, bits: int) -> bytes:
    require(len(dac) == 768 and bits in (6, 8), "unsupported palette")
    maximum = (1 << bits) - 1
    require(max(dac) <= maximum, "palette exceeds DAC range")
    return bytes((value * 255 + maximum // 2) // maximum for value in dac)
