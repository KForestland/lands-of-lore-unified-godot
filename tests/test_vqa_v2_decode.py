"""Asset-free checks for tools/vqa_v2_decode.py (Python VQA v2 partial-codebook decoder).

Synthetic movies are built in memory: valid decoding (partial-codebook swap from the frame after the N-th part, solid
blocks, VQFL seek snapshots ignored in linear playback), partial_v2 classification, and explicit VQAError for every
malformed or unsupported input class. No original game data is used.
Run: python3 -m unittest tests/test_vqa_v2_decode.py
"""
import sys
import unittest
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import vqa_v2_decode as V

def lcw(data: bytes) -> bytes:
    """LCW literal-only encoding (0x81..0xBF runs) terminated by 0x80."""
    out = bytearray()
    for i in range(0, len(data), 63):
        part = data[i:i+63]
        out.append(0x80 | len(part)); out += part
    return bytes(out + b'\x80')

def chunk(tag: bytes, payload: bytes) -> bytes:
    return tag + len(payload).to_bytes(4, 'big') + payload + (b'\0' if len(payload) & 1 else b'')

def vqhd(frames=3, w=8, h=4, parts=2, version=2, bw=4, bh=4, size=42) -> bytes:
    hd = bytearray(size)
    hd[0:2] = version.to_bytes(2, 'little'); hd[4:6] = frames.to_bytes(2, 'little')
    hd[6:8] = w.to_bytes(2, 'little'); hd[8:10] = h.to_bytes(2, 'little')
    if size > 13: hd[10], hd[11], hd[12], hd[13] = bw, bh, 15, parts
    return bytes(hd)

def form(*chunks_: bytes) -> bytes:
    body = b'WVQA' + b''.join(chunks_)
    return b'FORM' + len(body).to_bytes(4, 'big') + body

def vpt(lo, hi) -> bytes:
    return lcw(bytes(lo) + bytes(hi))

PALETTE = bytes(v for i in range(256) for v in (i % 64, (i * 3) % 64, (63 - i) % 64))
OLD = bytes(range(0, 16)) + bytes(range(16, 32))           # 2 vectors
NEW = bytes(range(100, 116)) + bytes(range(116, 132))      # 2 vectors, assembled from 2 parts
NEW_STREAM = lcw(NEW)
PART1, PART2 = NEW_STREAM[:7], NEW_STREAM[7:]

def frame(*subs: bytes) -> bytes:
    return chunk(b'VQFR', b''.join(subs))

def movie(extra_top=b'', frame0=None, frame1=None, frame2=None, header=None) -> bytes:
    f0 = frame0 if frame0 is not None else frame(chunk(b'CPL0', PALETTE), chunk(b'CBFZ', lcw(OLD)), chunk(b'CBPZ', PART1), chunk(b'VPTZ', vpt([0, 1], [0, 0])))
    f1 = frame1 if frame1 is not None else frame(chunk(b'CBPZ', PART2), chunk(b'VPTZ', vpt([1, 7], [0, 0xFF])))
    f2 = frame2 if frame2 is not None else frame(chunk(b'VPTZ', vpt([0, 1], [0, 0])))
    return form(chunk(b'VQHD', header if header is not None else vqhd()), f0, extra_top, f1, f2)

def rgb(indices) -> np.ndarray:
    p = np.frombuffer(PALETTE, np.uint8).astype(np.uint16)
    pal = ((p << 2) | (p >> 4)).astype(np.uint8).reshape(-1, 3)
    return pal[np.array(indices, np.uint8)]

def blocks(*vectors) -> np.ndarray:
    """Place 4x4 vectors (16 palette indices each) left to right in one block row."""
    return np.concatenate([np.frombuffer(bytes(v), np.uint8).reshape(4, 4) for v in vectors], 1)

class ValidDecode(unittest.TestCase):
    def test_partial_codebook_swaps_after_last_part(self):
        out = list(V.frames(movie()))
        self.assertEqual(len(out), 3)
        np.testing.assert_array_equal(out[0], rgb(blocks(OLD[:16], OLD[16:])))
        # Frame1 carries the last part but still renders with the old codebook; vector1 old, block2 solid colour 7.
        np.testing.assert_array_equal(out[1], rgb(blocks(OLD[16:], [7] * 16)))
        np.testing.assert_array_equal(out[2], rgb(blocks(NEW[:16], NEW[16:])))

    def test_vqfl_seek_snapshot_is_ignored(self):
        snapshot = chunk(b'VQFL', chunk(b'CBFZ', lcw(bytes(32))) + chunk(b'CBPZ', b'\x80'))
        plain = list(V.frames(movie()))
        with_vqfl = list(V.frames(movie(extra_top=snapshot)))
        for a, b in zip(plain, with_vqfl): np.testing.assert_array_equal(a, b)

    def test_partial_v2_classification(self):
        self.assertTrue(V.partial_v2(movie()))
        no_partials = form(chunk(b'VQHD', vqhd(frames=1)), frame(chunk(b'CPL0', PALETTE), chunk(b'CBFZ', lcw(OLD)), chunk(b'VPTZ', vpt([0, 1], [0, 0]))))
        self.assertFalse(V.partial_v2(no_partials))
        # Other versions without partial codebooks are left to FFmpeg, not rejected.
        self.assertFalse(V.partial_v2(form(chunk(b'VQHD', vqhd(version=3, frames=1)), frame(chunk(b'VPTZ', b'\x80')))))

