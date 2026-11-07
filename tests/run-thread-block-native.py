#!/usr/bin/env python3
"""Run exact production methods against controlled native lifecycle dependencies."""
import argparse
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--revision')
p.add_argument('--out', type=Path, required=True)
p.add_argument('--expect-fail', action='store_true')
a = p.parse_args()
f = Path(__file__).resolve().parents[1]
a.out.mkdir(parents=True, exist_ok=True)
s = (subprocess.check_output(['git', '-C', str(f), 'show', a.revision + ':src/NSThread.m'], text=True)
     if a.revision else (f / 'src/NSThread.m').read_text())
def method(marker):
    at = s.index(marker)
    return s[at:s.index('\n}', at) + 2] + '\n'
helper = ''
methods = method('- (id)initWithTarget:') + method('- (void)main\n')
if '@interface _NSThreadBlockTarget' in s:
    at = s.index('@interface _NSThreadBlockTarget')
    end = s.index('@end', s.index('@implementation _NSThreadBlockTarget', at)) + 4
    helper = s[at:end]
    methods += method('- (id)initWithBlock:') + method('+ (void)detachNewThreadWithBlock:')
(a.out / 'thread-block-target.inc').write_text(helper)
(a.out / 'thread-block-methods.inc').write_text(methods)
blocks = '/home/sean/Documents/Codex/Projects/Qvolution-work/toolchains/swift-6.3.3-linux-x64/compiler/usr/lib/swift'
cmd = ['/usr/bin/clang', '-O0', '-g', '-fblocks', '-fobjc-exceptions', '-fexceptions',
       '-I' + subprocess.check_output(['gcc', '-print-file-name=include'], text=True).strip(),
       '-I' + blocks + '/Block', '-I' + str(a.out), str(f / 'tests/thread-block-native.m'),
       '-L' + blocks + '/linux', '-Wl,-rpath,' + blocks + '/linux', '-lBlocksRuntime',
       '-l:libobjc.so.4', '-pthread', '-o', str(a.out / 'fixture')]
r = subprocess.run(cmd, capture_output=True)
(a.out / 'build.log').write_bytes(r.stdout + r.stderr)
if r.returncode:
    print((r.stdout + r.stderr).decode()); raise SystemExit(r.returncode)
r = subprocess.run([str(a.out / 'fixture')], capture_output=True)
(a.out / 'run.log').write_bytes(r.stdout + r.stderr)
print((r.stdout + r.stderr).decode(), end='')
if (r.returncode == 0) == a.expect_fail:
    raise SystemExit('unexpected regression result: ' + str(r.returncode))
print('PASS: baseline fails' if a.expect_fail else 'PASS: production block thread methods')
