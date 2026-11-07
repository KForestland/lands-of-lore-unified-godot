#!/usr/bin/env python3
"""Stage original Museum skeleton/Rat sounds from pinned frame-event records."""
import argparse, json, struct, sys, shutil
from pathlib import Path
from prepare_creature_audio_clips import stage_clips, sha, BANK_HASH
from lol2_source_format import parse_mix
GAME=Path('~/lol2_out/museum_capture_20260913/game')
ROOT=Path(__file__).resolve().parents[1]

def stage_population_audio(archive_name, archive_sha, sprite_folder, audio_folder, contract_path, *, root=None, game=None, manifest_path=None):
    root = ROOT if root is None else Path(root)
    manifest_path = root/'assets/lol2/generated'/sprite_folder/'sprites.json' if manifest_path is None else Path(manifest_path)
    manifest=json.loads(manifest_path.read_text())
    archive=((GAME if game is None else Path(game))/archive_name).read_bytes()
    assert sha(archive)==manifest['source']['sha256']==archive_sha
    metas=[archive[e['offset']:e['offset']+e['size']] for e in parse_mix(archive) if archive[e['offset']:e['offset']+8]==struct.pack('<II',18,516)]
    assert len(metas)==1
    meta=metas[0];assert sha(meta)==manifest['metadata_sha256']
    references=[]
    for definition,entry in manifest['definitions'].items():
        for state in entry['states']:
            for event in state['frame_events']:
                if event['kind']!=2: continue
                offset=event['source_offset']
                raw=meta[offset:offset+8]
                # Original packed event header: kind byte, frame byte, value word.
                assert raw[0]==2 and raw[1]==event['frame'] and struct.unpack_from('<H',raw,2)[0]==event['value_word'], (event,raw.hex())
                references.append(dict(definition=int(definition),selector=state['selector'],frame=event['frame'],request=event['value_word'],source_offset=offset,source_bytes=raw.hex()))
    requests=sorted({r['request'] for r in references})
    clips=stage_clips(root,audio_folder,requests,game=game)
    report=dict(version=1,archive_sha256=sha(archive),metadata_sha256=sha(meta),manifest_sha256=sha(manifest_path.read_bytes()),sound_bank_sha256=BANK_HASH,references=references,clips=clips,
        scope='Original packed kind2 event bytes and pinned sound-bank records, chunk bounds/PCM lengths/WAV round trips verified. Static source bindings only; native dispatch, live clocks, mixing, pause/save integration and audible review not claimed.')
    contract=dict(version=1,rate=22050,samples={k:v['samples'] for k,v in clips.items()},definitions={})
    for definition,entry in manifest['definitions'].items():
        contract['definitions'][definition]={str(s['selector']):dict(frames=len(s['views'][0]['frames']),cues=[[e['frame'],e['value_word']] for e in s['frame_events'] if e['kind']==2]) for s in entry['states']}
    contract_path.parent.mkdir(parents=True,exist_ok=True)
    contract_path.write_text(json.dumps(contract,indent=2)+'\n')
    text=json.dumps(report,indent=2)+'\n'
    (root/'assets/lol2/generated'/audio_folder/'audio.json').write_text(text)
    (root/'docs').mkdir(exist_ok=True)
    (root/'docs'/(audio_folder.replace('_','-')+'-checks.json')).write_text(text)
    print(f'PASS: {len(clips)} original {audio_folder} sounds, {len(references)} pinned frame-event bindings and PCM/WAV round trips')
def main():
    stage_population_audio('DAT/L3_DH.MIX','bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac','museum_creature_sprites','museum_creature_audio',ROOT/'scripts/lol2/museum_creature_audio_source.json')
PRESETS = {
    'museum_creature_audio': ('DAT/L3_DH.MIX', 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac', 'museum_creature_sprites'),
    'cave_guard_audio': ('DAT/L1_DC.MIX', '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345', 'cave_guard_sprites'),
    'cave_roach_audio': ('DAT/L1_DC.MIX', '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345', 'cave_roach_audio_sprites'),
    'cave_lurking_roach_audio': ('DAT/L1_DC.MIX', '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345', 'cave_lurking_roach_sprites'),
}

def cli():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game',type=Path,required=True)
    p.add_argument('--sprites',type=Path,required=True,help='Fresh sprites.json for the selected population')
    p.add_argument('--population',choices=PRESETS,required=True)
    p.add_argument('--output-root',type=Path,required=True)
    a=p.parse_args()
    if a.output_root.exists():p.error('--output-root must be fresh')
    archive, expected, folder=PRESETS[a.population]
    for path in [a.game/archive,a.game/'LOCALLNG.MIX',a.sprites]:
        if not path.is_file():p.error('Missing input: '+str(path))
    expected_definitions={'museum_creature_audio': {'0','1','2'}, 'cave_guard_audio': {'0','1','2'}, 'cave_roach_audio': {'4','5'}, 'cave_lurking_roach_audio': {'6'}}[a.population]
    if set(json.loads(a.sprites.read_text())['definitions']) != expected_definitions:p.error('Sprite definitions do not match the selected population')
    if shutil.which('ffmpeg') is None:p.error('ffmpeg not found on PATH')
    stage_population_audio(archive,expected,folder,a.population,a.output_root/'scripts/lol2'/(a.population+'_source.json'),root=a.output_root,game=a.game,manifest_path=a.sprites)

if __name__=='__main__':
    if len(sys.argv)>1:cli()
    else:main()
