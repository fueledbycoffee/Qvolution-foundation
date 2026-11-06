#!/usr/bin/env python3
"""Run unedited production methods with deterministic ObjC/dispatch/CF doubles.
Uses real Linux pipe/read/error behavior. Does not verify dispatch scheduling,
Objective-C ownership or CFRunLoop integration; run pipe-filehandle via qv-diff.
"""
import argparse
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--source-ref')
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
a.out.mkdir(parents=True, exist_ok=True)
source = (subprocess.check_output(['git', 'show', a.source_ref + ':src/NSFileHandle.m'],
          cwd=root, text=True) if a.source_ref else (root/'src/NSFileHandle.m').read_text())
concrete = source[source.index('@implementation NSConcreteFileHandle\n'):]

def body(text, marker):
    start = text.index(marker)
    opening = text.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]

replacements = {
    'PRODUCTION_AVAILABLE': body(concrete, '- (NSData *)availableData'),
    'PRODUCTION_MONITOR': body(concrete, '- (dispatch_source_t)_monitor:'),
    'PRODUCTION_PERFORM': body(concrete, 'static void NSConcreteFileHandlePerform('),
    'PRODUCTION_CONVERT': body(source, 'static NSData *_NSDataFromDispatchData(')
        if 'static NSData *_NSDataFromDispatchData(' in source else '',
    'PRODUCTION_ENUMS': source[source.index('typedef NS_OPTIONS'):source.index('CF_PRIVATE')],
}
callback = body(concrete, 'dispatch_io_read(channel,')
replacements['PRODUCTION_END_CALLBACK'] = callback[callback.index('{'):]
fixture = (root/'tests/filehandle-native.m').read_text()
for key, value in replacements.items():
    fixture = fixture.replace(key, value)
(a.out/'fixture.m').write_text(fixture)
gcc_include = subprocess.check_output(['gcc', '-print-file-name=include'], text=True).strip()
subprocess.run(['clang', '-O1', '-g', '-fobjc-runtime=gcc', '-fblocks',
    '-fconstant-string-class=FixtureString', '-fobjc-exceptions', '-fexceptions',
    '-I'+gcc_include, '-Wno-objc-method-access', '-Wno-incompatible-pointer-types',
    '-fsanitize=undefined', '-fno-sanitize-recover=all', str(a.out/'fixture.m'),
    '-lobjc', '-o', str(a.out/'fixture')], check=True)
failed = False
for case in ('available-payloads', 'available-eof', 'available-error', 'notification',
             'notification-error', 'monitor-eof', 'monitor-cancel', 'read-to-end-empty'):
    result = subprocess.run([str(a.out/'fixture'), case], text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    report = result.stdout + f'exit={result.returncode}\n'
    (a.out/(case+'.log')).write_text(report)
    print(case+': '+report.strip(), flush=True)
    failed |= result.returncode != 0
raise SystemExit(int(failed))
