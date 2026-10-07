"""Movie lookup metadata helpers moved unchanged from the project RE tools.

Header identification does not validate compressed movie data. The VQA decoder
performs that validation separately before playback assets are generated.
"""
import struct

def parse_vqhd(chunk_data):
    """Parse a VQHD (VQA Header) chunk, return dict of fields."""
    if len(chunk_data) < 24:
        return {"raw": list(chunk_data)}
    return {
        "version":    struct.unpack_from("<H", chunk_data, 0)[0],
        "flags":      struct.unpack_from("<H", chunk_data, 2)[0],
        "num_frames": struct.unpack_from("<H", chunk_data, 4)[0],
        "width":      struct.unpack_from("<H", chunk_data, 6)[0],
        "height":     struct.unpack_from("<H", chunk_data, 8)[0],
        "block_w":    chunk_data[10],
        "block_h":    chunk_data[11],
        "frame_rate": chunk_data[12],
        "cbparts":    chunk_data[13],
        "colors":     struct.unpack_from("<H", chunk_data, 14)[0],
        "max_blocks": struct.unpack_from("<H", chunk_data, 16)[0],
    }

def ww_hash_v1(name: str) -> int:
    """TD/RA era hash (xcc variant).

    Inner index advances only when i < len, so excess iterations within
    the 4-byte packing loop re-read nothing (a >>= 8 drains to zero).
    """
    name = name.upper()
    i = 0
    id_val = 0
    l = len(name)
    while i < l:
        a = 0
        for j in range(4):
            a = (a >> 8) & 0xFFFFFFFF
            if i < l:
                a |= ord(name[i]) << 24
                i += 1
        id_val = ((id_val << 1) | (id_val >> 31)) & 0xFFFFFFFF
        id_val = (id_val + a) & 0xFFFFFFFF
    return id_val


def parse_vqa_chunks(edata):
    """Parse all IFF chunks from a FORM/WVQA entry. Returns list of (chunk_id, chunk_data)."""
    if len(edata) < 12 or edata[:4] != b'FORM' or edata[8:12] != b'WVQA':
        return None

    form_size = struct.unpack_from(">I", edata, 4)[0]
    chunks = []
    pos = 12
    while pos + 8 <= len(edata):
        chunk_id = edata[pos:pos+4]
        chunk_size = struct.unpack_from(">I", edata, pos+4)[0]
        chunk_data = edata[pos+8:pos+8+chunk_size]
        chunks.append((chunk_id, chunk_data))
        pos += 8 + chunk_size
        if chunk_size % 2:
            pos += 1  # IFF padding to even boundary
    return chunks
