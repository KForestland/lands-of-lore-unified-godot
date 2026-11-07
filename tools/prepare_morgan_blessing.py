#!/usr/bin/env python3
"""Stage the original garden Power Orb blessing and repeat refusal.

Explicit inputs (fresh output root; every input and original is checked before anything is written):
  python3 tools/prepare_morgan_blessing.py --game GAME --plans scripts/lol2/morgan_orb_blessing.gd \
      --conversation scripts/lol2/monastery_conversation.gd --output-root FRESH
The movie lines are this tool's constants, checked against the published runtime plan (morgan_orb_blessing.gd
offer_plan) before writing; the staged frame/sample counts must equal the published monastery_conversation.gd
FRAMES/SAMPLES. Published helpers only (tools/monastery_media.py); no RE checkout, no native replay, no docs.
Without arguments the historical behaviour (audit_act_one_item_producers.Room for the archive) is unchanged.
"""
import json,sys
EXPLICIT=__name__=='__main__' and len(sys.argv)>1
if EXPLICIT:
    import argparse,re,shutil
    from pathlib import Path
    import monastery_media
    from monastery_media import extract,movie,digest
    ROOT=None  # set by cli()

    def stage_patch(source,target,record):
        return monastery_media.stage_patch(source,target,record,ROOT)
else:
    from audit_act_one_item_producers import Room
    from audit_monastery_rooms import ROOT,extract,movie,digest
    from prepare_monastery_rooms import stage_patch

SEQUENCES=[('MGAR_ORB',[254,255]),('MGAR_ORB_REFUSE',[165])]

def stage_clips(archive):
    out=ROOT/'assets/lol2/generated/morgan_blessing';out.mkdir(parents=True,exist_ok=True)
    cache=ROOT/'tmp/morgan_blessing_source';cache.mkdir(parents=True,exist_ok=True)
    sequences={}
    for sequence,lines in SEQUENCES:
        clips=[]
        for line in lines:
            name=f'23{line:03d}07E.VQA';key='WOMS\\MGAR\\'+name
            path=cache/name;path.write_bytes(extract(archive,key)[0])
            clips.append(stage_patch(path,out/(name[:-4]+'.ogv'),movie(archive,key)))
        sequences[sequence]=clips
    result=dict(archive_sha256=digest(archive),sequences=sequences)
    (out/'clips.json').write_text(json.dumps(result,indent=2)+'\n')
    print({name:dict(frames=[c['frames'] for c in clips],samples=[c['audio_samples'] for c in clips]) for name,clips in sequences.items()})
    return sequences

def main():
    source=Room('MGAR')
    stage_clips(source.archive)

# ---- explicit inputs -------------------------------------------------------------------------------------------------
PLANS_SHA256='1c860113994e23c5e0db3b786b1139cc36b92ce0595229b84e6155890e1b5500'  # scripts/lol2/morgan_orb_blessing.gd (published)
CONVERSATION_SHA256='28c4f50d5c5eac6c6b3e4ea4b7ed5b4d6f88699164413f2ac03199f61637655a'  # scripts/lol2/monastery_conversation.gd (published)
MGAR_SHA256='4c3fd55ab5d17e78fea0572cf92600b2261aa988f86113cdc1d2085850fe7155'  # DAT/MGAR.MIX

def published_counts(text):
    """FRAMES/SAMPLES entries for the two Morgan sequences from the published conversation script."""
    found={}
    for const in ['FRAMES','SAMPLES']:
        block=text[text.index(f'const {const} := {{'):];block=block[:block.index('}')+1]
        found[const]={k:json.loads(v) for k,v in re.findall(r'"(MGAR_ORB(?:_REFUSE)?)":(\[[0-9, ]*\])',block)}
    return found

def cli():
    global ROOT
    p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game','plans','conversation','output-root']: p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    if shutil.which('ffmpeg') is None: p.error('ffmpeg not found on PATH')
    for path,want,label in [(a.plans,PLANS_SHA256,'Morgan blessing plan script'),(a.conversation,CONVERSATION_SHA256,'monastery conversation script')]:
        if not path.is_file(): p.error('Missing input: '+str(path))
        if digest(path.read_bytes())!=want: p.error(f'{path}: not the pinned {label} ({want})')
    mix=a.game/'DAT/MGAR.MIX'
    if not mix.is_file(): p.error('Missing original '+str(mix))
    archive=mix.read_bytes()
    if digest(archive)!=MGAR_SHA256: p.error(f'{mix}: not the pinned original')
    try:
        plans=a.plans.read_text()
        refuse=re.search(r'return \[\["movie",23,(\d+),7,0\]\]',plans);bless=re.search(r'return \[\["stop_timer"\].*\n',plans)
        assert refuse and bless,'offer_plan returns'
        assert [('MGAR_ORB',[int(x) for x in re.findall(r'\["movie",23,(\d+),7,0\]',bless.group(0))]),('MGAR_ORB_REFUSE',[int(refuse.group(1))])]==SEQUENCES,'tool lines differ from the published offer_plan'
        counts=published_counts(a.conversation.read_text())
        assert set(counts['FRAMES'])==set(counts['SAMPLES'])=={'MGAR_ORB','MGAR_ORB_REFUSE'},'published FRAMES/SAMPLES'
        for sequence,lines in SEQUENCES:
            assert [movie(archive,f'WOMS\\MGAR\\23{l:03d}07E.VQA')['frames'] for l in lines]==counts['FRAMES'][sequence],f'{sequence} frames'
            samples=[sum(len(d)*2 for t,d in monastery_media.parse_vqa_chunks(extract(archive,f'WOMS\\MGAR\\23{l:03d}07E.VQA')[0]) if t==b'SND2') for l in lines]
            assert samples==counts['SAMPLES'][sequence],f'{sequence} samples'
    except (AssertionError,StopIteration,KeyError,ValueError,IndexError) as error:
        p.error('Inputs do not match the published contracts: '+(str(error) or type(error).__name__))
    ROOT=a.output_root.resolve()
    sequences=stage_clips(archive)
    for sequence,clips in sequences.items():
        assert [c['frames'] for c in clips]==counts['FRAMES'][sequence] and [c['audio_samples'] for c in clips]==counts['SAMPLES'][sequence],sequence

if __name__=='__main__':
    if EXPLICIT: cli()
    else: main()
