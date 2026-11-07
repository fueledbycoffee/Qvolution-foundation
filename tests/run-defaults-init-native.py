#!/usr/bin/env python3
"""Run verbatim production singleton/setter methods with native dependency doubles.
Use qv-slot build. --revision 460a776 --expect-init-deadlock proves the regression.
Full CFPreferences/AppKit/controller integration is deliberately not simulated.
"""
import argparse
from pathlib import Path
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--revision')
p.add_argument('--expect-init-deadlock', action='store_true')
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
out = a.out.resolve()
out.mkdir(parents=True, exist_ok=True)
source = (subprocess.check_output(['git', '-C', str(root), 'show', a.revision + ':src/NSUserDefaults.m'], text=True)
          if a.revision else (root / 'src/NSUserDefaults.m').read_text())
methods = []
for signature in ['+ (NSUserDefaults *)standardUserDefaults', '+ (void)resetStandardUserDefaults',
                  '- (void)setObject:(id)value forKey:', '- (void)removeObjectForKey:']:
    start = source.index(signature)
    end = source.index('\n}', start) + 2
    methods.append(source[start:end])
(out / 'defaults-init-methods.inc').write_text('\n'.join(methods) + '\n')
include = subprocess.check_output(['gcc', '-print-file-name=include'], text=True).strip()
# Same native BlocksRuntime already used by tests/run-foundation2-native.py.
blocks = '/home/sean/Documents/Codex/Projects/Qvolution-work/toolchains/swift-6.3.3-linux-x64/compiler/usr/lib/swift/linux'
command = ['clang', '-g', '-O0', '-Werror', '-fblocks', '-fconstant-string-class=NSString',
           '-I' + include, '-I' + str(out), str(root / 'tests/defaults-init-native.m'),
           '-l:libobjc.so.4', '-L' + blocks, '-Wl,-rpath,' + blocks,
           '-lBlocksRuntime', '-pthread', '-o', str(out / 'defaults-init-native')]
result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
(out / 'build.log').write_bytes(result.stdout)
if result.returncode:
    print(result.stdout.decode())
    raise SystemExit(result.returncode)
for scenario in ['initial', 'reset', 'main', 'background']:
    result = subprocess.run([str(out / 'defaults-init-native'), scenario], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
    (out / (scenario + '.log')).write_bytes(result.stdout)
    print(scenario, 'exit', result.returncode, result.stdout.decode().strip(), flush=True)
    expected = 124 if a.expect_init_deadlock and scenario in ['initial', 'reset'] else 0
    if result.returncode != expected:
        raise SystemExit('Unexpected result for ' + scenario)
print('PASS: reviewed initialization deadlocks reproduced' if a.expect_init_deadlock else 'PASS: corrected methods')
