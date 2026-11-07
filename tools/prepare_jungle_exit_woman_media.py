#!/usr/bin/env python3
"""Stage original pre-exit conversation media (local only) from the pinned L4_HJ data.

- prop554 template83 selectors 0-16 (WO14 world idle + speaker40/Luther lines) are type0x342 VQA references
  (names from scripts/lol2/jungle_exit_woman_source.json). Each clip is decoded through the same helper as the
  integrated Bacatta clips (every VQFR frame and SND2 sample asserted; key colour → transparent; own voice WAV).
- L4WW definition 6 frames through the shared creature preparer.
Output: assets/lol2/generated/jungle_exit_woman_media/ (ignored, never published).

Explicit inputs (fresh output root; nothing is written until every input is checked):
  python3 tools/prepare_jungle_exit_woman_media.py --game GAME --texture L4_HJ/materials/texture.bin \
      --source scripts/lol2/jungle_exit_woman_source.json --output-root FRESH
Without arguments the historical repository-root behaviour is unchanged.
"""
import argparse, hashlib, json, shutil, sys
from pathlib import Path
import prepare_jungle_bacatta_media as M
from prepare_museum_creature_sprites import stage
from prepare_jungle_exit_movies import sha, res, ROOT, TEXTURE
OUT = ROOT / 'assets/lol2/generated/jungle_exit_woman_media'
M.OUT = OUT; M.CACHE = ROOT / 'tmp/jungle_exit_woman_media'
SOURCE = ROOT / 'scripts/lol2/jungle_exit_woman_source.json'
GAME = None  # None: the shared helpers' existing default (LOL2_GAME_ROOT or the historical capture)
TEXTURE_SHA256 = '98c97fabb6fa8db7ca78a7c3626106ec850a6d5e37952292e15f32cb966a227b'  # decoded L4_HJ texture

def main():
    OUT.mkdir(parents=True, exist_ok=True); M.CACHE.mkdir(parents=True, exist_ok=True)
    source = SOURCE
    src = json.loads(source.read_text())
    clips = {}
    for selector, name in src['prop']['selectors'].items():
        clips[selector] = dict(M.clip(name, f'prop554_{int(selector):02d}'), selector=int(selector))
    stage('DAT/L4_HJ.MIX', TEXTURE.read_bytes(), [6], OUT / 'l4ww_sprites', game=GAME)
    manifest = dict(version=1, archive='DAT/L4_HJI.MIX', source_sha256=sha(source.read_bytes()), clips=clips,
                    sprites=res(OUT / 'l4ww_sprites/sprites.json'),
                    note='Original media, local only. Clip duration = max(frames/fps, voice length). Sprite poses use the shared 8 fps adapter.')
    (OUT / 'media.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print('PASS clips', {s: (c['vqa'], c['frames'], round(c['duration'], 3), bool(c['audio'])) for s, c in clips.items()})

def cli():
    global ROOT, OUT, SOURCE, GAME, TEXTURE
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'texture', 'source', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    for path in [a.texture, a.source]:
        if not path.is_file(): p.error('Missing input: ' + str(path))
    for tool in ['ffmpeg', 'ffprobe']:
        if shutil.which(tool) is None: p.error(tool + ' not found on PATH')
    src = json.loads(a.source.read_text())
    if src.get('source', {}).get('file') != 'DAT/L4_HJ.MIX' or sorted(map(int, src.get('prop', {}).get('selectors', {}))) != list(range(17)):
        p.error('Source contract is not the pre-exit L4_HJ prop554 contract')
    for rel in ['DAT/L4_HJ.MIX', 'DAT/L4_HJI.MIX']:
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
    if hashlib.sha256((a.game / 'DAT/L4_HJ.MIX').read_bytes()).hexdigest() != src['source']['sha256']:
        p.error('Original L4_HJ archive does not match the source contract')
    if hashlib.sha256(a.texture.read_bytes()).hexdigest() != TEXTURE_SHA256:
        p.error('Decoded L4_HJ texture does not match')
    GAME = a.game.resolve(); TEXTURE = a.texture.resolve(); SOURCE = a.source.resolve()
    ROOT = a.output_root.resolve(); OUT = ROOT / 'assets/lol2/generated/jungle_exit_woman_media'
    M.GAME = GAME; M.OUT = OUT; M.CACHE = ROOT / 'tmp/jungle_exit_woman_media'
    # res() is the existing imported helper; keep its root synchronized (as prepare_jungle_bacatta_media.cli does).
    import prepare_jungle_exit_movies as shared
    shared.ROOT = ROOT
    main()

if __name__ == '__main__':
    if len(sys.argv) > 1: cli()
    else: main()
