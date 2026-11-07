#!/usr/bin/env python3
"""Run production NSIndexSet code with native libobjc and a counting CFArray shim.
No full Foundation, Apple runtime, dispatch concurrency, or container is exercised;
the threads case races pthreads on one immutable set.
Run under qv-slot build. Keep --out evidence; --source-ref checks the reviewed code.
"""
import argparse
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(__doc__)
p.add_argument('--source-ref')
p.add_argument('--blocks-lib-dir', type=Path, default=Path('/home/sean/Documents/Codex/Projects/Qvolution-work/toolchains/swift-6.3.3-linux-x64/compiler/usr/lib/swift/linux'))
p.add_argument('--out', type=Path, required=True)
p.add_argument('--cases', nargs='+', default=['leak', 'fragmented', 'mutation', 'failure', 'bulk', 'threads', 'original'])
a = p.parse_args()
out = a.out.resolve()
out.mkdir(parents=True, exist_ok=True)
def read(path):
    if a.source_ref:
        return subprocess.check_output(['git', '-C', str(root), 'show', a.source_ref + ':' + path], text=True)
    return (root / path).read_text()
s = read('src/NSIndexSet.m')
s = s[s.index('typedef struct RangeList'):]
# These unrelated methods require NSCoder/NSString implementations, not cache storage.
for start in ['- (void) encodeWithCoder:', '- (id)initWithCoder:', '- (BOOL)isEqual:(id)', '- (id)description']:
    i = s.index(start)
    j = s.index('\n}', i) + 2
    s = s[:i] + s[j:]
(out / 'production.inc').write_text(s)
header = read('include/Foundation/NSIndexSet.h')
(out / 'indexset-header.inc').write_text('\n'.join(x for x in header.splitlines() if not x.startswith('#import')))
(out / 'utlist.h').write_text(read('src/utlist.h'))
original = read('tests/indexset-neighbours.m').replace('#import <Foundation/Foundation.h>', '')
(out / 'original.inc').write_text(original.replace('int main(void)', 'int original_main(void)'))
include = subprocess.check_output(['gcc', '-print-file-name=include'], text=True).strip()
cc = ['clang', '-g', '-O1', '-fblocks', '-fobjc-runtime=gcc', '-fconstant-string-class=NativeConstantString',
      '-I' + include, '-I' + str(out), '-Wno-incomplete-implementation', '-Wno-objc-method-access',
      '-Wno-incompatible-pointer-types', '-fsanitize=address,undefined', '-fno-sanitize-recover=all', '-pthread',
      str(root / 'tests/indexset-cache-native.m'), '-lobjc', '-L' + str(a.blocks_lib_dir),
      '-Wl,-rpath,' + str(a.blocks_lib_dir), '-lBlocksRuntime', '-o', str(out / 'fixture')]
r = subprocess.run(cc, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
(out / 'build.log').write_bytes(r.stdout)
if r.returncode:
    print(r.stdout.decode())
    raise SystemExit(r.returncode)
import os
env = dict(os.environ, ASAN_OPTIONS='detect_leaks=0')  # libobjc globals; own allocations counted explicitly
failed = []
for case in a.cases:
    r = subprocess.run([str(out / 'fixture'), case], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (out / (case + '.log')).write_bytes(r.stdout)
    print(case, 'exit', r.returncode, r.stdout.decode()[-1800:].strip())
    if r.returncode:
        failed.append(case)
if failed:
    raise SystemExit('FAIL: ' + ', '.join(failed))
print('PASS: all requested native cases')
