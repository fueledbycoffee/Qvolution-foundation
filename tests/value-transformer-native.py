#!/usr/bin/env python3
"""Execute production registry/Boolean methods on Linux libobjc doubles.

No container or Apple binary is used. Dictionary storage, ownership and locks
are controlled doubles; this verifies method behavior, not Foundation's ABI.
"""
import argparse
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--source-ref')
parser.add_argument('--case', choices=['registry', 'reverse', 'exception', 'unregister-reentry',
                    'replacement-reentry', 'mutation-exception', 'same-transformer'], default='registry')
args = parser.parse_args()
source = (subprocess.check_output(['git', 'show', args.source_ref + ':src/NSValueTransformer.m'], cwd=root, text=True)
          if args.source_ref else (root / 'src/NSValueTransformer.m').read_text())

def method(signature):
    start = source.index(signature)
    pos = source.index('{', start)
    depth = 1
    end = pos + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

registry = '\n'.join(method(s) for s in [
    '+ (void)setValueTransformer:', '+ (NSValueTransformer *)valueTransformerForName:',
    '+ (NSArray *)valueTransformerNames', '+ (BOOL)allowsReverseTransformation',
    '- (id)transformedValue:', '- (id)reverseTransformedValue:'])
booleans = source[source.index('@implementation _NSNegateBooleanTransformer'):source.index('@implementation _NSKeyedUnarchiveFromDataTransformer')]
program = (root / 'tests/value-transformer-native.m').read_text()
program = program.replace('PRODUCTION_REGISTRY', registry).replace('PRODUCTION_BOOLEANS', booleans)
include = subprocess.check_output(['gcc', '-print-file-name=include'], text=True).strip()
with tempfile.TemporaryDirectory(prefix='qv-transformer-') as temp:
    path = pathlib.Path(temp)
    (path / 'fixture.m').write_text(program)
    subprocess.run(['clang', '-O1', '-fobjc-runtime=gcc', '-fconstant-string-class=NSString',
                    '-fobjc-exceptions', '-fexceptions', '-I' + include,
                    '-Wno-incomplete-implementation', '-fsanitize=undefined',
                    '-fno-sanitize-recover=all', str(path / 'fixture.m'), '-lobjc', '-o', str(path / 'fixture')], check=True)
    subprocess.run([str(path / 'fixture'), args.case], check=True, timeout=10)
