#!/usr/bin/env python3
"""Pin the L1_DC tar pits: the first pit (props 465..471, 640; sequencer prop464) and the guard pit (props 440..446,
575..586; sequencer prop439), from the original archive records.

Tar props (templates 34/35/36/89) have three selectors: 0 = bubbling tar (descriptor449, 20 frames), 1 = ignition
(descriptor907, 35 frames), 2 = burning (descriptor126, 7 frames). Each owns, in record order:
  kind9 (hit) at owner state0, masks 0x0011/0x0000 (Spark bit1 or fire bit0x10; melee 2/4 refused), threshold99 mode4:
    first pit:  op9 self property19 value9 (B5420: durability byte+0x26 = 9), op5 prop464 selector1, op6 self sub1
                (animation restart), op5 self selector1, op16 state1, op20 sound 462.
    guard pit:  op19 prop223 (66130: deliver hit masks 0x0010/0x0000, damage 5) [props583/584 omit it], op5 prop439
                selector1 [prop577's first record omits it], op6 self sub1, op5 self selector1, op16 state1, op20 sound 462.
  kind6 value3 (animation end) at owner state1: op5 self selector2 (prop466 also op16 state2).
Sequencers (template82, never drawn; prop464 sits at height +435): kind2 timer (flags0: reload = random(20..30) << 8
in 1/256 native ticks, B8AC4/12415C; countdown word8) at owner state1: op5 self selector +1 (byte5 = 1); kind3
value1: op14 sub3 start (B485C, arg0 keeps the countdown) and op16 state1; kind3 value2..N: op19 hit (masks
0x0011/0x0001) on the next tar prop; last kind3: op14 sub4 stop (B494B). prop464 kind6 value9 (cave arrival scanner):
op14 sub4 stop.
Usage: prepare_cave_tar_fires.py --output scripts/lol2/cave_tar_fires_source.json
"""
import argparse, hashlib, json, shutil, struct, sys
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate

ROOT = Path(__file__).resolve().parents[1]
MAP = Path('~/lol2_out/all_maps_20260922/L1_DC')
FIRST = [465, 466, 467, 468, 469, 470, 471, 640]
GUARD = [440, 441, 442, 443, 444, 445, 446, 575, 576, 577, 578, 579, 580, 581, 582, 583, 584, 585, 586]
SEQUENCERS = {464: FIRST, 439: GUARD}
TEMPLATES = [34, 35, 36, 89]
DESCRIPTORS = [449, 907, 126]
SOUND = 462
NO_FIRE_HIT = [583, 584]  # their hit groups have no op19 on prop223


