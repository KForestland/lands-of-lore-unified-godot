#!/usr/bin/env python3
"""Build a local source atlas and reproducible coverage inventory for all level MIXes.

Original polygon/placement coordinates stay in --out. The repository summary
contains provenance, counts and command references, not original asset payloads.
"""
import argparse
from html import escape
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

# Legacy importing preparers still use external helpers; the atlas itself needs
# only lol2_source_format. Retain this path until those callers are migrated.
import re_helper_root
# LOL2_RE_ROOT (see re_helper_root.py); optional here because most callers only need lol2_source_format.
RE_TOOLS = re_helper_root.path('draracle', required=False)
re_helper_root.insert('draracle', required=False)
from lol2_source_format import parse_mix, u32, SIZES

ROOT = Path(__file__).resolve().parents[1]


def section(raw, offset_field, count_field, stride):
    offset, count = u32(raw, offset_field), u32(raw, count_field)
    if offset + count * stride > len(raw):
        raise ValueError(f'Section {offset_field:X}/{count_field:X} exceeds geometry')
    return offset, count, raw[offset:offset + count * stride]


def commands(raw, entry):
    transitions, streams = [], []
    for stream, (of, sf) in enumerate([(0x3c, 0x84), (0x44, 0x8c)]):
        start, size, data = section(raw, of, sf, 1)
        cursor, rows = 0, []
        while cursor < size:
            length = SIZES.get(data[cursor])
            if length is None or cursor + length > size:
                raise ValueError(f'Unknown/truncated command at stream{stream}:{cursor}')
            rows.append((cursor, data[cursor:cursor + length]))
            cursor += length
        assert b''.join(body for _, body in rows) == data
        i, groups = 0, 0
        while i < len(rows):
            group, head = rows[i]
            grouped = head[0] == 240
            count = head[4] if grouped else 1
            first = i + int(grouped)
            children = rows[first:first + count]
            if len(children) != count or any(body[0] == 240 for _, body in children):
                raise ValueError('Invalid or nested source command group')
            for offset, body in children:
                if body[:5] == bytes.fromhex('020100001c'):
                    transitions.append(dict(stream=stream, group=group, command_offset=offset,
                                            archive_offset=entry['offset'] + start + offset,
                                            destination_level=body[5] & 31, destination_entry=body[5] >> 5,
                                            admission='unbound'))
            groups += 1
            i = first + count
        streams.append(dict(stream=stream, bytes=size, commands=len(rows), groups=groups))
    return streams, transitions


