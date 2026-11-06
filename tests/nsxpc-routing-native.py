#!/usr/bin/env python3
"""Run extracted NSXPC methods with controlled native transport/coding doubles.
Run through qv-slot build. --source-ref selects a baseline for regression proof.
"""
import argparse
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--out', type=Path, required=True)
p.add_argument('--source-ref')
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
a.out.mkdir(parents=True, exist_ok=True)

def method(file, start):
    text = (subprocess.check_output(['git', 'show', a.source_ref + ':src/' + file],
            cwd=root, text=True) if a.source_ref else (root / 'src' / file).read_text())
    at = text.index(start)
    return text[at:text.index('\n}', at) + 2] + '\n'

(a.out / 'connection.inc').write_text(method('NSXPCConnection.m', '- (void)_setupConnection'))
(a.out / 'decoder.inc').write_text(method('NSXPCDecoder.m', '- (void) __decodeXPCObject:'))
typed = (subprocess.check_output(['git', 'show', a.source_ref + ':src/NSXPCSerializationObjC.m'],
         cwd=root, text=True) if a.source_ref else (root / 'src/NSXPCSerializationObjC.m').read_text())
typed = typed[typed.index('void _NSXPCSerializationDecodeTypedObjCValuesFromArray('):]
(a.out / 'decode-id.inc').write_text(typed[typed.index('    case _C_ID:'):typed.index('    case _C_CLASS:')])
swift = Path('/home/sean/Documents/Codex/Projects/Qvolution-work/toolchains/swift-6.3.3-linux-x64/compiler/usr/lib/swift')
gcc_include = subprocess.check_output(['gcc', '-print-file-name=include'], text=True).strip()
cmd = ['/usr/bin/clang', '-O1', '-g', '-fblocks', '-fobjc-runtime=gcc',
       '-Wno-objc-property-no-attribute', '-I' + gcc_include, '-I' + str(swift),
       '-I' + str(a.out), str(root / 'tests/nsxpc-routing-native.m'), '-lobjc',
       '-L' + str(swift / 'linux'), '-Wl,-rpath,' + str(swift / 'linux'),
       '-ldispatch', '-lBlocksRuntime', '-o', str(a.out / 'fixture')]
r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
(a.out / 'build.log').write_bytes(r.stdout)
if r.returncode:
    print(r.stdout.decode())
    raise SystemExit(r.returncode)
failed = False
for case in ('classes', 'queue', 'nil'):
    r = subprocess.run([str(a.out / 'fixture'), case], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (a.out / (case + '.log')).write_bytes(r.stdout)
    print(case, 'exit', r.returncode, r.stdout.decode().strip())
    failed |= bool(r.returncode)
raise SystemExit(int(failed))
