#!/usr/bin/env python3
"""Compile unchanged production methods against controlled Linux libobjc doubles."""
import argparse,pathlib,re,subprocess,tempfile
root=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--corefoundation-root',type=pathlib.Path,required=True);p.add_argument('--source-ref');p.add_argument('--cf-source-ref');p.add_argument('--case',default='all');a=p.parse_args()
def read(repo,file,ref):
 return subprocess.check_output(['git','show',ref+':'+file],cwd=repo,text=True) if ref else (repo/file).read_text()
def method(s,key):
 at=s.index(key);beg=s.index('{',at);depth=1;i=beg+1
 while depth:
  if s[i]=='{':depth+=1
  elif s[i]=='}':depth-=1
  i+=1
 return s[at:i]
f=read(root,'src/NSAttributedString.m',a.source_ref);s=read(root,'src/NSString.m',a.source_ref)
c=read(a.corefoundation_root,'NSAttributedString.m',a.cf_source_ref);cs=read(a.corefoundation_root,'NSString.m',a.cf_source_ref);run=read(a.corefoundation_root,'CFAttributedString.c',a.cf_source_ref)
program=(root/'tests/attributed-string-behavior-native.m').read_text()
parts={
 'PLACEHOLDER_INIT':method(f[f.index('@implementation __NSPlaceholderAttributedString'):],'- (id)initWithString:'),
 'STRING_METHODS':'\n'.join(method(s,k) for k in ['- (NSString *)substringFromIndex:', '- (NSString *)substringWithRange:', '- (NSRange)rangeOfString:(NSString *)str options:(NSStringCompareOptions)mask range:(NSRange)searchRange locale:']),
 'CF_STRING_METHODS':'\n'.join(method(cs,k) for k in ['- (id)substringWithRange:', '- (unichar)characterAtIndex:']),
 'RUN_ACCESSOR':method(run,'static CFDictionaryRef _CFRunArrayObjectAtIndex'),
 'RANGE_HELPERS':c[c.index('static BOOL _rangeCheckRange'):c.index('- (void)removeAttribute:')],
 'CF_ATTR_METHODS':'\n'.join(method(c,k) for k in ['- (NSDictionary *)attributesAtIndex:(NSUInteger)index effectiveRange:', '- (id)attribute:(NSString *)attrName atIndex:(NSUInteger)index effectiveRange:', '- (void)setAttributes:'])+'\n'+(method(c,'- (BOOL)isKindOfClass:') if '- (BOOL)isKindOfClass:' in c else ''),
 'ENUM_METHODS':'\n'.join(method(f,k) for k in ['- (void)enumerateAttributesInRange:', '- (void)enumerateAttribute:']),
}
for k,v in parts.items():program=re.sub(r"\b"+k+r"\b",lambda m:v,program)
inc=subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip()
with tempfile.TemporaryDirectory(prefix='qv-attr-behavior-') as tmp:
 src=pathlib.Path(tmp)/'fixture.m';exe=pathlib.Path(tmp)/'fixture';src.write_text(program)
 subprocess.run(['clang','-O1','-g','-fobjc-runtime=gcc','-fconstant-string-class=FixtureString','-fobjc-exceptions','-fexceptions','-fblocks','-I'+inc,'-Wno-objc-method-access','-Wno-incomplete-implementation','-Wno-incompatible-pointer-types','-fsanitize=undefined','-fno-sanitize-recover=all',str(src),'-lobjc','-o',str(exe)],check=True)
 subprocess.run([str(exe)]+([] if a.case=='all' else [a.case]),check=True)