class Malformed(unittest.TestCase):
    def rejects(self, blob, text, fn=None):
        with self.assertRaises(V.VQAError) as ctx:
            (fn or (lambda b: list(V.frames(b))))(blob)
        self.assertIn(text, str(ctx.exception))

    def test_container(self):
        good = movie()
        self.rejects(b'RIFF' + good[4:], 'not an IFF FORM')
        self.rejects(good[:8] + b'AVI ' + good[12:], 'not WVQA')
        self.rejects(good[:4] + (len(good) * 2).to_bytes(4, 'big') + good[8:], 'FORM size')
        self.rejects(good[:-10], 'FORM size')
        truncated = form(chunk(b'VQHD', vqhd()))[:-4]
        self.rejects(truncated[:4] + (len(truncated) - 8).to_bytes(4, 'big') + truncated[8:], 'exceeds data')
        self.rejects(form(b'VQ\x00D' + (42).to_bytes(4, 'big') + vqhd()), 'invalid chunk tag')

    def test_missing_padding_and_frames(self):
        with self.assertRaisesRegex(V.VQAError, 'padding'):
            V.chunks(b'TEST' + (1).to_bytes(4, 'big') + b'x')
        unpadded = chunk(b'CBPZ', b'x')[:-1]
        self.rejects(movie(frame1=frame(unpadded)), 'padding', V.partial_v2)
        self.rejects(movie(header=vqhd(frames=4)), 'frame count', V.partial_v2)
        self.rejects(movie(header=vqhd(frames=4)), 'frame count')
        self.rejects(form(chunk(b'VQHD', vqhd(frames=1))), 'frame count', V.partial_v2)

    def test_header(self):
        self.rejects(form(frame(chunk(b'VPTZ', b'\x80'))), 'expected one VQHD')
        self.rejects(movie(header=vqhd(size=20)), 'VQHD is 20 bytes')
        self.rejects(movie(header=vqhd(version=3)), 'unsupported VQA version 3')
        self.rejects(movie(header=vqhd(bh=2)), 'unsupported block size 4x2')
        self.rejects(movie(header=vqhd(w=6)), 'invalid frame size')
        self.rejects(movie(header=vqhd(parts=0)), 'part count is 0')
        self.rejects(movie(header=vqhd(frames=2)), 'does not match VQHD frame count')
        self.rejects(movie(header=vqhd(version=3)), 'unsupported VQA version', V.partial_v2)

    def test_frame_contents(self):
        cpl, cbf = chunk(b'CPL0', PALETTE), chunk(b'CBFZ', lcw(OLD))
        ok_vpt = chunk(b'VPTZ', vpt([0, 1], [0, 0]))
        self.rejects(movie(frame0=frame(cbf, ok_vpt)), 'no palette')
        self.rejects(movie(frame0=frame(cpl, ok_vpt)), 'no codebook')
        self.rejects(movie(frame0=frame(chunk(b'CPL0', PALETTE[:300]), cbf, ok_vpt)), 'CPL0 is 300 bytes')
        self.rejects(movie(frame0=frame(cpl, cbf)), 'missing VPTZ')
        self.rejects(movie(frame0=frame(cpl, cbf, chunk(b'VPTZ', vpt([0], [0])))), 'VPTZ decodes to 2 bytes')
        self.rejects(movie(frame0=frame(cpl, cbf, chunk(b'VPTZ', vpt([0, 5], [0, 0])))), 'outside codebook')
        self.rejects(movie(frame0=frame(cpl, chunk(b'CBFZ', lcw(OLD[:20])), ok_vpt)), 'not whole 4x4 vectors')
        self.rejects(movie(frame0=frame(cpl, cbf, chunk(b'CBP0', NEW), ok_vpt)), 'unsupported sub-chunk CBP0')
        self.rejects(movie(frame0=frame(cpl, cbf, chunk(b'XYZW', b''), ok_vpt)), 'unknown sub-chunk')
        self.rejects(movie(frame0=frame(cpl, cbf, ok_vpt, ok_vpt)), 'duplicate sub-chunk VPTZ')
        self.rejects(movie(frame1=frame(chunk(b'CBPZ', PART2[:-1] + b'\x81'), chunk(b'VPTZ', vpt([1, 7], [0, 0xFF])))), 'LCW')

    def test_lcw(self):
        self.assertEqual(V.lcw(lcw(b'abc')), b'abc')
        self.assertEqual(V.lcw(b'\x83abc\xc0\x00\x00\x80'), b'abcabc')           # absolute copy
        self.assertEqual(V.lcw(b'\x81a\x00\x01\x80'), b'aaaa')                    # overlapping relative copy
        self.assertEqual(V.lcw(b'\xfe\x04\x00z\x80'), b'zzzz')                   # fill
        for bad, text in [(b'\x83ab', 'truncated'), (b'\x81a', 'truncated'), (b'\x81a\x00\x05\x80', 'relative reference'),
                          (b'\x81a\xc0\x09\x00\x80', 'absolute reference'), (b'\xff\x01\x00', 'truncated'), (b'', 'truncated')]:
            with self.assertRaises(V.VQAError) as ctx: V.lcw(bad)
            self.assertIn(text, str(ctx.exception))

if __name__ == '__main__':
    unittest.main()
