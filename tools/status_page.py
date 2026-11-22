#!/usr/bin/env python3
"""G-07: the owner's status page, one row per level, ending in "Ready for you? yes/no + reason".

  python3 tools/status_page.py [--out DIR]      writes STATUS.html and STATUS.md (default AI_COMMS/status/)

Reads only files the lanes already write; a missing source shows as "-" with the reason, never as green:
  AI_COMMS/status/levels.json            per level: main_quest ("built" | "partial" | "missing"), note   (lead keeps it)
  grok_research/interactables_census/census.json   objects per level; "must touch" = on_main_chain "yes"
  AI_COMMS/status/press_results.json     {"<area>": {"<class>:<index>": "pass" | "fail"}}  (press tests, G-06/B)
  AI_COMMS/robot/<area>/latest.json      {"date": "YYYY-MM-DD", "stops": N}   (robot walk, G-06)
  AI_COMMS/robot/<area>/judge.json       {"date": ..., "issues": N}           (picture judge, G-10)
  AI_COMMS/playtest_feedback_*/report_*/report.json   owner F10 reports (last walk date per level)
Ready = main quest built, every must-touch object pressed green, robot walk within 2 days with 0 stops.
"""
import argparse
import datetime
import glob
import html
import json
import re
from pathlib import Path

COMMS = Path('~/AI_COMMS')
LEVELS = [  # (area id, name, F2 start id) in play order
    ('L1_DC', 'Cave', ''), ('L2_MU', 'Museum', 'act1-museum-arrival'), ('L4_HJ', 'Huline Jungle', 'act1-jungle-arrival'),
    ('L5_HC', 'Hive', 'act1-hive-entry'), ('L3_DH', 'Dark Halls', 'act1-sword-repaired'),
    ('L8_SJ', 'Savage Jungle', 'act2-l8'), ('L9_DR', 'Dracoid Ruins', 'act2-l9'), ('L10_DC', 'Dracoid Cemetery', 'act2-l10'),
    ('L12_CM', 'Claw Mountains', 'act2-l12'), ('L13_RC', 'Citadel of the Ruloi', 'act2-l13'),
    ('L14_HT', 'Huline Temple', 'act2-l14'), ('L16_CA', 'City of the Ancients', 'act3-l16'),
    ('L17_HC', 'Huline Caverns', 'act3-l17'), ('L19_BC', "Belial's Laboratory", 'act3-l19'),
    ('L20_BB', 'Birthing Chamber', 'act3-l20'),
]
# F10 report "area" strings for levels whose host does not print the area id.
REPORT_NAMES = {'Cave': 'L1_DC', 'Museum': 'L2_MU', 'Jungle': 'L4_HJ', 'Hive': 'L5_HC', 'Dark Halls': 'L3_DH',
                'Darker Jungle': 'L8_SJ'}
FRESH_DAYS = 2


def load(path, default):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return default


def owner_walks():
    last = {}
    for report in glob.glob(str(COMMS / 'playtest_feedback_*/report_*/report.json')):
        data = load(report, {})
        area = str(data.get('area', ''))
        match = re.match(r'(L\d+_[A-Z]+)', area)
        area_id = match[1] if match else REPORT_NAMES.get(area, '')
        day = str(data.get('created_utc', ''))[:10]
        if area_id and day and day > last.get(area_id, ''):
            last[area_id] = day
    return last


