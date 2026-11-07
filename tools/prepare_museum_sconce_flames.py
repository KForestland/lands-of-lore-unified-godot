#!/usr/bin/env python3
"""Rebuild the Museum hall sconce fire (static assemblies 117-139, template37).

Lock113's insert group 7976 runs op5 value1 on controls 117-139 and the take group 8200 runs value0.
State 1 selects child mask 2: the hidden template37 child-91 face pair per sconce, resource 39
(20 animated variants). This pack carries those 46 faces and the 20 frames, pinned by sha256.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys, tempfile
ROOT = Path(__file__).resolve().parents[1]
SCONCES = range(117, 140)
FACE_SHA = "33d94bdc07145ddbe23e4c7b2f9f653d15da154f903ecf41ba95a7b31942b6ec"
FRAME_SHA = ["44f3cb1f77762084ecfcb3a4bb5ec5db66a1a382143bd1bc17bcbda6969b0363", "9ec10b6f81c2a8d5d62b3a9cb1d4e5d51b6a4a5832d04f7e42cc4d3d6ed6963e",
	"b6ac7b3d95f778e67ae76740c0abf4ea62b52069d783d5f44dc6f60a6980bb63", "f2e2c4e4d0d43940aa8231b50fc6e047a7aca52499763d499397cc8a1e1c63db",
	"841dba563bc91322f9c7f116deef1f348cea093765dafa811b38d730856a5ab1", "f5ed2a4a070fe3d5ee213de5984cf27b9781028bbfd5cea6a93b3fa95b8a1c41",
	"3d8cc67c9711291a73d9323d3ffd5fda19cb1bcb430cead06a0f4e0e61429a41", "77a2745ce46e821310b0739db3c86a7bcdabcc7d144507b1bccfc707101c2cca",
	"b4e1a07133e5ec543098e4f0ffcecf2c730d56a80cdb28d6365a3c471e651bd1", "986872a869dd984f32f34cfa2c99c125e7d2f70361cfe1482898d81297d24906",
	"6ed26e50d55513738a2bd5a7f2100fb9c5db244626d0f1a9c7bc8ed426ad4a9c", "2a251196e545d3253453e004d54529632c835088d2b857f72a4f37b3e32fddb6",
	"3edd7f8a0bb8bab649e7f59215fb149a42d6f2f6a535c75a6e714e212d1d00d8", "1fbf44aab90a509485ee6c81b91ac54bb366398987320c0ad8f62321200b17fc",
	"64bcba56b6fe47edcf96632bfb1066027b94386e5339d6a428d2e09db427816a", "73dded12f368cb7a29f4c5c336e383fc09f218160006894e6cda0475c28ba3a0",
	"efa21f461e2561a1585d4f5d5b04a1d88d5bf6909df3aa8cf0ceeecd353cde80", "e4e72a939cbcf1b03444d88a66f0b9cb9d4d4b2646b514fce0da11f99f861166",
	"8d73e64cd68f23e1188ced7722a5ee2151347dc867ad52a5e8204df2e0a72aa8", "576a947e4d0c0954e54b241516dd428bad14fb0b140e7b9537362b9f82f8d424"]
def sha(data): return hashlib.sha256(data).hexdigest()
def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--game', required=True, type=Path)
	p.add_argument('--materials', required=True, type=Path)
	p.add_argument('--re-root', required=True, type=Path)
	p.add_argument('--out', required=True, type=Path)
	a = p.parse_args()
	out = a.out.resolve()
	for source in [a.game.resolve(), a.materials.resolve(), a.re_root.resolve()]:
		if out == source or out in source.parents or source in out.parents: p.error('Output overlaps an input')
	if out.exists(): p.error('Output must be fresh')
	with tempfile.TemporaryDirectory(prefix='museum-sconce-flames-') as temp:
		report = Path(temp) / 'assemblies'
		subprocess.run([sys.executable, str(ROOT / 'tools/export_map_movables.py'), '--game-root', str(a.game), '--material-root', str(a.materials), '--re-root', str(a.re_root), '--tools-root', str(ROOT / 'tools'), '--area', 'L3_DH', '--placement-kind', 'static_assembly', '--out', str(report)], check=True, stdout=subprocess.DEVNULL)
		data = json.loads((report / 'movables.json').read_text())
		faces = [f for f in data['state_faces'] if f['template'] == 37 and f['source_index'] in SCONCES]
		if sha(json.dumps(faces, sort_keys=True, separators=(',', ':')).encode()) != FACE_SHA: raise ValueError('Sconce source geometry changed')
		if any(int(f['child_mask']) != 2 or int(f['resource_id']) != 39 for f in faces): raise ValueError('Sconce state mask/resource changed')
		material_root = Path(data['materials_root'])
		frames = [(material_root / f'material_0039/variant_{i}.png').read_bytes() for i in range(len(FRAME_SHA))]
		for i, content in enumerate(frames):
			if sha(content) != FRAME_SHA[i]: raise ValueError(f'Sconce flame frame {i} changed')
		if (material_root / f'material_0039/variant_{len(FRAME_SHA)}.png').exists(): raise ValueError('Unexpected extra flame variant')
		out.mkdir(parents=True)
		names = []
		for i, content in enumerate(frames):
			name = f'flame_{i:02d}.png'; (out / name).write_bytes(content); names.append(name)
		result = {'version': 1, 'source': data['source'], 'sconces': list(SCONCES), 'lit_state': 1, 'child_mask': 2, 'resource': 39,
			'faces': [{k: f[k] for k in ('source_index', 'child', 'face', 'points', 'uv')} for f in faces], 'frames': names,
			'fps': 8.0, 'timing': 'adapter: native resource-39 frame delay untraced; 8 fps matches the provisional review material animations',
			'scope': 'Lock113 sconce fire faces only. Props 276-279, prop126 and the control113 animation keep their existing status.'}
		(out / 'sconce_flames.json').write_text(json.dumps(result, indent=1) + '\n')
	print(f'PASS museum sconce flames: {len(faces)} faces on {len(SCONCES)} sconces, {len(frames)} frames')
if __name__ == '__main__': main()
