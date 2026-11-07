#!/usr/bin/env python3
"""Exercise the production NSString numeric parser with bounds-checking strings."""
import argparse
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--source-ref')
a = p.parse_args()
s = (subprocess.check_output(['git', 'show', a.source_ref + ':src/NSString.m'], cwd=root, text=True)
     if a.source_ref else (root / 'src/NSString.m').read_text())
start = s.index('static const unsigned char __NSNumberSet')
end = s.index('// Undocumented method used by KVC', start)
parser = s[start:end]
bool_start = s.index('- (BOOL)boolValue', end)
bool_end = s.index('- (BOOL)containsString:', bool_start)
program = (root / 'tests/string-numeric-bounds-native.m').read_text()
program = program.replace('PRODUCTION_NUMERIC_METHODS', parser + s[bool_start:bool_end])
inc = subprocess.check_output(['gcc', '-print-file-name=include'], text=True).strip()
with tempfile.TemporaryDirectory(prefix='qv-string-numeric-') as tmp:
    source = pathlib.Path(tmp) / 'fixture.m'
    binary = pathlib.Path(tmp) / 'fixture'
    source.write_text(program)
    subprocess.run(['clang', '-O1', '-g', '-fobjc-runtime=gcc', '-fobjc-exceptions', '-fexceptions',
                    '-fconstant-string-class=FixtureString', '-I' + inc,
                    '-fsanitize=undefined', '-fno-sanitize-recover=all', str(source), '-lobjc', '-lm',
                    '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
