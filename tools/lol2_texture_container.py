"""Bounded texture-container decompression using the system liblzo2.

Shared implementation moved unchanged from map_materials; accepts a validated
MIX entry and returns bytes plus block provenance. No extraction workspace.
"""
import ctypes, ctypes.util, hashlib, struct
MAX_DECOMPRESSED = 64 * 1024 * 1024
LZO_BLOCK = 1024 * 1024
def require(condition, message):
    if not condition: raise ValueError(message)
def sha256_hex(data):
    return hashlib.sha256(data).hexdigest()

def decode_lzo_container(mix: bytes, entry: dict) -> tuple[bytes, dict]:
    """Bounded liblzo2 decode of one MIX entry into its material-container blob."""
    library = ctypes.util.find_library('lzo2')
    require(bool(library), 'liblzo2 is required')
    lib = ctypes.CDLL(library)
    fn = lib.lzo1x_decompress_safe
    fn.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p,
                   ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p]
    fn.restype = ctypes.c_int

    raw = mix[entry['offset']:entry['offset'] + entry['size']]
    require(len(raw) >= 4, 'entry truncated before size header')
    total = struct.unpack_from('<I', raw)[0]
    require(0 < total <= MAX_DECOMPRESSED, 'decompressed size out of bounds')
    output = bytearray()
    cursor = 4
    blocks = []
    while len(output) < total:
        require(cursor + 4 <= len(raw), 'truncated block header')
        size = struct.unpack_from('<I', raw, cursor)[0]
        cursor += 4
        require(0 < size <= len(raw) - cursor, 'block size out of bounds')
        src = ctypes.create_string_buffer(raw[cursor:cursor + size])
        dst = ctypes.create_string_buffer(LZO_BLOCK)
        n = ctypes.c_size_t(len(dst))
        code = fn(src, size, dst, ctypes.byref(n), None)
        expected = min(LZO_BLOCK, total - len(output))
        require(code == 0 and n.value == expected, f'lzo1x_decompress_safe failed (code={code})')
        blocks.append(dict(offset=cursor, compressed=size, decoded=n.value))
        output.extend(dst.raw[:n.value])
        cursor += size
    require(raw[cursor:] == bytes(4) and len(raw) - cursor == 4, 'unexpected trailer after blocks')
    require(len(output) == total, 'decoded size mismatch')
    return bytes(output), dict(entry_index=entry['index'], entry_key=entry['key'],
                                entry_offset=entry['offset'], entry_size=entry['size'],
                                total=total, blocks=blocks, decoded_sha256=sha256_hex(output))
