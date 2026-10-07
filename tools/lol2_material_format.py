"""Portable material descriptors, palette/PNG encoding and shade-table readers.

Extracted from the existing verified readers without changing format semantics.
"""
import hashlib
import struct
import zlib

def require(condition, message):
    if not condition:
        raise ValueError(message)

def sha(data):
    return hashlib.sha256(data).hexdigest()

REMAP_ROW = 64
REMAP_BYTES = 256

def sections(blob: bytes) -> tuple[int, ...]:
    require(len(blob) >= 8, "missing blob header")
    count = struct.unpack_from("<I", blob)[0]
    require(4 <= count <= 256 and 8 + 4 * count <= len(blob), "bad section count")
    offsets = struct.unpack_from("<" + "I" * count, blob, 8)
    require(all(v == 0 or 8 + 4 * count <= v <= len(blob) for v in offsets),
                  "section outside named blob")
    return offsets

def material_record(blob: bytes, index: int, *, allow_partial_mips: bool = False) -> dict:
    offsets = sections(blob)
    table, payload = offsets[2], offsets[3]
    require(table > 0 and payload > table and (payload - table) % 56 == 0,
                  "unsupported descriptor table extent")
    count = (payload - table) // 56
    require(0 <= index < count, "descriptor index outside table")
    position = table + index * 56
    values = struct.unpack_from("<6H11I", blob, position)
    identifier, width, height, flags, field8, field10 = values[:6]
    name_hash_candidate = values[6]
    mip_offsets, mip_sizes = values[7:12], values[12:17]
    require(flags == 0xA9, "this extractor supports only witnessed 0xA9 records")
    require(width > 0 and height > 0, "zero material dimension")
    payload_end = min((v for v in offsets if v > payload), default=len(blob))
    mips = []
    active_levels = 5
    if allow_partial_mips:
        active_levels = sum(size != 0 for size in mip_sizes)
        require(1 <= active_levels <= 5, "empty mip chain")
        require(all(mip_sizes[k] > 0 for k in range(active_levels)) and
                      all(mip_sizes[k] == mip_offsets[k] == 0 for k in range(active_levels, 5)),
                      "mip chain has holes or nonzero unused offsets")
        require((field10 & 255) == active_levels, "mip count field mismatch")
    for level, (relative, size) in enumerate(zip(mip_offsets, mip_sizes)):
        if level >= active_levels:
            break
        start = payload + relative
        require(size >= 8 and payload <= start and start + size <= payload_end,
                      "mip outside payload section")
        mip_flags, w, h, length16 = struct.unpack_from("<4H", blob, start)
        require(mip_flags == flags, "descriptor/mip flags mismatch")
        require((w, h) == (max(1, width >> level), max(1, height >> level)),
                      "descriptor/mip dimensions mismatch")
        require(size == 8 + w * h and length16 == (w * h) & 0xFFFF,
                      "mip byte extent mismatch")
        mips.append(dict(level=level, start=start, data_start=start + 8,
                         width=w, height=h, record_size=size,
                         stored_length16=length16,
                         pixels_sha256=sha(blob[start + 8:start + size])))
    return dict(index=index, descriptor_start=position, descriptor_count=count,
                identifier=identifier, width=width, height=height, flags=flags,
                field8=field8, field10=field10, name_hash_candidate=name_hash_candidate,
                payload_section_start=payload, mips=mips)

def rgb_palette(dac: bytes, bits: int) -> bytes:
    require(len(dac) == 768 and bits in (6, 8), "unsupported palette")
    maximum = (1 << bits) - 1
    require(max(dac) <= maximum, "palette exceeds DAC range")
    return bytes((value * 255 + maximum // 2) // maximum for value in dac)

def colorize(indices: bytes, rgb: bytes) -> bytes:
    require(len(rgb) == 768, "RGB palette must have 256 entries")
    return b"".join(rgb[value * 3:value * 3 + 3] for value in indices)

def png_rgb(width: int, height: int, pixels: bytes) -> bytes:
    require(width > 0 and height > 0 and len(pixels) == width * height * 3,
                  "invalid RGB image extent")
    def chunk(kind, content):
        return struct.pack(">I", len(content)) + kind + content + struct.pack(">I", zlib.crc32(kind + content))
    rows = b"".join(b"\0" + pixels[y * width * 3:(y + 1) * width * 3] for y in range(height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))

def column_major_to_rows(data,width,height):
 require(len(data)==width*height,'Pixel extent mismatch')
 return bytes(data[x*height+y] for y in range(height) for x in range(width))

def initial_remap_row(blob: bytes, source_sha256: str) -> bytes:
    """Shade row 64 (sections[4] + 0x4000, 256 bytes).

    Caller pins the blob sha256. The row must sit inside the shade section
    (the next section offset when present, otherwise the blob end).
    """
    digest = hashlib.sha256(blob).hexdigest()
    require(digest == source_sha256, 'texture blob hash does not match caller pin')
    offsets = sections(blob)
    require(len(offsets) > 4 and offsets[4] > 0, 'shade section missing')
    start = offsets[4] + REMAP_ROW * REMAP_BYTES
    end = start + REMAP_BYTES
    shade_end = offsets[5] if len(offsets) > 5 and offsets[5] else len(blob)
    require(offsets[4] <= start and end <= shade_end <= len(blob),
             'initial remap row outside shade section')
    return blob[start:end]
