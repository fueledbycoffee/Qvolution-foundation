#!/usr/bin/env python3
"""Run unchanged NSValue production methods with explicit host storage/coder doubles.
No archive parsing, CF allocation/cache, or guest Foundation behavior is claimed.
"""
from pathlib import Path
import argparse, subprocess, tempfile, resource
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
p=argparse.ArgumentParser();p.add_argument('--source-ref');p.add_argument('--case',choices=['equality','coding'],default='coding');a=p.parse_args()
r=Path(__file__).resolve().parents[1]
def source(name):
 return subprocess.check_output(['git','show',a.source_ref+':src/'+name],cwd=r,text=True) if a.source_ref else (r/'src'/name).read_text()
def method(s,key):
 at=s.index(key);i=s.index('{',at)+1;depth=1
 while depth:
  if s[i]=='{':depth+=1
  elif s[i]=='}':depth-=1
  i+=1
 return s[at:i]+'\n'
s=source('NSValue.m');coder=source('NSCoder.m')
base=s.split('@implementation NSValue\n',1)[1].split('\n@end',1)[0]
concrete=s.split('@implementation NSConcreteValue\n',1)[1].split('\n@end',1)[0]
ext=s.split('@implementation NSValue (NSValueExtensionMethods)',1)[1].split('\n@end',1)[0]
code=(r/'tests/value-coding-native.m').read_text()
replacements={
 'BASE_METHODS': ''.join(method(base,k) for k in ['- (id)initWithCoder:', '- (void)encodeWithCoder:', '- (id)copyWithZone:']) + (method(base,'- (void)getValue:(void *)value size:') if '- (void)getValue:(void *)value size:' in base else ''),
 'VALUE_METHODS': ''.join(method(ext,k) for k in ['- (NSRange)rangeValue','- (CGPoint)pointValue','- (CGSize)sizeValue','- (CGRect)rectValue','- (BOOL)isEqual:', '- (BOOL)isEqualToValue:']),
 'CONCRETE_METHODS': ''.join(method(concrete,k) for k in ['- (void)encodeWithCoder:', '- (BOOL)isEqualToValue:', '- (const char *)objCType', '- (void)getValue:', '- (const void *)_value']),
 'DECODE_FUNCTION':method(s[s.index('static id newDecodedValue(NSCoder *aCoder)'):], 'static id newDecodedValue('),
 'GEOMETRY_METHODS': ''.join(method(coder,k) for k in ['- (CGPoint)decodePointForKey:', '- (CGSize)decodeSizeForKey:', '- (void)encodePoint:(CGPoint)pt forKey:', '- (void)encodeSize:(CGSize)sz forKey:']),
 'EQUALITY_ONLY': '1' if a.case=='equality' else '0',
}
for k,v in replacements.items():code=code.replace(k,v)
inc=subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip()
with tempfile.TemporaryDirectory(prefix='qv-value-') as tmp:
 src=Path(tmp)/'fixture.m';exe=Path(tmp)/'fixture';src.write_text(code)
 subprocess.run(['clang','-g','-O1','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions','-fconstant-string-class=NSString','-I'+inc,'-Wno-objc-method-access','-Wno-incomplete-implementation','-Wno-incompatible-pointer-types','-fsanitize=address,undefined','-fno-sanitize-recover=all',str(src),'-lobjc','-o',str(exe)],check=True)
 import os
 subprocess.run([str(exe)],check=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})
