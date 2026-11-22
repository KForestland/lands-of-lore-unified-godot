#!/usr/bin/env python3
"""Prepare control 186's Huline movie (E056E.VQA). Original media stays local.

Template 27 resource 616. Source pixels are 400x640; ROTATE_270 makes 640x400,
the same aspect as the template quad (140 x 87). Frames are not part of a patch.
"""
import argparse, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from PIL import Image
from lol2.map_video_inventory import lookup_movie
from prepare_jungle_exit_movies import decode, audio, parse_vqa_chunks
from prepare_jungle_bacatta_media import segments

PIN = "a7bda8ce0285a07a2e6edba424739730e873a3f729b2bf2b18d997aa3e3bd9c6"

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Use a fresh output directory")
    found = lookup_movie(args.game, "L4_HJ", "E056E.VQA")
    assert found["status"] == "exact" and found["sha256"] == PIN, found.get("status")
    head = found["vqhd"]
    assert (head["count"], head["width"], head["height"], head["fps"]) == (752, 400, 640, 15), head
    args.output.mkdir(parents=True)
    cache = Path("/tmp/bg14-cat-cache")
    if cache.exists():
        raise SystemExit("cache already exists: %s" % cache)
    cache.mkdir()
    vqa = cache / "E056E.VQA"
    vqa.write_bytes(found["blob"])
    print("decoding", head["count"], "frames", flush=True)
    frames = decode(vqa, cache / "decoded", 752, (400, 640))
    rows = []
    key = None
    odd = 0
    for index, frame in enumerate(frames):
        image = Image.open(frame).convert("RGBA")
        corner = image.getpixel((0, 0))[:3]
        if key is None:
            key = corner
            assert key == (0, 251, 251), key
        elif corner != key:
            odd += 1
        image = image.transpose(Image.Transpose.ROTATE_270)
        image.putdata([(r, g, b, 0 if (r, g, b) == key else 255) for r, g, b, _ in image.getdata()])
        name = "frame_%04d.png" % index
        image.save(args.output / name)
        rows.append(name)
        if index % 100 == 0:
            print("keyed", index, flush=True)
    samples = sum(len(payload) * 2 for tag, payload in parse_vqa_chunks(found["blob"]) if tag == b"SND2")
    assert samples > 0
    rate = audio(vqa, args.output / "voice.wav", samples)
    manifest = dict(version=1, sha256=found["sha256"], movie="E056E.VQA", frames=rows,
                    width=640, height=400, fps=15, rotation=270, key=list(key),
                    segments=segments(found["blob"], 15), audio="voice.wav", samples=samples, rate=rate)
    assert [row["index"] for row in manifest["segments"]] == [0, 1, 2, 3, 4]
    assert manifest["segments"][1]["name"] == "HLoit000HULoiter"
    (args.output / "media.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("PASS", len(rows), "frames; samples", samples, "rate", rate, "corners_not_key", odd)

if __name__ == "__main__":
    main()
