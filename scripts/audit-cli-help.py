#!/usr/bin/env python3
"""Read-only audit of every Bushel command/flag against an extracted container CLI.

Does not start a daemon or execute container operations. Build is a plugin and
must be supplied explicitly so an installed older plugin cannot shadow it.
"""
import argparse
import json
from pathlib import Path
import subprocess

COMMANDS = {
    'list': ['--all', '--format'], 'inspect': [], 'start': [], 'stop': [],
    'kill': [], 'delete': [], 'logs': ['--follow', '-n'], 'exec': [],
    'run': ['--detach', '--name', '--memory', '--cpus', '--publish', '--volume', '--env', '--network', '--rm'],
    'network list': ['--format'], 'network create': [], 'network delete': [],
    'volume list': ['--format'], 'volume create': [], 'volume delete': [], 'volume prune': [],
    'system status': ['--format'], 'system df': ['--format'], 'system start': [], 'system stop': [],
    'image list': ['--format'], 'image pull': [], 'image delete': [], 'image tag': [],
    'image prune': ['--all'],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--build-plugin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    results = []
    for command, flags in COMMANDS.items():
        result = subprocess.run([str(args.binary), 'help', *command.split()], capture_output=True, text=True, timeout=30)
        output = result.stdout + result.stderr
        missing = [flag for flag in flags if flag not in output]
        results.append({'command': command, 'returncode': result.returncode, 'missing_flags': missing, 'help': output})
    result = subprocess.run([str(args.build_plugin), '--help'], capture_output=True, text=True, timeout=30)
    output = result.stdout + result.stderr
    results.append({'command': 'build', 'returncode': result.returncode,
                    'missing_flags': [flag for flag in ['--tag', '--progress', '--file'] if flag not in output], 'help': output})
    args.output.write_text(json.dumps(results, indent=2)+'\n')
    failures = [r['command'] for r in results if r['returncode'] or r['missing_flags']]
    print(f'{len(results)} command surfaces checked; failures: {failures}')
    raise SystemExit(bool(failures))


if __name__ == '__main__':
    main()
