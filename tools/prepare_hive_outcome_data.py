#!/usr/bin/env python3
"""Extract the existing Hive executioner outcome animation contract without replay."""
import argparse, hashlib, json, struct
from pathlib import Path
from lol2_source_format import parse_mix
from lol2_material_format import sections
from lol2_creature_sprite_format import parse_states, read_events, group_frames

ARCHIVE = 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
EXE = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
TEXTURE = 'c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'


def require(value, message):
    if not value:
        raise ValueError(message)


def prepare(game, texture, output):
    require(not output.exists(), 'Output must be a fresh directory')
    for source in (game, texture):
        require(output != source and output not in source.parents and source not in output.parents, 'Output overlaps an input')
    archive = (game / 'DAT/L5_HC.MIX').read_bytes()
    executable = (game / 'LOLG.DAT').read_bytes()
    blob = texture.read_bytes()
    require(hashlib.sha256(archive).hexdigest() == ARCHIVE, 'Unsupported Hive archive')
    require(hashlib.sha256(executable).hexdigest() == EXE, 'Unsupported executable provenance')
    require(hashlib.sha256(blob).hexdigest() == TEXTURE, 'Unsupported Hive texture')
    matches = [e for e in parse_mix(archive) if e['key'] == 3776335874]
    require(len(matches) == 1, 'Expected one Hive metadata entry')
    e = matches[0]
    meta = archive[e['offset']:e['offset'] + e['size']]
    entity = parse_states(meta)['entities'][1]
    require(entity['name'] == 'EXEC', 'Executioner definition differs')
    count, offset = struct.unpack_from('<II', meta, 0x50)
    sec = sections(blob)
    descriptors = {i:struct.unpack_from('<6H11I',blob,sec[2]+i*56) for i in range((sec[3]-sec[2])//56)}
    grouped = {g['base']:g for g in group_frames({i:d for i,d in descriptors.items() if d[3] == 0x1246})}
    clips = []
    for selector, expected_resource, expected_frames in [(17,474,19),(18,742,9),(19,336,1),(20,334,1)]:
        state = entity['states'][selector]
        require(len(state['views']) == 1, 'Expected one outcome view')
        resource = state['views'][0]['resource_reference']
        require(resource == expected_resource, 'Outcome resource differs')
        descriptor = descriptors[resource]
        if resource in grouped:
            frames = grouped[resource]['count']
        elif descriptor[3] == 0x2c6:
            frames = descriptor[4]
        else:
            require(descriptor[3:5] == (0x28e,1), 'Unsupported outcome descriptor')
            frames = 1
        require(frames == expected_frames, 'Outcome frame count differs')
        raw = bytes.fromhex(state['raw_hex'])
        interval = struct.unpack_from('<i',raw,4)[0] >> 8
        events, _ = read_events(meta,offset,count,struct.unpack_from('<H',raw,8)[0])
        require(interval == 1024 and all(e['kind'] == 2 for e in events), 'Outcome interval/events differ')
        clips.append(dict(selector=selector,resource=resource,frames=frames,interval=interval,
                          events=[dict(kind=e['kind'],frame=e['frame'],raw_hex=e['raw_hex']) for e in events],
                          action=14 if selector in (17,18) else 15))
    target = output / 'assets/lol2/generated/hive_outcome/animation.json'
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps(dict(version=1,clips=clips,provenance=dict(executable_sha256=EXE,archive_sha256=ARCHIVE)),indent=2)+'\n')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game',type=Path,required=True)
    p.add_argument('--texture',type=Path,required=True)
    p.add_argument('--output-root',type=Path,required=True)
    a=p.parse_args()
    try:
        prepare(a.game.resolve(),a.texture.resolve(),a.output_root.resolve())
    except (ValueError,OSError,KeyError,IndexError,struct.error) as error:
        p.error(str(error))
    print('PASS four original executioner outcome animation records')


if __name__=='__main__':
    main()
