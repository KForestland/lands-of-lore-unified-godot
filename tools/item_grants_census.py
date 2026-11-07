#!/usr/bin/env python3
"""Item grant census (ITEM_CENSUS_AND_PLAN_20261025.md step 5; read-only on staged data).

Extends item_census.json (the lead's item_census.py: 170 definitions, 663 world placements) with every other source the
staged data shows for each definition:
  - script grants: every opcode-3 command of the 15 levels' native scripts (scripts/lol2/native_scripts/AREA.json). Layout as
    the port's hosted sources use it (museum_prism_source.json `03010000 d9cd0de5 01000000`, hive_net_exile_source.json
    `03010000 5a30db1e 04000000`): byte 1 kind, word +2 target, dword +4 = the definition identity (every one of the 1086
    commands resolves to a definition), dword +8 = an argument (1 / 4 / 0 / 3 / 5; its meaning, like the take / has-item forms,
    is Grok backlog 6 item 3: pending). Kind 1 target 0 = the party (876), kind 2 target N = actor N (55), kind 0xC0 (12).
    The owner records (object + event kind, or region event) of each group are listed, so a builder knows what fires it.
  - actor-carried identities: actor placement dword +52 (the act-one audit: copied to actor +0x74; identity alone does not
    establish loot, 9BA88 resolves only inside a supplied list) where it resolves to a definition (LIKELY carried item).
  - shop grants: the port's staged shop tables (assets/lol2/generated/magic_shop_items, weapon_shop*): port lists, not a
    decoded vendor table (Grok backlog 6 item 15: none found).
Output: grants.json (per definition: placements, script grants, actor-carried, shops, source classes) and a summary.

  python3 tools/item_grants_census.py --census AI_COMMS/.../item_census/item_census.json --project . --out AI_COMMS/.../item_census
"""
import argparse, collections, glob, hashlib, json, os, struct
from pathlib import Path


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--census', type=Path, required=True)
    p.add_argument('--project', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    census = json.loads(a.census.read_text())
    defs = {int(d['index']): d for d in census['definitions']}
    by_identity = {int(d['identity']): int(d['index']) for d in census['definitions']}
    grants = {i: dict(index=i, name=d['name'], handler=int(d.get('handler', 0)), placements=dict(d.get('areas', {})) if isinstance(d.get('areas'), dict) else d.get('areas', []),
                      script_grants=[], actor_carried=[], shop=[]) for i, d in defs.items()}
    placed = {i for i, d in defs.items() if d.get('placements')}
    unresolved = collections.Counter()
    args_seen = collections.Counter()
    kinds = collections.Counter()
    areas = []
    for path in sorted(glob.glob(str(a.project / 'scripts/lol2/native_scripts/*.json'))):
        data = json.loads(Path(path).read_text())
        area = data['area']
        areas.append(area)
        owners = collections.defaultdict(list)
        for o in data['objects']:
            for e in o['events']:
                if e.get('group') is not None:
                    owners[(e['stream'], e['group'])].append(dict(owner=o['ref'], kind=e['kind'], record_hex=e['raw_hex'],
                                                                  predicate=(e.get('predicate') or {}).get('index')))
        for g in data['groups']:
            for c in g['commands']:
                if c['opcode'] != 3:
                    continue
                b = bytes.fromhex(c['raw_hex'])
                if len(b) < 12:
                    continue
                identity = struct.unpack_from('<I', b, 4)[0]
                arg = struct.unpack_from('<i', b, 8)[0]
                kinds[(b[1], struct.unpack_from('<H', b, 2)[0] if b[1] != 2 else 'actor')] += 1
                args_seen[arg] += 1
                index = by_identity.get(identity)
                if index is None:
                    unresolved[hex(identity)] += 1
                    continue
                grants[index]['script_grants'].append(dict(area=area, stream=g['stream'], group=g['group'], group_file_offset=g['file_offset'],
                                                           command_file_offset=c['file_offset'], hex=c['raw_hex'], kind=b[1],
                                                           target=struct.unpack_from('<H', b, 2)[0], arg=arg,
                                                           owners=owners.get((g['stream'], g['group']), [])))
        for o in data['objects']:
            if not o['ref'].startswith('actor:') or 'placement_hex' not in o:
                continue
            b = bytes.fromhex(o['placement_hex'])
            if len(b) < 56:
                continue
            identity = struct.unpack_from('<I', b, 52)[0]
            index = by_identity.get(identity)
            if identity and index is not None:
                grants[index]['actor_carried'].append(dict(area=area, actor=o['ref'], placement_file_offset=o.get('file_offset'), identity_hex='%08x' % identity))
    shops = []
    for path in sorted(glob.glob(str(a.project / 'assets/lol2/generated/*shop*/*.json'))):
        try:
            data = json.loads(Path(path).read_text())
        except Exception:
            continue
        def walk(x, key=''):
            if isinstance(x, dict):
                if isinstance(x.get('definition'), int) and 'name' in x:
                    shops.append((x['definition'], dict(shop=os.path.relpath(path, a.project), id=key, name=x['name'])))
                for k, v in x.items():
                    walk(v, k)
            elif isinstance(x, list):
                for v in x:
                    walk(v, key)
        walk(data)
    for index, row in shops:
        if index in grants:
            grants[index]['shop'].append(row)
    classes = collections.Counter()
    no_source = []
    never_placed_with_source = []
    for i, g in grants.items():
        g['sources'] = [k for k in ('placements', 'script_grants', 'actor_carried', 'shop') if g[k]]
        if i in placed:
            g['sources'] = ['placements'] + [k for k in g['sources'] if k != 'placements']
        elif 'placements' in g['sources']:
            g['sources'].remove('placements')
        classes[tuple(g['sources'])] += 1
        if not g['sources']:
            no_source.append(dict(index=i, name=g['name'], handler=g['handler'], ghost=bool(defs[i].get('ghost', False))))
        elif i not in placed:
            never_placed_with_source.append(dict(index=i, name=g['name'], sources=g['sources']))
    summary = dict(definitions=len(grants), placed=len(placed), never_placed=len(grants) - len(placed),
                   script_grant_commands=sum(len(g['script_grants']) for g in grants.values()), unresolved_identities=dict(unresolved),
                   script_grant_kinds={str(k): v for k, v in kinds.most_common()}, script_grant_args={str(k): v for k, v in args_seen.most_common()},
                   definitions_with_script_grants=sum(1 for g in grants.values() if g['script_grants']),
                   definitions_actor_carried=sum(1 for g in grants.values() if g['actor_carried']),
                   definitions_in_shops=sum(1 for g in grants.values() if g['shop']),
                   never_placed_with_a_source=len(never_placed_with_source), no_known_source=len(no_source),
                   source_classes={'+'.join(k) if k else 'none': v for k, v in classes.most_common()}, areas=areas)
    out = dict(version=1, census_sha256=hashlib.sha256(a.census.read_bytes()).hexdigest(), summary=summary,
               never_placed_with_source=never_placed_with_source, no_known_source=no_source,
               definitions=[grants[i] for i in sorted(grants)],
               scope='Opcode 3 = the give-item command as the port\'s hosted Prism/Net of Exile sources decode it (identity dword +4); '
                     'its argument dword +8 and the take / has-item forms are Grok backlog 6 item 3 (pending). Actor dword +52 is a '
                     'carried identity, not proven loot. Shops are the port\'s staged lists. Read-only.')
    a.out.mkdir(parents=True, exist_ok=True)
    (a.out / 'grants.json').write_text(json.dumps(out, indent=1) + '\n')
    lines = ['# Item grant census (step 5), %s' % os.path.basename(str(a.census.parent)), '',
             'Definitions %d: placed in the world %d, never placed %d.' % (summary['definitions'], summary['placed'], summary['never_placed']),
             'Script grants (opcode 3): %d commands over %d levels, every identity resolves; %d definitions granted by scripts.' % (summary['script_grant_commands'], len(areas), summary['definitions_with_script_grants']),
             'Argument dword +8 values: %s (meaning pending Grok backlog 6 item 3).' % summary['script_grant_args'],
             'Kinds: %s.' % summary['script_grant_kinds'],
             'Actor-carried identities (placement +52, LIKELY): %d definitions. Shop lists (port): %d definitions.' % (summary['definitions_actor_carried'], summary['definitions_in_shops']),
             'Never-placed definitions with a source now: %d; definitions with no known source: %d.' % (summary['never_placed_with_a_source'], summary['no_known_source']),
             '', '## Source classes', ''] + ['- %s: %d' % (k, v) for k, v in summary['source_classes'].items()] + \
            ['', '## Never placed, now sourced', ''] + ['- %d %s: %s' % (r['index'], r['name'], ', '.join(r['sources'])) for r in never_placed_with_source] + \
            ['', '## No known source', ''] + ['- %d %s (handler %d%s)' % (r['index'], r['name'], r['handler'], ', ghost row' if r['ghost'] else '') for r in no_source]
    (a.out / 'GRANTS_REPORT.md').write_text('\n'.join(lines) + '\n')
    print(json.dumps(summary)[:1500])


if __name__ == '__main__':
    main()