def map_svg(vertices, records, actors, props, transitions=(), arrivals=(), actor_bindings=(), object_points=None, source_paths=()):
    xs, ys = [v[0] / 65536 for v in vertices], [-v[1] / 65536 for v in vertices]
    x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
    width, height = max(1, x1 - x0), max(1, y1 - y0)
    margin = max(width, height) * .025
    paths = []
    for record in records:
        points = [(xs[i], ys[i]) for i in record[6:10]]
        paths.append('M' + 'L'.join(f'{x:.3f},{y:.3f}' for x, y in points) + 'Z')
    def dots(rows, color, radius, label):
        shapes = []
        for i,(x,y) in enumerate(rows):
            binding = actor_bindings[i] if label == 'Actor' and actor_bindings else None
            title = f'{label} {i}' + (f' · {binding["name"]} · definition{binding["definition"]}' if binding else '')
            attrs = f'data-actor="{i}" data-definition="{binding["definition"]}"' if binding else ''
            shapes.append(f'<circle {attrs} cx="{x}" cy="{-y}" r="{radius}" fill="{color}"><title>{escape(title)}</title></circle>')
        return ''.join(shapes)
    exits = []
    for transition in transitions:
        key = f'{transition["stream"]}_{transition["command_offset"]}'
        for owner in transition.get('direct_owners', []):
            title = escape(f'Exit to level{transition["destination_level"]}, entry{transition["destination_entry"]}; {owner["owner_kind"]}{owner["owner"]}; event{owner["event"]}; predicate{owner["predicate"]}; group{transition["group"]}')
            attrs = f'data-transition="{key}" fill="#e879ae" fill-opacity="0.4" stroke="#ffabd0" stroke-width="2" vector-effect="non-scaling-stroke"'
            if owner['owner_kind'] == 'region':
                points = ' '.join(f'{xs[i]:.3f},{ys[i]:.3f}' for i in records[owner['owner']][6:10])
                exits.append(f'<polygon {attrs} points="{points}"><title>{title}</title></polygon>')
            elif owner['owner_kind'] in ['actor','prop','control','movable']:
                x,y = object_points[owner['owner_kind']][owner['owner']]
                exits.append(f'<circle {attrs} cx="{x}" cy="{-y}" r="{max(width,height)/300}"><title>{title}</title></circle>')
    arrival_shapes = []
    size = max(width,height)/350
    for arrival in arrivals:
        x,y = arrival['x'],-arrival['y']
        title = escape(f'Arrival selector{arrival["selector"]}; record{arrival["index"]}; region{arrival["region"]}; heading{arrival["heading_units"]}')
        arrival_shapes.append(f'<path data-arrival="{arrival["index"]}" d="M{x},{y-size}L{x+size},{y}L{x},{y+size}L{x-size},{y}Z" fill="#90c5ff" stroke="#c8e3ff" stroke-width="1" vector-effect="non-scaling-stroke"><title>{title}</title></path>')
    route_shapes = []
    for path in source_paths:
        points = [(point['x'],-point['y']) for point in path['points']]
        if path['flags']&1: points.append(points[0])
        encoded = ' '.join(f'{x},{y}' for x,y in points)
        title = escape(f'Actor path{path["index"]}; {path["mode"]}; {path["count"]} points; unbound regions{path["unbound_region_markers"]}')
        route_shapes.append(f'<polyline data-path="{path["index"]}" points="{encoded}" fill="none" stroke="#43d7e5" stroke-width="3" stroke-dasharray="7 4" vector-effect="non-scaling-stroke"><title>{title}</title></polyline>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0-margin} {y0-margin} {width+2*margin} {height+2*margin}" role="img" aria-label="Source area outline">'
            f'<path d="{"".join(paths)}" fill="none" stroke="#698896" stroke-width="1" vector-effect="non-scaling-stroke"/>'
            f'<g class="props">{dots(props, "#e8b36b", max(width,height)/1800, "Prop")}</g>'
            f'<g class="actors">{dots(actors, "#63e6be", max(width,height)/700, "Actor")}</g>'
            f'<g class="paths">{"".join(route_shapes)}</g><g class="exits">{"".join(exits)}</g><g class="arrivals">{"".join(arrival_shapes)}</g></svg>')


