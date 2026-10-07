#!/usr/bin/env python3
"""Run the 11-leg earned broken-sword Act One chain (cave → darker jungle) on a private Xvfb display.

Each leg loads the previous leg's actual save (hash-checked inside the test) and writes the next save/proof.
Receipts go to <out>/chain.out as "[HH:MM:SS] <leg> start" / "[HH:MM:SS] <leg> exit=<code>" with one log per leg,
the format tools/audit_fresh_chain_progress.py audits. Stops at the first failing leg. Use a NEW --out directory
for every run (repeated receipts are rejected by the audit). Leg arguments are derived from each test's own
save-path branches (broken-sword branch; see docs/act-one-completion.md).
"""
import argparse, datetime, os, select, shutil, subprocess, sys, tempfile, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
LEGS = [
    ('01_cave', 'cave_opening_route_walk', ['--captain-route', '--starting-spells', '--middle-route', '--bridge-route', '--through-museum', '--route-fast']),
    ('02_museum', 'museum_earned_walk_test', ['--broken-sword']),
    ('03_jungle_hive', 'earned_jungle_hive_walk_test', ['--broken-sword']),
    ('04_flute', 'hive_quest_walk_test', ['--earned-cave-chain', '--broken-sword', '--continue-monastery', '--return-hive']),
    ('05_wax', 'hive_wax_return_test', ['--broken-sword', '--earned-cave-chain']),
    ('06_runes', 'hive_earned_rune_walk_test', ['--broken-sword', '--earned-cave-chain']),
    ('07_rune_return', 'hive_earned_rune_return_test', ['--broken-sword', '--earned-cave-chain']),
    ('08_knowledge', 'broken_magic_knowledge_walk_test', []),
    ('09_translation', 'monastery_rune_offer_test', ['--broken-sword']),
    ('10_repair', 'broken_repair_earned_walk_test', []),
    ('11_departure', 'act_one_departure_walk_test', ['--broken-sword', '--continue-departure']),
]
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True)
    parser.add_argument('--timeout', type=float, default=2400)
    parser.add_argument('--demo-interface', action='store_true', help='Use production demo controls during the earned campaign')
    parser.add_argument('--start', default='01_cave', help='first leg to run (continues an existing chain)')
    args = parser.parse_args()
    out = Path(args.out).resolve()
    if (out / 'chain.out').exists(): parser.error('Use a new --out directory (receipts must be fresh).')
    out.mkdir(parents=True, exist_ok=True)
    xvfb = shutil.which('Xvfb') or str(ROOT / 'tmp/virtual-display/root/usr/bin/Xvfb')
    godot = ['flatpak', 'run', 'org.godotengine.Godot']
    read_fd, write_fd = os.pipe()
    log = (out / 'xvfb.log').open('w+b')
    server = subprocess.Popen([xvfb, '-displayfd', str(write_fd), '-screen', '0', '1280x720x24', '-nolisten', 'tcp', '-noreset'], pass_fds=(write_fd,), stdout=log, stderr=log)
    os.close(write_fd)
    try:
        if not select.select([read_fd], [], [], 10)[0]: raise RuntimeError('Xvfb did not start')
        display = ':' + os.read(read_fd, 32).decode().strip()
        receipts = open(out / 'chain.out', 'a', buffering=1)
        stamp = lambda: datetime.datetime.now().strftime('%H:%M:%S')
        names = [leg[0] for leg in LEGS]
        for name, test, flags in LEGS[names.index(args.start):]:
            receipts.write(f'[{stamp()}] {name} start\n'); print(f'[{stamp()}] {name} start', flush=True)
            command = godot + ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--resolution', '1280x720', '--fixed-fps', '60',
                               '--path', str(ROOT), '--script', f'res://tests/{test}.gd', '--'] + flags + (['--demo-interface'] if args.demo_interface else [])
            with open(out / f'{name}.log', 'w') as leg_log:
                leg_log.write(' '.join(command) + '\n'); leg_log.flush()
                started = time.time()
                try:
                    # Keep the display between clients and diagnose infrastructure before
                    # a Godot startup can spend the entire gameplay timeout waiting on X11.
                    probe = subprocess.run(['xwininfo', '-display', display, '-root'],
                                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=5)
                    if server.poll() is not None or probe.returncode:
                        leg_log.write('ERROR: Private display preflight failed: ' + probe.stderr.decode(errors='replace') + '\n')
                        code = 125
                    else:
                        code = subprocess.run(command, stdout=leg_log, stderr=subprocess.STDOUT, timeout=args.timeout, env={**os.environ, 'DISPLAY': display}, stdin=subprocess.DEVNULL).returncode
                except subprocess.TimeoutExpired:
                    code = 124
            receipts.write(f'[{stamp()}] {name} exit={code}\n'); print(f'[{stamp()}] {name} exit={code} ({time.time()-started:.0f}s)', flush=True)
            if code != 0: return code
        if args.start == names[0]:
            # Only a full fresh 01→11 run earns the completion receipt the audit requires.
            receipts.write(f'[{stamp()}] CHAIN COMPLETE\n'); print(f'[{stamp()}] CHAIN COMPLETE', flush=True)
        return 0
    finally:
        server.terminate(); server.wait(10); log.close()
if __name__ == '__main__':
    sys.exit(main())
