#!/usr/bin/env python3
"""The empty Dreamstone holder (L13_RC prop record 326, material prop_84) for after the stone is taken.

Owner F10 2026-11-16T16-25-00 (r19o8): "the empty holder is not empty when I take the stone". All five frames of
prop_84 draw the stone in the holder's claws and the pack has no empty frame. Presentation adapter (lead 2026-11-16):
frame 0 (the prop's static texture) with the stone cut out - an ellipse over the stone between the claws made fully
transparent; the claws and the palm below are kept. Writes assets/lol2/generated/l13_altar/holder_empty.png (local,
derived from the original frame; not for publication).
"""
import hashlib, json, pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAP = ROOT / "assets/lol2/generated/maps/L13_RC/area.json"
OUT = ROOT / "assets/lol2/generated/l13_altar/holder_empty.png"
RECORD = 326
# Stone ellipse in the 256x256 frame (pixels): centre, radii. Measured on frame 0.
CX, CY, RX, RY = 141.5, 33.0, 15.5, 24.5

def main():
    data = json.loads(MAP.read_text())
    prop = next(p for p in data["props"] if int(p.get("record", -1)) == RECORD)
    source = MAP.parent / data["materials"][prop["material"]]
    image = Image.open(source).convert("RGBA")
    assert image.size == (256, 256), image.size
    px = image.load()
    cleared = 0
    for y in range(0, 64):
        for x in range(110, 175):
            if ((x - CX) / RX) ** 2 + ((y - CY) / RY) ** 2 <= 1.0 and px[x, y][3] != 0:
                px[x, y] = (0, 0, 0, 0); cleared += 1
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print(OUT, cleared, hashlib.sha256(OUT.read_bytes()).hexdigest())

if __name__ == "__main__":
    main()
