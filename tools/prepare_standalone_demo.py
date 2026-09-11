#!/usr/bin/env python3
from pathlib import Path
import shutil
import argparse
parser=argparse.ArgumentParser(description="Stage portable Linux and Windows walkthrough exports from locally generated assets.")
parser.add_argument("--output",type=Path,required=True)
parser.add_argument("--templates",type=Path,required=True)
args=parser.parse_args()
src=Path(__file__).resolve().parents[1]
stage=args.output.resolve()/'project'
assert (src/'assets/lol2/generated/dummy_creatures/creatures.json').is_file(), 'Generate cave assets first'
assert not stage.exists(), 'Use a fresh output directory'
templates=args.templates.resolve()
stage.mkdir(parents=True,exist_ok=True)
for name in ['scripts','scenes','assets']:
 shutil.copytree(src/name,stage/name,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.import','*.uid'))
s=(src/'project.godot').read_text().replace('res://scenes/lol2/setup.tscn','res://scenes/lol2/cave_walkthrough.tscn').replace('Lands of Lore Unified Godot','LoL2 Cavern Walkthrough')
(stage/'project.godot').write_text(s)
# Preserve exact palette indices and raw PNG FileAccess in exported packs.
for p in (stage/'assets').rglob('*.png'):
 p.with_name(p.name+'.import').write_text('[remap]\n\nimporter="keep"\n')
blocks=[]
for i,(name,platform,ext,template) in enumerate([('Linux','Linux','x86_64','linux_release.x86_64'),('Windows','Windows Desktop','exe','windows_release_x86_64.exe')]):
 out=stage.parent/name;out.mkdir(exist_ok=True)
 blocks.append(f'''[preset.{i}]
name="{name}"
platform="{platform}"
runnable=true
advanced_options=false
export_filter="all_resources"
include_filter="assets/lol2/generated/*.json,assets/lol2/generated/*.png"
exclude_filter=""
export_path="../{name}/LoL2-Cavern.{ext}"
script_export_mode=1

[preset.{i}.options]
custom_template/release="{templates / template}"
binary_format/architecture="x86_64"
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
codesign/enable=false
application/modify_resources=false
''')
(stage/'export_presets.cfg').write_text('\n'.join(blocks))
print(stage)