def le(n):
    return struct.pack('<H', n).hex()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if a.output.exists(): sys.exit('refusing to overwrite ' + str(a.output))
    out = ROOT / 'assets/lol2/generated/cave_tar_fires'
    if out.exists(): sys.exit('refusing to overwrite ' + str(out))
    sys.path.insert(0, str(Path(__file__).resolve().parent / 'lol2'))
    from map_props import load_templates
    from lol2_source_format import parse_mix
    area, arc, entry, raw, owners, streams = source_area('L1_DC')
    meta = next(arc[e['offset']:e['offset'] + e['size']] for e in parse_mix(arc) if e['key'] == 2971019266)
    templates = load_templates(meta)['templates']
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    exported = {q['record']: q for q in json.loads((MAP / 'props/props.json').read_text())['props']}
    review = json.loads((MAP / 'review.json').read_text())

    def records(prop):
        rows = []
        for o in owners:
            if o['owner_kind'] != 'prop' or o['owner'] != prop: continue
            rows.append(dict(group=o['group'], kind=o['event'],
                             raw=arc[o['archive_offset']:o['archive_offset'] + arc[o['archive_offset']]].hex(),
                             predicate=predicate(table, o['predicate']) if o['predicate'] is not None else None,
                             commands=[c['raw_hex'] for c in streams[o['stream']][o['group']]]))
        return rows

    def simple(pred, key, value):
        return pred is not None and pred['op'] == '==' and pred['left'] == key and pred['right'] == {'immediate': value}

    # Template art: three selectors per tar template, collision height byte28 and depth byte30 of the template.
    tpl = {}
    for t in TEMPLATES:
        T = templates[t]; d = bytes.fromhex(T['template_hex'])
        assert T['selector_count'] == 3 and [s['frames'][0]['descriptor'] for s in T['selectors']] == DESCRIPTORS, t
        sels = []
        for s in T['selectors']:
            f0 = s['frames'][0]
            sels.append(dict(selector=s['selector'], descriptor=f0['descriptor'], left=f0['left'], right=f0['right'],
                             bottom=f0['bottom'], top=s['state_height'] - f0['top_trim']))
        tpl[str(t)] = dict(selectors=sels, height=struct.unpack_from('<H', d, 28)[0], depth=struct.unpack_from('<H', d, 30)[0])
    props = {}
    for seq, members in SEQUENCERS.items():
        for prop in members:
            q = exported[prop]; placement = bytes.fromhex(q['placement_hex']); oid = le(prop)
            assert q['template'] in TEMPLATES and q['animated'] and q['material'] == 'prop_449', prop
            rows = records(prop)
            hits = [r for r in rows if r['kind'] == 9]; ends = [r for r in rows if r['kind'] == 6]
            assert len(ends) == 1 and ends[0]['raw'][8:12] == '0300' and simple(ends[0]['predicate'], {'owner_state': True}, 1), prop
            assert ends[0]['commands'][0] == '0503%s0200' % oid and ends[0]['commands'][1:] in ([], ['1003%s0200' % oid]), prop
            head = ['0903%s1309' % oid] if seq == 464 else [] if prop in NO_FIRE_HIT else ['1303df00100000000500']
            tail = ['0603%s0100' % oid, '0503%s0100' % oid, '1003%s0100' % oid, '1403%sce0180000a14' % oid]
            ignite = head + ['0503%s0100' % le(seq)] + tail
            for i, r in enumerate(hits):
                b = bytes.fromhex(r['raw'])
                assert b[4:8] == bytes.fromhex('11000000') and b[8] == 99 and b[9] == 4, (prop, r['raw'])
                # prop577's first record (the one AE2C8 runs at state0) omits the sequencer advance; its second
                # record (local12==0 AND state0, never reached first) has it.
                want = head + tail if prop == 577 and i == 0 else ignite
                pred = r['predicate']
                if prop == 577 and i == 1:
                    assert pred['op'] == 'AND' and simple(pred['left']['expression'], {'local': 12}, 0) and simple(pred['right']['expression'], {'owner_state': True}, 0), pred
                else: assert simple(pred, {'owner_state': True}, 0), (prop, pred)
                assert r['commands'] == want, (prop, r)
            assert len(hits) == (2 if prop == 577 else 1), prop
            props[str(prop)] = dict(position=q['position'], region=q['region'], template=q['template'], pit=seq,
                                    durability=placement[30], records=rows)
    sequencers = {}
    for seq, members in SEQUENCERS.items():
        q = exported[seq]; rows = records(seq); oid = le(seq)
        assert q['template'] == 82, seq
        timers = [r for r in rows if r['kind'] == 2]; k3 = {int(r['raw'][8:10], 16): r for r in rows if r['kind'] == 3}
        assert len(timers) == 1 and simple(timers[0]['predicate'], {'owner_state': True}, 1) and timers[0]['commands'] == ['0503%s0101' % oid]
        t = bytes.fromhex(timers[0]['raw'])
        assert t[4] == 0 and t[6:8] == bytes([30, 20]), timers[0]['raw']
        assert k3[1]['commands'] == ['0e03%s03000000' % oid, '1003%s0100' % oid], k3[1]
        order = []
        for value in range(2, len(k3)):
            cmds = k3[value]['commands']
            for c in cmds:
                assert c.startswith('1303') and c[8:] == '110001000270', c
                order.append(struct.unpack('<H', bytes.fromhex(c[4:8]))[0])
        assert sorted(order) == sorted(members) and len(set(order)) == len(order), (seq, order)
        assert k3[len(k3)]['commands'] == ['0e03%s04000000' % oid] and sorted(k3) == list(range(1, len(k3) + 1)), seq
        arrival = [r for r in rows if r['kind'] == 6]
        if seq == 464: assert len(arrival) == 1 and arrival[0]['raw'][8:12] == '0900' and arrival[0]['commands'] == ['0e03%s04000000' % oid]
        else: assert not arrival
        assert len(rows) == 1 + len(k3) + len(arrival), seq
        sequencers[str(seq)] = dict(position=q['position'], region=q['region'], template=82, timer_raw=timers[0]['raw'],
                                    timer_enabled=not (t[5] & 1), countdown=struct.unpack_from('<H', t, 8)[0],
                                    interval=[t[7], t[6]], arrival_stops=bool(arrival), records=rows)
    out.mkdir(parents=True)
    art = {}
    for d in DESCRIPTORS:
        names = []
        for i, f in enumerate(review['animations'][f'prop_{d}']['frames']):
            name = f'{d}_{i}_index.png'; shutil.copyfile(MAP / f.replace('.png', '_index.png'), out / name); names.append(name)
        art[str(d)] = names
    assert [len(art[str(d)]) for d in DESCRIPTORS] == [20, 35, 7]
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from prepare_creature_audio_clips import stage_clips
    stage_clips(ROOT, 'cave_tar_fires', [SOUND])
    import wave
    with wave.open(str(out / f'{SOUND}.wav')) as w: seconds = round(w.getnframes() / w.getframerate(), 4)
    files = {n.name: hashlib.sha256(n.read_bytes()).hexdigest() for n in sorted(out.iterdir())}
    result = dict(version=1, source=dict(area='L1_DC', archive_sha256=hashlib.sha256(arc).hexdigest()),
                  templates=tpl, art=art, props=props, sequencers=sequencers,
                  sounds={str(SOUND): dict(file=f'{SOUND}.wav', seconds=seconds)},
                  prop223=dict(hit='1303df00100000000500', masks=[0x0010, 0], damage=5,
                               note='op19 fire hit on prop223 (absent until stream0 group560 property3); its group2326 explosion is not hosted here'),
                  files=files,
                  adapters=['native ticks at 60/s; timer units 1/256 tick (word8 countdown, reload random(20..30)<<8)',
                            'timer reload draw uses a saved port PRNG, not the native 12415C generator state',
                            'animations at 10 frames/s; kind6 value3 at every cycle end of the shown selector',
                            'hit volume = selector0 sprite width x template height(byte28) x depth(byte30), the scenic prop574 rule',
                            'Spark context 1/1 with port damage; chain hits admit through mask 0x0011 (native damage is the leftover pointer value)'])
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS cave tar fires: %d tar props, %d sequencers, %d art frames, sound %d' %
          (len(props), len(sequencers), sum(len(v) for v in art.values()), SOUND))


if __name__ == '__main__':
    main()
