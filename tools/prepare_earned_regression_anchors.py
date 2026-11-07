#!/usr/bin/env python3
"""Preserve qualified earned outputs before regression producers overwrite their mutable paths."""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for row in json.loads((root/'docs/earned-regression-anchors.json').read_text())['anchors']:
 src=root/row['source'];dst=root/row['anchor']
 if dst.exists():
  assert hashlib.sha256(dst.read_bytes()).hexdigest()==row['sha256'],f'Anchor differs: {dst}'
 else:
  assert hashlib.sha256(src.read_bytes()).hexdigest()==row['sha256'],f'Need original qualified earned output: {src}'
  dst.write_bytes(src.read_bytes())
 print('PASS',row['anchor'],row['sha256'])
