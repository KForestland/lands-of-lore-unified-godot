"""Import the pinned material render; source is generated with the contributor kit."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("render_dir", type=Path)
args = parser.parse_args()
source = args.render_dir
report = json.loads((source / "report.json").read_text())
if (report["descriptor"]["index"], report["shade_bank"], report["reference"]["blob_sha256"]) != (556, 45, "adf44e535d7b890f0f47e28266e480559fa0417094e0b5495f0775e06c41ef21"):
    raise SystemExit("Not the verified descriptor 556 / shade 45 fixture")
name = "material_556_mip0_256x256.png"
data = (source / name).read_bytes()
expected = "80027f46b62ecfa00d93597c9565c4df78a41081a4937d9532c9b66a0dfa7e7d"
if hashlib.sha256(data).hexdigest() != expected:
    raise SystemExit("PNG differs from pinned fixture; investigate before importing")
out = Path(__file__).resolve().parents[2] / "assets/lol2/generated/cave_material"
out.mkdir(parents=True, exist_ok=True)
(out / "rock.png").write_bytes(data)
(out / "provenance.json").write_text(json.dumps({
    "blob_sha256": report["reference"]["blob_sha256"], "descriptor": 556,
    "shade_bank": 45, "png_sha256": expected,
    "scope": "Verified L20 rock material; use on test cave surfaces is an artistic assignment. Base PNG only; Godot original mip selection not reproduced."
}, indent=2) + "\n")
print(f"Verified material imported to {out}")
