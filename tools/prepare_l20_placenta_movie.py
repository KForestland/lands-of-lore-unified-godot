#!/usr/bin/env python3
"""Stage prop 242's exact L20 reel, SPHERE3\\L20_BB\\PLACENTA.VQA."""
import argparse, hashlib, json
from pathlib import Path
from lol2.map_video_inventory import lookup_movie
from prepare_cave_entrance_death import encode

PIN = "e5605c7362bbbed3bf29792608cb313f9979f2cf364540c3cba315c25d6da6da"
ARCHIVE = "6e6960776cf5ecbc0a0b83f100d09322ff006cf3ebf04e343a8ce8d28dd8f3be"

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game", type=Path, required=True)
    p.add_argument("--output-root", type=Path, default=Path("."))
    p.add_argument("--cache", type=Path, default=Path("tmp/l20_placenta_media"))
    a = p.parse_args()
    root = a.output_root.resolve()
    found = lookup_movie(a.game, "L20_BB", "placenta.vqa")
    assert found["status"] == "exact", found.get("reason")
    assert found["logical_name"] == "SPHERE3\\L20_BB\\PLACENTA.VQA"
    assert found["sha256"] == PIN and found["archive_sha256"] == ARCHIVE
    assert found["mix_index"] == 24 and found["key"] == 3224565000 and found["length"] == 755314
    header = found["vqhd"]
    assert header["count"] == 60 and header["width"] == 640 and header["height"] == 340 and header["fps"] == 15
    cache = a.cache.resolve()
    cache.mkdir(parents=True, exist_ok=True)
    vqa = cache / "placenta.vqa"
    vqa.write_bytes(found["blob"])
    out = root / "assets/lol2/generated/l20_placenta"
    out.mkdir(parents=True, exist_ok=True)
    target = out / "placenta.ogv"
    media = encode(vqa, cache, 60, target)
    media.update(
        logical_name=found["logical_name"],
        mix_index=found["mix_index"],
        key=found["key"],
        source_sha256=found["sha256"],
        sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
        path="res://assets/lol2/generated/l20_placenta/placenta.ogv",
        record=242,
        area="L20_BB",
        scope="Original 60 frames at 15 fps. Ogg encoding. Quad uses the recorded corners.",
    )
    (out / "movie.json").write_text(json.dumps(media, indent=1) + "\n")
    print("PASS original placenta", media["seconds"], "seconds")

if __name__ == "__main__":
    main()
