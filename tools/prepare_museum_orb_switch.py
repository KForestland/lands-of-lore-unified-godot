#!/usr/bin/env python3
"""Decode the Museum orb and fire-crystal sprites the ordinary prop pack omits.

  python3 tools/prepare_museum_orb_switch.py --game GAME --texture TEXTURE.BIN --museum-json PATH --output-root FRESH

Prop154 template32 selector0 is descriptor 907 (0x828E, 123x208). Prop297 template18 selector0 is
descriptor 455 (0x828E, 172x163). Colour uses tools/lol2/map_sprite_rows.py: index 0 and index 1 stay
transparent. The ordinary pack stays untouched. Region1249's shipped floor (museum face 3307, y=-50)
is copied into the source json so the runtime can raise it to y=30. Movable65's aim is its Godot
placement (-2096, -5, -1085) lifted by the same 5 units the locks use, on the pit centre x/z.
"""
import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

MIX_SHA = "bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac"
BLOB_SHA = "7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07"
META_KEY = 3105896470
GEO_KEY = 3106551060
SPRITES = {154: (907, "orb.png"), 297: (455, "crystal.png")}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--game", type=Path, required=True)
    parser.add_argument("--texture", type=Path, required=True)
    parser.add_argument("--museum-json", type=Path, required=True)
    parser.add_argument("--movables-json", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()
    if args.output_root.exists():
        parser.error("--output-root must be a fresh directory")
    tools = Path(__file__).resolve().parent
    sys.path[:0] = [str(tools), str(tools / "lol2")]
    from lol2_source_format import parse_mix
    from lol2_material_format import rgb_palette, sections
    from map_sprite_rows import colour_rgba, decode_sprite
    from PIL import Image

    mix_path = args.game / "DAT/L3_DH.MIX"
    mix = mix_path.read_bytes()
    blob = args.texture.read_bytes()
    if digest(mix) != MIX_SHA or digest(blob) != BLOB_SHA:
        parser.error("L3_DH.MIX or texture.bin is not the pinned original")
    entries = parse_mix(mix)
    meta_e = next(e for e in entries if e["key"] == META_KEY)
    geo_e = next(e for e in entries if e["key"] == GEO_KEY)
    meta = mix[meta_e["offset"]:meta_e["offset"] + meta_e["size"]]
    geo = mix[geo_e["offset"]:geo_e["offset"] + geo_e["size"]]
    bounds = _selector0(meta)
    placed = _placements(geo)
    sec = sections(blob)
    palette = rgb_palette(blob[struct.unpack_from("<I", blob, 4)[0]:][:768], 6)
    out = args.output_root / "assets/lol2/generated/museum_orb_switch"
    out.mkdir(parents=True)
    images = {}
    for record, (descriptor, name) in SPRITES.items():
        info = bounds[placed[record]["template"]]
        if info["descriptor"] != descriptor:
            parser.error(f"record {record} descriptor {info['descriptor']} != {descriptor}")
        header = struct.unpack_from("<6H11I", blob, sec[2] + descriptor * 56)
        if header[3] != 0x828E or header[4] != 1:
            parser.error(f"descriptor {descriptor} is not one 0x828E frame")
        payload = blob[sec[3] + header[7]:sec[3] + header[7] + header[12]]
        sprite = decode_sprite(payload, expected_flags=0x828E)
        if (sprite["width"], sprite["height"]) != (header[1], header[2]):
            parser.error("decoded size differs from the descriptor")
        Image.frombytes("RGBA", (sprite["width"], sprite["height"]), colour_rgba(sprite, palette)).save(out / name)
        images[record] = dict(info, file=name, width=sprite["width"], height=sprite["height"],
                              payload_sha256=digest(payload), index1=sprite["count"], record=record, **placed[record])
    museum = json.loads(args.museum_json.read_text())
    face = museum["faces"][3307]
    ys = {point[1] for point in face["points"]}
    if face["region"] != 1249 or face.get("kind") != "floor" or ys != {-50} or str(face["material"]) != "231":
        parser.error("museum face 3307 is not the lowered region1249 floor")
    placements = json.loads(args.movables_json.read_text())["placements"]
    movable = next(row for row in placements if int(row.get("index", -1)) == 65)
    if (movable["x"], movable["y"], movable["height"], movable["template"]) != (-2096, 1085, -5, 66):
        parser.error("movable 65 placement changed")
    source = {
        "version": 1,
        "pit": {"face_index": 3307, "region": 1249, "kind": "floor", "material": face["material"],
                "lowered_y": -50, "raised_y": 30, "points": face["points"], "uv": face["uv"]},
        "plate": {"movable": 65, "template": 66, "native_xy": [-2096, 1085], "height": -5,
                  "position": [-2096, -5, -1085], "aim": [-2095, 0, -1085],
                  "placement_hex": movable["placement_hex"]},
        "orb": images[154],
        "crystal": images[297],
    }
    script = args.output_root / "scripts/lol2"
    script.mkdir(parents=True)
    (script / "museum_orb_switch_source.json").write_text(json.dumps(source, indent=2) + "\n")
    print("PASS museum orb switch media", out)


def _u32(raw: bytes, offset: int) -> int:
    return struct.unpack_from("<I", raw, offset)[0]


def _selector0(meta: bytes) -> dict:
    off, count = _u32(meta, 8), _u32(meta, 0x40)
    so = off + count * 55 + 4
    state_count = _u32(meta, so - 4)
    fo = so + state_count * 16 + 4
    frame_count = _u32(meta, fo - 4)
    state = frame = 0
    found = {}
    for template in range(count):
        record = meta[off + template * 55:off + (template + 1) * 55]
        selectors = record[46] + record[47]
        for selector in range(selectors):
            row = meta[so + state * 16:so + (state + 1) * 16]
            frames = struct.unpack_from("<b", row, 13)[0]
            span = 1 if frames < 0 else frames
            if template in (32, 18) and selector == 0:
                header = meta[fo + frame * 12:fo + (frame + 1) * 12]
                found[template] = dict(
                    descriptor=struct.unpack_from("<h", header)[0],
                    left=-row[14] / 2 + header[5], right=row[14] / 2 - header[7],
                    bottom=float(header[8]), top=float(row[15] - header[6]),
                    frame_flags=header[2], selectors=selectors, state_count=frames, flag50=record[50])
            state += 1
            frame += span
    if state != state_count or frame != frame_count or set(found) != {18, 32}:
        raise SystemExit("template tables did not yield selector 0 for templates 18 and 32")
    return found


def _placements(geo: bytes) -> dict:
    found = {}
    for index in range(_u32(geo, 0x60)):
        if index not in (154, 297):
            continue
        row = geo[_u32(geo, 0x14) + index * 37:_u32(geo, 0x14) + (index + 1) * 37]
        x, y, z = [struct.unpack_from("<h", row, k)[0] for k in (0, 2, 6)]
        found[index] = dict(template=struct.unpack_from("<H", row, 32)[0], position=[x, z, -y],
                            region=struct.unpack_from("<H", row, 10)[0], selector=row[35])
    if set(found) != {154, 297}:
        raise SystemExit("prop 154 or 297 missing")
    return found


if __name__ == "__main__":
    main()
