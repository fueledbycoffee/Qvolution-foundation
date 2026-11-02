#!/usr/bin/env python3
"""Native tests of unedited production factory/ivar functions with test doubles.
NSKeyValueSet's primitive read methods are compiled verbatim against a container
double; full Foundation, NSInvocation, KVO and mutable proxies require the guest fixture.
Run through qv-slot build. Baseline failures are retained and required.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys
SRC = pathlib.Path(__file__).resolve().parents[1]
L = SRC.parent
args = argparse.ArgumentParser()
args.add_argument('--size-parser-dir', type=pathlib.Path,
                  help='pinned lane snapshot containing NSObjCRuntime.m, its internal header and manifest.json')
options = args.parse_args()
O = L / ('native-production-parser' if options.size_parser_dir else 'native')
O.mkdir(exist_ok=True)
parser_source = None
if options.size_parser_dir:
    d = options.size_parser_dir
    manifest = json.loads((d / 'manifest.json').read_text())
    for name in ['NSObjCRuntime.m', 'NSObjCRuntimeInternal.h']:
        assert hashlib.sha256((d / name).read_bytes()).hexdigest() == manifest['sha256'][name], name
    # Keep the production function signature and body verbatim, omitting imports.
    parser_source = (d / 'NSObjCRuntimeInternal.h').read_text() + '\n'
    parser_source += 'const char *__NSGetSizeAndAlignment(' + (
        d / 'NSObjCRuntime.m').read_text().split('const char *__NSGetSizeAndAlignment(', 1)[1]
    print('production size parser snapshot', manifest['head'])
assert not subprocess.check_output(['git', '-C', str(SRC), 'status', '--porcelain'], text=True).strip(), 'commit first'

def region(s, start, end):
    a = s.index(start)
    return s[a:s.index(end, a)]

def generate(s):
    # Regions are compiled verbatim: no hand translation of production logic.
    result = region(s, '@implementation NSObject (NSKeyValueCodingPrivate)', '+ (NSKeyValueProxyGetter*)_createMutableArrayValueGetter') + '\n@end\n'
    result += region(s, 'static id _NSGetObjectValueInIvar(', '#undef DEFINE_GET_VALUE_IN_IVAR') + '\n'
    if 'static void _NSKeyValueGetStructBytes(' in s:
        result += region(s, 'static void _NSKeyValueGetStructBytes(', 'static void _NSSetObjectValueForKeyWithMethod(')
    result += region(s, 'static void _NSSetStructValueForKeyInIvar(', '#define DEFINE_SET_IN_IVAR(')
    result += region(s, '#define TYPE_TO_IMP(', '#pragma mark -')
    result += '@implementation NativeCachedSetter\n' + region(s, '- (void)setMethod:(Method)method {', '\n@end') + '\n@end\n'
    return result

def generate_set_proxy(s):
    # NSKeyValueSet's primitive NSSet overrides, verbatim.
    a = s.index('@implementation NSKeyValueSet\n')
    return region(s[a:], '- (NSEnumerator *)objectEnumerator', '- (void)_proxyNonGCFinalize')

for label, revision in [('before','464ccf18d44a7269e9545300c8b6122a03ca62b2'), ('after','HEAD')]:
    d = O / label
    d.mkdir(exist_ok=True)
    source = subprocess.check_output(['git','-C',str(SRC),'show',revision+':src/NSKeyValueAccessor.m'],text=True)
    (d/'native-production.inc').write_text(generate(source))
    proxies = subprocess.check_output(['git','-C',str(SRC),'show',revision+':src/NSKeyValueCollectionProxies.m'],text=True)
    (d/'native-set-proxy.inc').write_text(generate_set_proxy(proxies))
    command = ['/usr/bin/clang', '-g', '-O0', '-fobjc-exceptions', '-fexceptions', '-Wno-objc-method-access', '-Wno-incompatible-pointer-types', '-I'+str(SRC/'tests'), '-I'+str(d), '-I'+subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip(), str(SRC/'tests/native-test.m'), '-l:libobjc.so.4', '-o', str(d/'fixture')]
    if parser_source:
        (d/'native-size-parser.inc').write_text(parser_source)
        command.insert(1, '-DKVC_NATIVE_PRODUCTION_SIZE_PARSER')
    p = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (d/'build.log').write_bytes(p.stdout)
    if p.returncode:
        print(p.stdout.decode()[-4000:]); sys.exit(p.returncode)
    sections = ['search', 'boxing', 'retarget', 'setproxy'] + (['encoding'] if parser_source else [])
    for section in sections:
        p = subprocess.run([str(d/'fixture'), section], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (d/(section+'.log')).write_bytes(p.stdout)
        print(label, section, 'exit',p.returncode, p.stdout.decode().strip())
        assert (p.returncode != 0) if label == 'before' and section != 'encoding' else (p.returncode == 0)
print('PASS native production-region regression: baseline fails, modified source passes')
