#!/usr/bin/env python3
"""docs/DEVIATIONS.md from one file per row (WORKFLOW_PLAN W4, 2026-10-31).

docs/deviations/ holds the ledger as ordered pieces: `NNNN-row-<date>-<slug>.md` = exactly one table row (one line), and
`NNNN-text-<slug>.md` = a verbatim block of the lines between rows (headings, prose, table headers, blank lines). `build`
concatenates them in NNNN order into docs/DEVIATIONS.md; the result is byte-identical to the hand-kept file this tool
was split from. `--check` renders to memory and fails (exit 1) when docs/DEVIATIONS.md differs: a hand edit of the rendered
file, or a piece changed without re-rendering. `split` (one-time import) cuts an existing DEVIATIONS.md into pieces.
Add a row: create the next `NNNN-row-...md` (one line, starting with `| `) and run `build`.

  python3 tools/build_deviations.py build        # render docs/DEVIATIONS.md
  python3 tools/build_deviations.py --check      # exit 1 when the rendering and the file differ
  python3 tools/build_deviations.py split        # import docs/DEVIATIONS.md into docs/deviations/ (refuses a non-empty folder)
"""
import argparse, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / 'docs/DEVIATIONS.md'
PIECES = ROOT / 'docs/deviations'
ROW = re.compile(r'^\| \d{4}-\d{2}-\d{2} \|')


def slug(text, limit=48):
    s = re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-')
    return s[:limit].rstrip('-') or 'piece'


def pieces():
    files = sorted(p for p in PIECES.glob('*.md') if re.match(r'^\d{4}-', p.name))
    # W16 (2026-11-01): equal numbers are allowed and render in name order, so two lanes adding pieces never renumber.
    return files


def render():
    out = []
    for p in pieces():
        text = p.read_text()
        if '-row-' in p.name:
            lines = text.splitlines()
            if len(lines) != 1 or not ROW.match(lines[0]):
                raise SystemExit(f'{p.name}: a row piece holds exactly one table row starting with "| YYYY-MM-DD |"')
            out.append(lines[0] + '\n')
        else:
            out.append(text)
    return ''.join(out)


def split():
    if PIECES.exists() and any(PIECES.iterdir()):
        raise SystemExit(f'{PIECES} is not empty; split only imports into an empty folder')
    PIECES.mkdir(parents=True, exist_ok=True)
    lines = LEDGER.read_text().splitlines(keepends=True)
    n = 0
    block = []

    def flush_text():
        nonlocal n, block
        if not block:
            return
        n += 1
        first = next((l for l in block if l.strip() and not l.startswith('|')), block[0])
        (PIECES / f'{n:04d}-text-{slug(first.strip("# \n"))}.md').write_text(''.join(block))
        block = []
    for line in lines:
        if ROW.match(line):
            flush_text()
            n += 1
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            (PIECES / f'{n:04d}-row-{cells[0]}-{slug(cells[1])}.md').write_text(line if line.endswith('\n') else line + '\n')
        else:
            block.append(line)
    flush_text()
    print(f'split {LEDGER.name} into {n} pieces under {PIECES}')


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('command', nargs='?', choices=['build', 'split'])
    p.add_argument('--check', action='store_true')
    a = p.parse_args()
    if a.command == 'split':
        split()
        return
    text = render()
    if a.check:
        current = LEDGER.read_text() if LEDGER.exists() else ''
        if current != text:
            sys.exit('docs/DEVIATIONS.md differs from the rendering of docs/deviations/: edit the pieces and run tools/build_deviations.py build')
        print('PASS deviations: docs/DEVIATIONS.md matches docs/deviations/ (%d pieces)' % len(pieces()))
        return
    if a.command == 'build':
        LEDGER.write_text(text)
        print('built %s from %d pieces' % (LEDGER, len(pieces())))
        return
    p.error('give build, split or --check')


if __name__ == '__main__':
    main()
