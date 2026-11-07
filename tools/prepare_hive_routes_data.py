#!/usr/bin/env python3
"""Prepare the four existing Jungle/Hive route pairs from original records."""
import argparse, hashlib, json, struct
from pathlib import Path
from build_game_atlas import parse_mix, section, u32
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from lol2_geometry_format import slope_corners

SOURCES = {
    'jungle': ('L4_HJ', 3710797084, '517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f'),
    'hive': ('L5_HC', 3776990464, 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'),
}
BODY_HEIGHT = 34  # Existing authored review-start offset, not native placement evidence.


def require(value, message):
    if not value:
        raise ValueError(message)


def load(game, name):
    area, key, pin = SOURCES[name]
    archive = (game / ('DAT/' + area + '.MIX')).read_bytes()
    require(hashlib.sha256(archive).hexdigest() == pin, 'Unsupported ' + area + ' archive')
    entries = [e for e in parse_mix(archive) if e['key'] == key]
    require(len(entries) == 1, 'Expected one geometry entry')
    entry = entries[0]
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    owners, _ = collect_owners(raw, entry['offset'], u32(raw, 0x58))
    start, _, stream = section(raw, 0x3c, 0x84, 1)
    _, _, vb = section(raw, 4, 0x50, 8)
    _, _, rb = section(raw, 12, 0x58, 44)
    _, _, ab = section(raw, 0x48, 0x90, 12)
    return dict(archive=archive, raw=raw, offset=entry['offset'], owners=owners, start=start,
                groups=dict(groups(stream)), vertices=list(struct.iter_unpack('<ii', vb)),
                records=list(struct.iter_unpack('<22H', rb)), arrivals=list(struct.iter_unpack('<hhHHBBH', ab)))


def prepare(game, output):
    require(not output.exists(), 'Output must be a fresh directory')
    require(output != game and output not in game.parents and game not in output.parents, 'Output overlaps original game')
    sources = {name: load(game, name) for name in SOURCES}
    routes = {}
    for area, region, entry, destination in [('jungle',2809,1,'hive'),('hive',460,3,'jungle'),
                                             ('jungle',2604,2,'hive'),('hive',835,4,'jungle')]:
        source, dest = sources[area], sources[destination]
        owners = [o for o in source['owners'] if o['owner_kind'] == 'region' and o['owner'] == region]
        require(len(owners) == 1, 'Expected one route event owner')
        owner = owners[0]
        require(owner['stream'] == 0 and owner['predicate'] is None and owner['event'] == 2, 'Route event differs')
        rows = [(offset,b) for offset,b in source['groups'][owner['group']] if b[:5] == bytes.fromhex('020100001c')]
        require(len(rows) == 1, 'Expected one level-change command')
        offset, command = rows[0]
        packed = command[5]
        require(packed >> 5 == entry and packed & 31 == (5 if destination == 'hive' else 4), 'Route destination differs')
        record = source['records'][region]
        polygon = [[source['vertices'][v][0] / 65536, -source['vertices'][v][1] / 65536] for v in record[6:10]]
        event_at = owner['archive_offset']
        event_raw = source['archive'][event_at:event_at + source['archive'][event_at]]
        link = dict(region=region, polygon=polygon, event=owner['event'], value=owner['value'],
                    group=owner['group'], predicate=None, raw_hex=event_raw.hex(),
                    source_offset=event_at, descriptors=owner['descriptors'])
        transition = dict(stream=0, group=owner['group'], packed_destination=packed,
                          command=dict(offset=offset, source_offset=source['offset'] + source['start'] + offset,
                                       opcode=command[0], kind=command[1], target=struct.unpack_from('<H',command,2)[0], raw_hex=command.hex()),
                          destination_level=packed & 31, destination_entry=packed >> 5)
        arrivals = [a for a in dest['arrivals'] if a[4] == entry]
        require(len(arrivals) == 1, 'Expected one destination arrival')
        x,y,heading,support,selector,flags,tail = arrivals[0]
        heights = slope_corners(dest['records'], support)
        # Existing review starts use the upper support corner plus body clearance.
        key = area if entry in (1,3) else area + '_small'
        routes[key] = dict(region=region, polygon=polygon, floor=min(slope_corners(source['records'],region)),
                           ceiling=max(slope_corners(source['records'],region,True)), destination=destination,
                           entry=entry, arrival=[x,max(heights)+BODY_HEIGHT,-y], source_event=link,
                           source_transition=transition,
                           scope='Source route/arrival pair. Authored grounded polygon admission and preserved view yaw; native crossed-region dispatcher not reproduced.')
    target = output / 'assets/lol2/generated/hive_routes/routes.json'
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps(routes, indent=2) + '\n')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game',type=Path,required=True)
    p.add_argument('--output-root',type=Path,required=True)
    a=p.parse_args()
    try:
        prepare(a.game.resolve(),a.output_root.resolve())
    except (ValueError,OSError,KeyError,IndexError,struct.error) as error:
        p.error(str(error))
    print('PASS four original Jungle/Hive route pairs')


if __name__=='__main__':
    main()
