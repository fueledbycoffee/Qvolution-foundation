#!/usr/bin/env python3
"""Native tests of unedited production factory/ivar functions with test doubles.
Full Foundation, NSInvocation, KVO and mutable proxies require the guest fixture.
Run through qv-slot build. Baseline failures are retained and required.
"""
import pathlib
import subprocess
import sys
SRC = pathlib.Path(__file__).resolve().parents[1]
L = SRC.parent
O = L / 'native'
O.mkdir(exist_ok=True)
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

for label, revision in [('before','464ccf18d44a7269e9545300c8b6122a03ca62b2'), ('after','HEAD')]:
    d = O / label
    d.mkdir(exist_ok=True)
    source = subprocess.check_output(['git','-C',str(SRC),'show',revision+':src/NSKeyValueAccessor.m'],text=True)
    (d/'native-production.inc').write_text(generate(source))
    command = ['/usr/bin/clang', '-g', '-O0', '-fobjc-exceptions', '-fexceptions', '-Wno-objc-method-access', '-Wno-incompatible-pointer-types', '-I'+str(SRC/'tests'), '-I'+str(d), '-I'+subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip(), str(SRC/'tests/native-test.m'), '-l:libobjc.so.4', '-o', str(d/'fixture')]
    p = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (d/'build.log').write_bytes(p.stdout)
    if p.returncode:
        print(p.stdout.decode()[-4000:]); sys.exit(p.returncode)
    for section in ['search', 'boxing', 'retarget']:
        p = subprocess.run([str(d/'fixture'), section], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (d/(section+'.log')).write_bytes(p.stdout)
        print(label, section, 'exit',p.returncode, p.stdout.decode().strip())
        assert (p.returncode != 0) if label == 'before' else (p.returncode == 0)
print('PASS native production-region regression: baseline fails, modified source passes')
