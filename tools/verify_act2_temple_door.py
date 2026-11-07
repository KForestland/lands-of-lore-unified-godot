#!/usr/bin/env python3
"""Pin the TMPLDOR door callback and L8 named-local join; never execute original code."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from monastery_media import extract

ROOT = Path(__file__).resolve().parents[1]
WINDOWS = {
    0x1b8: "8b50488915440700008b504c8915480700008b505089154c070000",
    0x2d2: "8b90b40000008915b4070000",
    0x5a8: "68c4060000ff158c07000083c40485c074326810010000ff154407000083c404",
    0x611: "6800010000ff15fc07000083c4046810010000ff154c07000083c40485c074166a0168e3060000ff15b407000083c408ff1568070000",
}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game", type=Path, required=True)
    p.add_argument("--out", type=Path, default=ROOT / "scripts/lol2/act2_temple_door_source.json")
    a = p.parse_args()
    archive = (a.game / "DAT/TMPLDOR.MIX").read_bytes()
    assert hashlib.sha256(archive).hexdigest() == "ebfe1aaff150ba292b940b9c96da26e35a8ed7d3877bea0ee6cde44633db7736"
    dll, source = extract(archive, "WOMS\\TMPLDOR_.WOM")
    assert source["sha256"] == "c8e75a10595fdee7c08e8fdc53398c49609e2cfb332e0b7f4122d32ce55b9a1e"
    size = struct.unpack_from("<I", dll, 36)[0]
    module = dll[48:48+size]
    for at, expected in WINDOWS.items():
        assert module[at:at+len(bytes.fromhex(expected))].hex() == expected
    assert module[0x6c4:].split(b"\0")[0] == b"134-Dreamstone"
    name = "Luther_goes_to_level_14"
    assert module[0x6e3:].split(b"\0")[0].decode() == name
    native = json.loads((ROOT / "scripts/lol2/native_scripts/L8_SJ.json").read_text())
    src = native["source"]
    level = (a.game / src["file"]).read_bytes()
    assert hashlib.sha256(level).hexdigest() == src["sha256"]
    geom = level[src["geometry_entry_offset"]:][:src["geometry_entry_size"]]
    count, at = struct.unpack_from("<II", geom, 0xb0)
    assert geom[at+count+13*41:at+count+14*41].split(b"\0")[0].decode() == name
    g = next(g for g in native["groups"] if g["stream"] == 1 and g["group"] == 11612)
    assert [c["raw_hex"] for c in g["commands"]] == ["020100001c2e", "c60000000d00"]
    result = dict(grade="DECODED", scope="Static instructions and source names; not a native runtime trace or full quest qualification", archive_sha256=hashlib.sha256(archive).hexdigest(), module=source, windows={hex(k):v for k,v in WINDOWS.items()}, local=dict(area="L8_SJ", index=13, name=name), exit=dict(object="prop:1198", event=6, value=20, predicate=136, stream=1, group=11612, level=14, selector=1), item="134-Dreamstone", room_flag=272)
    a.out.write_text(json.dumps(result, indent=2)+"\n")
    print("PASS original temple callback bytes, named local13, and L8->L14 native group join")

if __name__ == "__main__": main()