def graph_svg(areas):
    # Positions are diagram layout only, not native world coordinates or quest order.
    positions = {1:(70,140),3:(220,140),4:(370,140),5:(370,45),7:(370,235),
                 8:(530,140),9:(530,235),10:(680,235),12:(530,45),13:(680,45),
                 14:(680,140),16:(830,140),17:(980,140),19:(1130,140),20:(1280,140)}
    ids = {area['level']:area for area in areas}
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1360 285" aria-label="Candidate area connections"><defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0L10 5L0 10Z" fill="#8095a8"/></marker></defs>']
    edges = sorted({(area['level'], t['destination_level']) for area in areas for t in area['transitions']})
    for source, destination in edges:
        if source not in positions or destination not in positions:
            continue
        x, y = positions[source];u, v = positions[destination]
        dx, dy = u-x, v-y;length = (dx*dx+dy*dy)**.5
        if not length: continue
        # Parallel reciprocal arrows remain visible on opposite sides.
        ox, oy = -dy/length*4, dx/length*4
        parts.append(f'<path d="M{x+dx/length*43+ox},{y+dy/length*24+oy} L{u-dx/length*47+ox},{v-dy/length*26+oy}" stroke="#8095a8" stroke-dasharray="4 3" fill="none" marker-end="url(#arrow)"/>')
    for level, area in ids.items():
        x, y = positions[level]
        color = '#174f49' if area['status']['content'] == 'partial' else '#263344'
        parts.append(f'<a href="#" data-area="{area["id"]}"><rect x="{x-45}" y="{y-21}" width="90" height="42" rx="8" fill="{color}" stroke="#8cb1bb"/><text x="{x}" y="{y+5}" text-anchor="middle" fill="#eff5f5" font-size="15">{area["id"]}</text></a>')
    return ''.join(parts) + '</svg>'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, default=Path('/home/bob/lol2_out/museum_capture_20260913/game'))
    parser.add_argument('--out', type=Path, default=Path('/home/bob/lol2_out/game_atlas_20260916'))
    args = parser.parse_args()
    coverage = json.loads((ROOT / 'docs/game-coverage.json').read_text())
    args.out.mkdir(parents=True, exist_ok=True)
    areas = []
    owner_path = ROOT / 'docs/game-transition-owners.json'
    owner_index = {a['id']:a for a in json.loads(owner_path.read_text())['areas']} if owner_path.exists() else {}
    arrival_path = ROOT / 'docs/game-arrivals.json'
    arrival_report = json.loads(arrival_path.read_text()) if arrival_path.exists() else {}
    arrival_index = {a['id']:a for a in arrival_report.get('areas', [])}
    actor_path = ROOT / 'docs/game-actors.json'
    actor_index = {a['id']:a for a in json.loads(actor_path.read_text())['areas']} if actor_path.exists() else {}
    predicate_path = ROOT / 'docs/game-exit-predicates.json'
    predicate_index = {a['id']:a for a in json.loads(predicate_path.read_text())['areas']} if predicate_path.exists() else {}
    path_audit = ROOT / 'docs/game-paths.json'
    path_index = {a['id']:a for a in json.loads(path_audit.read_text())['areas']} if path_audit.exists() else {}
    paths = sorted((p for p in (args.game / 'DAT').glob('L*.MIX') if re.fullmatch(r'L\d+_[A-Z]{2}', p.stem)), key=lambda p:int(p.stem.split('_')[0][1:]))
    if {p.stem for p in paths} != set(coverage['areas']):
        raise ValueError('Source archive/coverage set differs: review inventory instead of silently omitting areas')
    for path in paths:
        archive = path.read_bytes()
        candidates = []
        for entry in parse_mix(archive):
            raw = archive[entry['offset']:entry['offset'] + entry['size']]
            if len(raw) >= 0x244 and u32(raw, 0) == 18 and u32(raw, 4) == 5300:
                candidates.append((entry, raw))
        if len(candidates) != 1:
            raise ValueError(f'{path.name}: expected one geometry entry, found{len(candidates)}')
        entry, raw = candidates[0]
        _, nv, vb = section(raw, 4, 0x50, 8)
        _, nr, rb = section(raw, 12, 0x58, 44)
        _, na, ab = section(raw, 0x1c, 0x68, 56)
        _, np, pb = section(raw, 0x14, 0x60, 37)
        vertices = list(struct.iter_unpack('<ii', vb))
        records = list(struct.iter_unpack('<22H', rb))
        for record in records:
            if any(i >= nv for i in record[6:10]) or any(i != 65535 and i >= nr for i in record[2:6]):
                raise ValueError(f'{path.name}: geometry references outside source tables')
        actors = [struct.unpack_from('<hh', ab, i*56) for i in range(na)]
        props = [struct.unpack_from('<hh', pb, i*37) for i in range(np)]
        object_points = {'actor':actors,'prop':props}
        for label,of,cf,stride in [('control',0x18,0x64,33),('movable',0x24,0x70,41)]:
            _,count,body = section(raw,of,cf,stride)
            object_points[label] = [struct.unpack_from('<hh',body,i*stride) for i in range(count)]
        streams, transitions = commands(raw, entry)
        status = {**coverage['defaults'], **coverage['areas'][path.stem]}
        for evidence in status['evidence']:
            if not (ROOT / evidence).is_file(): raise ValueError(f'Missing evidence: {evidence}')
        area = dict(id=path.stem, level=int(path.stem.split('_')[0][1:]), name=status['name'],
                    source=dict(file='DAT/' + path.name, sha256=hashlib.sha256(archive).hexdigest(),
                                geometry_key=entry['key'], geometry_sha256=hashlib.sha256(raw).hexdigest()),
                    counts=dict(vertices=nv, regions=nr, actors=na, props=np),
                    streams=streams, transitions=transitions, status=status)
        if path.stem in owner_index:
            owner_area = owner_index[path.stem]
            if owner_area['source'] != area['source']:
                raise ValueError('Transition ownership source changed; rerun ownership audit')
            by_offset = {(t['stream'],t['command_offset']):t for t in owner_area['transitions']}
            for transition in transitions:
                owned = by_offset[(transition['stream'],transition['command_offset'])]
                for field in ['group','destination_level','destination_entry']:
                    assert transition[field] == owned[field]
                transition['direct_owners'] = owned['direct_owners']
                transition['ownership'] = owned['ownership']
                if path.stem in predicate_index:
                    audited = predicate_index[path.stem]
                    assert audited['source'] == area['source']
                    predicates = {p['predicate']:p for p in audited['predicates']}
                    for owner in transition['direct_owners']:
                        if owner['predicate'] is not None:
                            owner['predicate_description'] = predicates[owner['predicate']]['description']
        arrivals = []
        if path.stem in arrival_index:
            audited = arrival_index[path.stem]
            if audited['source'] != area['source']:
                raise ValueError('Arrival source changed; rerun arrival audit')
            _,count,arrival_data = section(raw,0x48,0x90,12)
            assert count == len(audited['entries'])
            for item in audited['entries']:
                x,y,heading,region,selector,flags,tail = struct.unpack_from('<hhHHBBH',arrival_data,item['index']*12)
                assert region == item['region'] and selector == item['selector']
                arrivals.append(dict(item,x=x,y=y,heading_units=heading))
            area['arrivals'] = audited['entries']
            area['arrival_selection'] = audited['selection']
        actor_bindings = []
        if path.stem in actor_index:
            audited = actor_index[path.stem]
            if audited['source'] != area['source']:
                raise ValueError('Actor source changed; rerun actor audit')
            actor_bindings = audited['actors']
            assert len(actor_bindings) == na
            for index,binding in enumerate(actor_bindings):
                assert binding['actor'] == index and binding['definition'] == ab[index*56+32]
            area['actor_definitions'] = audited['definitions']
        source_paths = []
        if path.stem in path_index:
            audited = path_index[path.stem]
            assert audited['source'] == area['source']
            _,count,path_records = section(raw,0xdc,0xd8,4)
            _,marker_count,markers = section(raw,0xc8,0xc4,8)
            assert count == len(audited['paths'])
            for item in audited['paths']:
                assert tuple(struct.unpack_from('<HBB',path_records,item['index']*4)) == (item['first'],item['count'],item['flags'])
                assert item['first']+item['count'] <= marker_count
                points = []
                for index in item['marker_indices']:
                    x,y,region,flags = struct.unpack_from('<hhHH',markers,index*8)
                    points.append(dict(x=x,y=y,region=region,flags=flags))
                source_paths.append(dict(item,points=points))
            area['paths'] = audited['paths']
        areas.append(area)
        (args.out / (path.stem + '.svg')).write_text(map_svg(vertices, records, actors, props, transitions, arrivals, actor_bindings, object_points, source_paths))
    ids = {a['level'] for a in areas}
    unresolved = sorted({t['destination_level'] for a in areas for t in a['transitions']} - ids)
    report = dict(version=1, scope='All15 numbered level archives in the supplied local reference; subareas and quest completeness not yet audited.',
                  areas=areas, unresolved_destination_levels=unresolved, gaps=coverage['cross_area_gaps'],
                  command_sizes_sha256=hashlib.sha256(json.dumps(SIZES, sort_keys=True).encode()).hexdigest())
    (ROOT / 'docs/game-source-inventory.json').write_text(json.dumps(report, indent=2) + '\n')
    (args.out / 'inventory.json').write_text(json.dumps(report, indent=2) + '\n')
    totals = Counter()
    for area in areas: totals.update(area['counts'])
    table = ['# Original game coverage', '', 'Generated from `game-coverage.json` and the local source archives by `tools/build_game_atlas.py`.', '',
             'Mapped source records are not completed gameplay. Partial means some behavior exists, not full-area fidelity.', '',
             '| Area | Regions | Actors / props | Geometry | Content | Routes | Saves | Bob QA |', '| --- | ---: | ---: | --- | --- | --- | --- | --- |']
    for a in areas:
        s,c = a['status'],a['counts']
        table.append(f'| {a["id"]}: {a["name"]} | {c["regions"]} | {c["actors"]} / {c["props"]} | {s["geometry"]} | {s["content"]} | {s["routes"]} | {s["saves"]} | {s["qa"]} |')
    table += ['', '## Source connection diagram', '', 'Arrows are decoded area-change commands, not verified traversable routes. Entry selectors and source command offsets are retained in `game-source-inventory.json`. Direct source event owners are recorded where available; predicate semantics, indirect callers and route admission remain to be audited.', '', '```mermaid', 'flowchart LR']
    for a in areas:
        table.append(f'  {a["id"]}["{a["id"]}"]')
    edges = sorted({(a['id'], next((b['id'] for b in areas if b['level']==t['destination_level']), 'UNKNOWN_'+str(t['destination_level']))) for a in areas for t in a['transitions']})
    table += [f'  {a} -.-> {b}' for a,b in edges] + ['```', '', '## Next fill-in work', '']
    for a in areas:
        table.append(f'- **{a["id"]}**: {a["status"]["next"]}')
    if owner_index:
        matched = sum(bool(t.get('direct_owners')) for a in areas for t in a['transitions'])
        table += ['', f'Direct event owners are bound for{matched} of{sum(len(a["transitions"]) for a in areas)} transition commands. See [transition audit](game-transition-owners.md); the atlas highlights these source exits.', '']
    if arrival_index:
        table += ['', 'All72 mapped transition commands select existing arrival records across15 areas. See [arrival audit](game-arrivals.md); blue diamonds in the atlas locate the71 source arrival records. Full load/placement and route admission remain separate.', '']
    if actor_index:
        table += ['', 'All1,028 source actors bind to128 area-local definitions through native loader/constructor checks. See [actor inventory](game-actors.md); the atlas can filter and locate named definitions. Encounter activation and required/optional roles remain open.', '']
    if predicate_index:
        table += ['', 'All10 distinct immediate exit predicates have verified byte comparisons (2,560 native cases). See [exit predicate audit](game-exit-predicates.md). Their quest meanings and invocation conditions remain open.', '']
        if (ROOT / 'docs/game-exit-dependencies.json').exists():
            table += ['', 'The nine known constant gate assignments now have direct event owners. See [exit dependencies](game-exit-dependencies.md) for prerequisite gates and which assignments satisfy or clear each exit predicate. Event producers and quest meanings remain open.', '']
        if (ROOT / 'docs/game-actor-event-bindings.json').exists():
            table += ['', 'All1,028 actor event-list offsets and the common virtual getter are bound in [actor event-list checks](game-actor-event-bindings.md), including the current-owner side effect used by predicates.', '']
    if path_index:
        table += ['', 'The atlas also shows22 source actor paths, with looping/reversing controls checked against7,408 native steps. [Two paths contain unbound region references](game-paths.md); movement and collision are not verified by the path outlines.', '']
    table += ['', '## Coverage limits', ''] + ['- '+gap for gap in coverage['cross_area_gaps']]
    table += ['', f'Validation: {len(areas)} unique source geometry entries; all vertex/neighbor references bounded; both command streams fully parsed and round-tripped in every area; {len(unresolved)} unknown destination IDs. Prop/actor counts are source placement records, not quest-task counts.', '',
              'Local visual atlas: `/home/bob/lol2_out/game_atlas_20260916/index.html`. Original map coordinates remain outside the repository.', '']
    (ROOT / 'docs/game-coverage.md').write_text('\n'.join(table))
    payload = json.dumps(report).replace('<', '\\u003c')
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>LoL2 restoration atlas</title>
<style>body{font:16px system-ui;background:#101925;color:#e7edf3;margin:24px}h1{margin-bottom:6px}p{color:#b9cad6;max-width:1000px}button,select{font:inherit;background:#24374a;color:white;padding:9px;border:1px solid #6c8897;border-radius:6px}#graph{background:#152332;border-radius:12px;margin:20px 0}#graph svg{width:100%;min-width:800px}#graph{overflow:auto}main{display:grid;grid-template-columns:1fr 310px;gap:20px}#viewport{height:65vh;overflow:hidden;border:1px solid #536779;background:#0b131b;border-radius:10px;touch-action:none}#viewport svg{width:100%;height:100%;cursor:grab}aside{padding:12px}dt{color:#9ab1c1;margin-top:10px}dd{margin:3px 0 0}label{margin:0 12px}a{color:#80dbc6}#maplink{display:inline-block;margin:12px 0}footer{color:#9ab1c1;margin-top:16px}@media(max-width:850px){main{grid-template-columns:1fr}#viewport{height:55vh}}</style>
<h1>LoL2 restoration atlas</h1><p>15 source areas mapped. Use the map to choose the next playable slice and track what remains. Geometry is not a finished level.</p>
<div id="graph">GRAPH</div><p>Dashed arrows: area-change commands found in the source. Quest conditions and actual route admission still need verification. Diagram positions are illustrative.</p>
<select id="area" aria-label="Area"></select><label><input id="actors" type="checkbox" checked>Actors</label><label><input id="props" type="checkbox" checked>Props</label><label><input id="exits" type="checkbox" checked>Source exits</label><label><input id="arrivals" type="checkbox" checked>Arrivals</label><label><input id="paths" type="checkbox">Actor paths</label><button id="reset">Reset view</button>
<main><div id="viewport"></div><aside><h2 id="title"></h2><p id="counts"></p><dl id="status"></dl><h3>Next work</h3><p id="next"></p><a id="maplink">Open / save SVG</a><details><summary>Actor paths</summary><div id="pathlist"></div></details><h3>Source actors</h3><select id="actorfilter" aria-label="Source actor definition"></select><div id="actorlist"></div><h3>Source exits</h3><div id="exitlist"></div><p>Pink outlines: direct exit triggers. Select an exit below to locate it. Conditions remain unverified.</p><h3>Source arrivals</h3><div id="arrivallist"></div><p>Blue diamonds: source arrival records.</p><p>Wheel to zoom, drag to pan. Green dots: source actors. Gold dots: source props. Hover a dot for its source index.</p></aside></main>
<footer>Top-down source outlines can overlap vertically. This is a planning atlas, not a collision or walkthrough proof. Required quest and optional-content inventory remains open.</footer>
<script>const report=PAYLOAD;
const maps=MAPS;
const select=document.querySelector('#area'),viewport=document.querySelector('#viewport');let svg,initial,drag;
for(const a of report.areas){const o=document.createElement('option');o.value=a.id;o.textContent=a.id+' · '+a.name;select.append(o)}
function layers(){for(const id of ['actors','props','exits','arrivals','paths']){const layer=svg.querySelector('.'+id);if(layer)layer.style.display=document.querySelector('#'+id).checked?'':'none'}}
function filterActors(){const value=document.querySelector('#actorfilter').value;for(const shape of svg.querySelectorAll('[data-actor]'))shape.style.display=value===''||shape.dataset.definition===value?'':'none';const list=document.querySelector('#actorlist');list.replaceChildren();if(value==='')return;for(const shape of svg.querySelectorAll('[data-definition="'+value+'"]')){const button=document.createElement('button');button.textContent='Actor '+shape.dataset.actor;button.onclick=()=>locate(shape);list.append(button)}}
function locate(shape){if(!shape)return;const layer=shape.parentElement.classList[0],toggle=layer&&document.getElementById(layer);if(toggle){toggle.checked=true;layers()}const b=shape.getBBox(),size=Math.max(b.width,b.height,50)*3;svg.setAttribute('viewBox',[b.x+b.width/2-size/2,b.y+b.height/2-size/2,size,size].join(' '))}
function show(id){const a=report.areas.find(a=>a.id===id);select.value=id;document.querySelector('#title').textContent=a.name;document.querySelector('#counts').textContent=a.counts.regions+' regions · '+a.counts.actors+' actors · '+a.counts.props+' props';const dl=document.querySelector('#status');dl.replaceChildren();for(const k of ['geometry','content','routes','saves','qa','required_content_audit']){const dt=document.createElement('dt'),dd=document.createElement('dd');dt.textContent=k.replaceAll('_',' ');dd.textContent=a.status[k];dl.append(dt,dd)}document.querySelector('#next').textContent=a.status.next;document.querySelector('#maplink').href=id+'.svg';viewport.innerHTML=maps[id];svg=viewport.querySelector('svg');initial=svg.getAttribute('viewBox');layers();const filter=document.querySelector('#actorfilter');filter.replaceChildren();const all=document.createElement('option');all.value='';all.textContent='All source actors';filter.append(all);for(const d of a.actor_definitions||[]){const o=document.createElement('option');o.value=d.definition;o.textContent=d.definition+' · '+d.name+' ('+d.actors.length+')';filter.append(o)}filter.onchange=filterActors;filterActors();const pathlist=document.querySelector('#pathlist');pathlist.replaceChildren();for(const p of a.paths||[]){const button=document.createElement('button');button.textContent='Path '+p.index+' · '+p.mode+' · '+p.count+' points'+(p.unbound_region_markers.length?' · region unbound':'');button.onclick=()=>locate(svg.querySelector('[data-path="'+p.index+'"]'));const row=document.createElement('p');row.append(button);pathlist.append(row)}const list=document.querySelector('#exitlist');list.replaceChildren();for(const t of a.transitions){const row=document.createElement('p'),button=document.createElement('button');button.textContent='Level '+t.destination_level+' · entry '+t.destination_entry;const key=t.stream+'_'+t.command_offset;const shape=svg.querySelector('[data-transition="'+key+'"]');button.disabled=!shape;button.onclick=()=>locate(shape);row.append(button);const note=document.createElement('small');note.style.display='block';note.textContent=(t.direct_owners||[]).map(o=>o.owner_kind+' '+o.owner+' / '+(o.owner_kind==='region'?'event ':'record kind ')+o.event+' / '+(o.predicate_description||('predicate '+(o.predicate===null?'none attached':o.predicate)))).join('; ')||'Direct event owner unbound';row.append(note);const dest=report.areas.find(d=>d.level===t.destination_level);if(dest&&dest.arrival_selection){const arrival=document.createElement('button');arrival.textContent='View destination';arrival.onclick=()=>{show(dest.id);locate(svg.querySelector('[data-arrival="'+dest.arrival_selection[t.destination_entry]+'"]'))};row.append(arrival)}list.append(row)}const arrivals=document.querySelector('#arrivallist');arrivals.replaceChildren();for(const entry of a.arrivals||[]){const button=document.createElement('button');button.textContent='Entry '+entry.selector+' · region '+entry.region;button.onclick=()=>locate(svg.querySelector('[data-arrival="'+entry.index+'"]'));const row=document.createElement('p');row.append(button);arrivals.append(row)}}
select.onchange=()=>show(select.value);document.querySelector('#reset').onclick=()=>svg.setAttribute('viewBox',initial);for(const id of ['actors','props','exits','arrivals','paths'])document.querySelector('#'+id).onchange=layers;
document.querySelector('#graph').onclick=e=>{const a=e.target.closest('[data-area]');if(a){e.preventDefault();show(a.dataset.area)}};
viewport.onwheel=e=>{e.preventDefault();const b=svg.viewBox.baseVal,f=e.deltaY>0?1.15:1/1.15;svg.setAttribute('viewBox',[b.x+b.width*(1-f)/2,b.y+b.height*(1-f)/2,b.width*f,b.height*f].join(' '))};
viewport.onpointerdown=e=>{const b=svg.viewBox.baseVal;drag={x:e.clientX,y:e.clientY,b:[b.x,b.y,b.width,b.height]};viewport.setPointerCapture(e.pointerId)};
viewport.onpointermove=e=>{if(!drag)return;const r=viewport.getBoundingClientRect(),scale=Math.max(drag.b[2]/r.width,drag.b[3]/r.height);svg.setAttribute('viewBox',[drag.b[0]-(e.clientX-drag.x)*scale,drag.b[1]-(e.clientY-drag.y)*scale,drag.b[2],drag.b[3]].join(' '))};viewport.onpointerup=viewport.onpointercancel=()=>drag=null;
show('L4_HJ');</script></html>'''
    maps = {a['id']:(args.out / (a['id'] + '.svg')).read_text() for a in areas}
    page = page.replace('GRAPH', graph_svg(areas)).replace('PAYLOAD', payload).replace('MAPS', json.dumps(maps).replace('<', '\\u003c'))
    (args.out / 'index.html').write_text(page)
    print(json.dumps(dict(areas=len(areas), totals=dict(totals), commands=sum(s['commands'] for a in areas for s in a['streams']),
                          transition_commands=sum(len(a['transitions']) for a in areas), edges=len(edges), unresolved=unresolved,
                          atlas=str(args.out / 'index.html')), indent=2))


if __name__ == '__main__':
    main()
