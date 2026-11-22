#!/usr/bin/env python3
"""Stage prop 78's exact L19 reel, SPHERE3\\L19_BC\\E224E.VQA."""
import argparse, hashlib, json
from pathlib import Path
from lol2.map_video_inventory import lookup_movie
from prepare_cave_entrance_death import encode

PIN = "2a4c3fa6163cf4ac5f6ddb38fa1777548a4d93b4ca6292036bf4a5db020b7363"
ARCHIVE = "7ca34b4942bad7702a5c7ff25ad72f48ec88a22a5af1a4a2e4718535dcfcb5d5"

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game", type=Path, required=True)
    p.add_argument("--output-root", type=Path, default=Path("."))
    p.add_argument("--cache", type=Path, default=Path("tmp/l19_e224e_media"))
    a = p.parse_args()
    root = a.output_root.resolve()
    found = lookup_movie(a.game, "L19_BC", "e224e.vqa")
    assert found["status"] == "exact", found.get("reason")
    assert found["logical_name"] == "SPHERE3\\L19_BC\\E224E.VQA"
    assert found["sha256"] == PIN and found["archive_sha256"] == ARCHIVE
    assert found["mix_index"] == 5 and found["key"] == 1194504581 and found["length"] == 10686006
    header = found["vqhd"]
    assert header["count"] == 1256 and header["width"] == 228 and header["height"] == 348 and header["fps"] == 15
    cache = a.cache.resolve()
    cache.mkdir(parents=True, exist_ok=True)
    vqa = cache / "e224e.vqa"
    vqa.write_bytes(found["blob"])
    out = root / "assets/lol2/generated/l19_e224e"
    out.mkdir(parents=True, exist_ok=True)
    target = out / "e224e.ogv"
    media = encode(vqa, cache, 1256, target)
    media.update(
        logical_name=found["logical_name"],
        mix_index=found["mix_index"],
        key=found["key"],
        source_sha256=found["sha256"],
        sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
        path="res://assets/lol2/generated/l19_e224e/e224e.ogv",
        record=78,
        area="L19_BC",
        scope="Original 1256 frames at 15 fps. Ogg encoding. Quad uses the recorded corners.",
    )
    (out / "movie.json").write_text(json.dumps(media, indent=1) + "\n")
    print("PASS original e224e", media["seconds"], "seconds")

if __name__ == "__main__":
    main()
