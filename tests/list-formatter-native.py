#!/usr/bin/env python3
"""Compile and execute the production ICU joining helper on Linux."""
import argparse
import pathlib
import subprocess
import tempfile
import sys

root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--source-ref')
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix='qv-list-') as tmp:
    path = pathlib.Path(tmp)
    def source_file(name):
        if args.source_ref:
            result = subprocess.run(['git', 'show', args.source_ref + ':' + name],
                                    cwd=root, text=True, capture_output=True)
            if result.returncode:
                print(f'SETUP ERROR: {args.source_ref} lacks required source {name}; '
                      'no behavior test ran', file=sys.stderr)
                raise SystemExit(2)
            return result.stdout
        return (root / name).read_text()
    (path / 'NSListFormatterInternal.h').write_text(source_file('src/NSListFormatterInternal.h'))
    subprocess.run(['clang', '-std=c11', '-O1', '-g', '-Wall', '-Wextra', '-Werror',
                    '-fsanitize=address,undefined', '-fno-sanitize-recover=all', '-I' + tmp,
                    str(root / 'tests/list-formatter-native.c'), '-licui18n', '-licuuc',
                    '-o', str(path / 'test')], check=True)
    subprocess.run([str(path / 'test')], check=True)
    # Exercise the unedited implementation with controlled libobjc object doubles.
    import re
    def without_imports(text):
        return re.sub(r'^#import.*$', '', text, flags=re.M)
    program = (root / 'tests/list-formatter-object-native.m').read_text()
    header = without_imports(source_file('include/Foundation/NSListFormatter.h'))
    implementation = without_imports(source_file('src/NSListFormatter.m'))
    # Keep the production ICU helper include; all Foundation imports are replaced by doubles.
    implementation = '#include "NSListFormatterInternal.h"\n' + implementation
    regression = without_imports((root / 'tests/list-formatter.m').read_text())
    regression = regression.replace('@autoreleasepool', '').replace('NSListFormatter *f = [NSListFormatter new];', 'FixtureCheckCoding(); NSListFormatter *f = [NSListFormatter new];')
    program = program.replace('PRODUCTION_HEADER', header).replace('PRODUCTION_IMPLEMENTATION', implementation).replace('PUBLIC_REGRESSION', regression)
    src = path / 'object.m'; src.write_text(program)
    inc = subprocess.check_output(['gcc', '-print-file-name=include'], text=True).strip()
    subprocess.run(['clang', '-O1', '-g', '-fobjc-runtime=gcc', '-fobjc-exceptions', '-fexceptions',
                    '-fconstant-string-class=FixtureConstantString', '-I' + inc, '-I' + tmp,
                    '-Wno-nullability-completeness', '-Wno-incompatible-pointer-types',
                    '-fsanitize=undefined', '-fno-sanitize-recover=all', str(src),
                    '-lobjc', '-licui18n', '-licuuc', '-o', str(path / 'object')], check=True)
    subprocess.run([str(path / 'object')], check=True)

    race = (root / 'tests/list-formatter-race.m').read_text()
    fixture = (root / 'tests/list-formatter-object-native.m').read_text().split('static void FixtureCheckCoding', 1)[0]
    fixture = fixture.replace('PRODUCTION_HEADER', header).replace('PRODUCTION_IMPLEMENTATION',
        race + '\n' + implementation) + (root / 'tests/list-formatter-race-main.m').read_text()
    src = path / 'race.m'; src.write_text(fixture)
    subprocess.run(['clang', '-O1', '-g', '-fobjc-runtime=gcc', '-fobjc-exceptions', '-fexceptions',
                    '-fconstant-string-class=FixtureConstantString', '-I' + inc, '-I' + tmp,
                    '-Wno-nullability-completeness', '-Wno-incompatible-pointer-types',
                    '-fsanitize=undefined', '-fno-sanitize-recover=all', str(src),
                    '-Wl,--wrap=objc_sync_enter', '-lobjc', '-licui18n', '-licuuc', '-pthread',
                    '-o', str(path / 'race')], check=True)
    subprocess.run([str(path / 'race')], check=True, timeout=20)

    fixture = (root / 'tests/list-formatter-object-native.m').read_text().split('static void FixtureCheckCoding', 1)[0]
    concurrent = without_imports((root / 'tests/list-formatter-concurrent.m').read_text()).replace('@autoreleasepool', '')
    fixture = fixture.replace('PRODUCTION_HEADER', header).replace('PRODUCTION_IMPLEMENTATION', implementation) + concurrent
    src = path / 'concurrent.m'; src.write_text(fixture)
    subprocess.run(['clang', '-O1', '-g', '-fobjc-runtime=gcc', '-fobjc-exceptions', '-fexceptions',
                    '-fconstant-string-class=FixtureConstantString', '-I' + inc, '-I' + tmp,
                    '-Wno-nullability-completeness', '-Wno-incompatible-pointer-types',
                    '-fsanitize=undefined', '-fno-sanitize-recover=all', str(src),
                    '-lobjc', '-licui18n', '-licuuc', '-pthread', '-o', str(path / 'concurrent')], check=True)
    subprocess.run([str(path / 'concurrent')], check=True, timeout=20)