def rows(today):
    levels = load(COMMS / 'status/levels.json', {})
    census = load(COMMS / 'grok_research/interactables_census/census.json', {}).get('rows', [])
    presses = load(COMMS / 'status/press_results.json', {})
    walks = owner_walks()
    out = []
    for area, name, start in LEVELS:
        info = levels.get(area, {})
        quest = info.get('main_quest', '?')
        must = [r for r in census if r.get('area') == area and r.get('on_main_chain') == 'yes']
        total = len([r for r in census if r.get('area') == area])
        results = presses.get(area, {})
        green = sum(1 for r in must if results.get(f"{r.get('native_class')}:{r.get('index')}") == 'pass')
        robot = load(COMMS / f'robot/{area}/latest.json', {})
        judge = load(COMMS / f'robot/{area}/judge.json', {})
        robot_day = str(robot.get('date', ''))
        fresh = bool(robot_day) and (today - datetime.date.fromisoformat(robot_day)).days <= FRESH_DAYS
        reasons = []
        if quest != 'built': reasons.append(f'main quest {quest}')
        if must and green < len(must): reasons.append(f'{len(must) - green} must-touch objects not pressed green')
        if not must: reasons.append('no must-touch objects marked in the census yet')
        if not robot_day: reasons.append('no robot walk yet')
        elif not fresh: reasons.append(f'robot walk is older than {FRESH_DAYS} days')
        elif int(robot.get('stops', 1)) > 0: reasons.append(f"robot found {robot.get('stops')} stops")
        out.append({'area': area, 'name': name, 'start': start, 'quest': quest, 'note': info.get('note', ''),
                    'census': f'{green}/{len(must)} must-touch ({total} objects)' if total else '-',
                    'robot': f"{robot_day}: {robot.get('stops', '?')} stops" if robot_day else '-',
                    'judge': f"{judge.get('issues', '?')} issues" if judge else '-',
                    'owner': walks.get(area, '-'),
                    'ready': not reasons, 'why': reasons[0] if reasons else 'robot clean, objects green'})
    out.sort(key=lambda r: (not r['ready'], LEVELS.index(next(l for l in LEVELS if l[0] == r['area']))))
    return out


COLUMNS = [('Ready for you?', 'ready'), ('Level', 'name'), ('F2 start', 'start'), ('Main quest', 'quest'),
           ('Objects (green / must-touch)', 'census'), ('Robot walk', 'robot'), ('Picture judge', 'judge'),
           ('Your last walk', 'owner'), ('Why', 'why')]


def cell(row, key):
    if key == 'ready':
        return 'YES' if row['ready'] else 'no'
    return str(row[key]) if row[key] else '-'


def write(out_dir, table, today):
    out_dir.mkdir(parents=True, exist_ok=True)
    md = [f'# LoL2 status, {today}', '', '| ' + ' | '.join(c for c, _ in COLUMNS) + ' |',
          '|' + '---|' * len(COLUMNS)]
    md += ['| ' + ' | '.join(cell(r, k).replace('|', '/') for _, k in COLUMNS) + ' |' for r in table]
    (out_dir / 'STATUS.md').write_text('\n'.join(md) + '\n')
    head = ''.join(f'<th>{html.escape(c)}</th>' for c, _ in COLUMNS)
    body = ''.join('<tr class="%s">%s</tr>' % ('yes' if r['ready'] else 'no',
                   ''.join(f'<td>{html.escape(cell(r, k))}</td>' for _, k in COLUMNS)) for r in table)
    page = f'''<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>LoL2 status</title>
<style>body{{font-family:system-ui,sans-serif;margin:24px;color:#222}}table{{border-collapse:collapse;width:100%}}
th,td{{border-bottom:1px solid #ddd;padding:6px 8px;text-align:left;font-size:14px}}th{{background:#f4f4f4}}
tr.yes td:first-child{{color:#0a6b2d;font-weight:700}}tr.no td:first-child{{color:#888}}</style></head><body>
<h1>LoL2 status, {today}</h1><p>One row per level. "YES" rows are ready for a 30-minute walk: press F2 and pick the start.</p>
<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table></body></html>
'''
    (out_dir / 'STATUS.html').write_text(page)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--out', default=str(COMMS / 'status'))
    args = parser.parse_args()
    today = datetime.date.today()
    table = rows(today)
    write(Path(args.out), table, today)
    print(f"{sum(r['ready'] for r in table)} of {len(table)} levels ready; wrote {args.out}/STATUS.html and STATUS.md")


if __name__ == '__main__':
    main()
