#!/usr/bin/env python3
"""Inspect commands from an actual configured Darling Ninja build."""
import argparse
from pathlib import Path
import shlex
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--build', type=Path, required=True)
parser.add_argument('--foundation', type=Path, required=True)
parser.add_argument('--darwin', type=Path, required=True)
parser.add_argument('--target', choices=('Foundation_x86_64', 'swift_DarwinFoundation1'))
args = parser.parse_args()
failed = False
for target, module, selected in (
    ('Foundation_x86_64', 'Foundation', args.foundation),
    ('swift_DarwinFoundation1', 'Darwin', args.darwin),
):
    if args.target and target != args.target:
        continue
    commands = subprocess.check_output(
        ['ninja', '-C', str(args.build), '-t', 'commands', target], text=True)
    link = next(line for line in reversed(commands.splitlines())
                if '-reexport_library,' in line)
    words = shlex.split(link)
    expected = str(selected.resolve())
    reexport = '-Wl,-reexport_library,' + expected
    if reexport not in words:
        print(f'{target}: missing selected re-export {expected}')
        failed = True
    for guest in (f'/usr/lib/swift/libswift{module}.dylib', f'@rpath/libswift{module}.dylib'):
        prefix = '-Wl,-dylib_file,' + guest + ':'
        mapped = {word[len(prefix):] for word in words if word.startswith(prefix)}
        print(f'{target}: {guest} -> {sorted(mapped)}')
        if mapped != {expected}:
            failed = True
raise SystemExit(1 if failed else 0)
