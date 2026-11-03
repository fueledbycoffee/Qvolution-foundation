#!/usr/bin/env python3
"""Compile production NSLocale accessors into a Linux libobjc fixture.
Run through qv-slot build. --source-ref HEAD demonstrates the original failure.
"""
import argparse
import pathlib
import re
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--source-ref')
args = parser.parse_args()
source = (subprocess.check_output(['git', 'show', args.source_ref + ':src/NSLocale.m'],
          cwd=root, text=True) if args.source_ref else (root / 'src/NSLocale.m').read_text())
names = ['countryCode', 'scriptCode', 'decimalSeparator', 'groupingSeparator',
         'currencyCode', 'currencySymbol', 'usesMetricSystem', 'localizedStringForLanguageCode']
methods = []
for name in names:
    match = re.search(r'- \([^\n]+\)\s*' + name + r'\b[^\n]*\n\{[^}]*\}', source)
    if match:
        methods.append(match[0])
fixture = (root / 'tests/locale-accessors-native.m').read_text().replace(
    'PRODUCTION_METHODS', '\n\n'.join(methods))
include = subprocess.check_output(['gcc', '-print-file-name=include'], text=True).strip()
with tempfile.TemporaryDirectory(prefix='qv-locale-') as tmp:
    src = pathlib.Path(tmp) / 'test.m'
    exe = pathlib.Path(tmp) / 'test'
    src.write_text(fixture)
    subprocess.run(['clang', '-O1', '-fobjc-runtime=gcc', '-I' + include,
                    '-Wno-incomplete-implementation', '-fsanitize=undefined',
                    '-fno-sanitize-recover=all', str(src), '-lobjc', '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
