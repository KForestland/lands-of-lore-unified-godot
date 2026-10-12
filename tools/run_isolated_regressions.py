#!/usr/bin/env python3
"""Run the existing Godot regression runner on a private Xvfb display."""
import argparse
import os
from pathlib import Path
import select
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__, add_help=False)
    parser.add_argument('--xvfb', type=Path)
    options, forwarded = parser.parse_known_args()
    executable = options.xvfb or shutil.which('Xvfb')
    if not executable:
        local = ROOT / 'tmp/virtual-display/root/usr/bin/Xvfb'
        if local.is_file():
            executable = local
    if not executable:
        parser.error('Xvfb is required; supply --xvfb /path/to/Xvfb. No game assets are supplied by this wrapper.')
    read_fd, write_fd = os.pipe()
    with tempfile.TemporaryFile() as log:
        server = subprocess.Popen([str(executable), '-displayfd', str(write_fd),
                                   '-screen', '0', '1280x720x24', '-nolisten', 'tcp'],
                                  pass_fds=(write_fd,), stdout=log, stderr=log)
        os.close(write_fd)
        try:
            if not select.select([read_fd], [], [], 10)[0]:
                raise RuntimeError('Xvfb did not announce a display within10 seconds')
            display = os.read(read_fd, 32).decode().strip()
            if not display.isdecimal():
                log.seek(0)
                raise RuntimeError('Xvfb failed: ' + log.read().decode(errors='replace')[-3000:])
            print('Isolated rendered display :' + display, flush=True)
            return subprocess.call([sys.executable, str(ROOT / 'tools/run_regressions.py'),
                                    *forwarded, '--display', ':' + display], cwd=ROOT)
        finally:
            os.close(read_fd)
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()

if __name__ == '__main__':
    sys.exit(main())
