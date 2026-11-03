#!/usr/bin/env python3
"""Execute the production UUID initializers with Linux libobjc/libuuid doubles.
CF construction/lifetime and NSString conversion are controlled test doubles;
this does not replace the macOS/Darling differential check.
"""
import argparse
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--source-ref')
a = p.parse_args()
source = (subprocess.check_output(['git', 'show', a.source_ref + ':src/NSUUID.m'],
          cwd=root, text=True) if a.source_ref else (root / 'src/NSUUID.m').read_text())
source = source.split('@implementation __NSConcreteUUID', 1)[1]
def method(signature):
    start = source.index(signature)
    end = source.index('{', start) + 1
    depth = 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]
program = (root / 'tests/nsuuid-string-native.m').read_text().replace('PRODUCTION_METHODS',
    '\n'.join(method(s) for s in ['- (id)initWithUUIDString:',
                                 '- (id)initWithUUIDBytes:', '- (void)dealloc']))
inc = subprocess.check_output(['gcc', '-print-file-name=include'], text=True).strip()
with tempfile.TemporaryDirectory(prefix='nsuuid-native-') as tmp:
    src = pathlib.Path(tmp) / 'test.m'
    exe = pathlib.Path(tmp) / 'test'
    src.write_text(program)
    subprocess.run(['clang', '-fobjc-runtime=gcc', '-I' + inc, '-fsanitize=undefined',
                    '-fno-sanitize-recover=all', str(src), '-lobjc', '-luuid', '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
