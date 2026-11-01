#!/usr/bin/env python3
"""Run via qv-slot build; controlled Linux libobjc fixture, never a container.
Extract real Foundation and CF cluster methods, without compiling Apple data.
"""
import argparse,pathlib,subprocess,tempfile,os,re
root=pathlib.Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument('--source-ref');a.add_argument('--case',choices=['all','throwing-keyed','throwing-unkeyed','throwing-init','throwing-temporary'],default='all');a.add_argument('--corefoundation-root',type=pathlib.Path,required=True);args=a.parse_args()
def method(source,start):
 at=source.index(start);beg=source.index('{',at);depth=1;i=beg+1
 while depth:
  if source[i]=='{':depth+=1
  elif source[i]=='}':depth-=1
  i+=1
 return source[at:i]
s=subprocess.check_output(['git','show',args.source_ref+':src/NSAttributedString.m'],cwd=root,text=True) if args.source_ref else (root/'src/NSAttributedString.m').read_text()
cf=(args.corefoundation_root/'NSAttributedString.m').read_text()
methods=s[s.index('static BOOL _NSAttributedStringReadInteger'):s.index('- (NSString *)description')] if 'static BOOL _NSAttributedStringReadInteger' in s else ''
mut=s[s.index('@implementation NSMutableAttributedString'):s.index('CF_PRIVATE')]
mutable=method(mut,'- (Class)classForCoder') if '- (Class)classForCoder' in mut else ''
placeholder=s[s.index('@implementation __NSPlaceholderAttributedString'):]
program=(root/'tests/attributed-string-coding-native.m').read_text()
for key,value in {
 'FIXTURE_CASE':str(['all','throwing-keyed','throwing-unkeyed','throwing-init','throwing-temporary'].index(args.case)),
 'ALLOC_METHOD':method(s,'+ (id)allocWithZone:'),
 'CODING_METHODS':methods,
 'MUTABLE_CLASS_METHOD':mutable,
 'PLACEHOLDER_INIT_METHODS':'\n'.join(method(placeholder,x) for x in ['- (id)initWithString:', '- (id)initWithAttributedString:']),
 'CF_CODING_METHODS':'\n'.join(method(cf,x) for x in ['+ (id)allocWithZone:', '- (Class)classForCoder','- (id)initWithCoder:', '- (void)encodeWithCoder:']),
 'OBSERVED_CASES':r'''
 NSDictionary *one=[NSDictionary new],*two=[NSDictionary new];
 for(int large=0;large<2;large++) {
  // Known inputs from the authored Linux probe, never a guest archive.
  static char longText[301];memset(longText,'a',300);
  FixtureString *text=class_createInstance([FixtureString class],0);
  if(large){text->bytes=longText;text->size=300;}
  NSCoder *observed=[NSCoder new];observed->keyed=YES;
  [observed encodeObject:large?(id)text:(id)@"abcdef" forKey:@"NSString"];
  NSMutableArray *attrs=[NSMutableArray array];[attrs addObject:one];[attrs addObject:large?empty:two];if(!large)[attrs addObject:empty];
  uint8_t small[]={2,0,3,1,1,2},big[]={129,1,0,171,1,1};
  NSMutableData *info=[NSMutableData data];[info appendBytes:large?big:small length:6];
  [observed encodeObject:attrs forKey:@"NSAttributes"];[observed encodeObject:info forKey:@"NSAttributeInfo"];
  id result=[[[NSAttributedString class]alloc]initWithCoder:observed];
  assert([result length]==(large?300:6));
  assert([result attributesAtIndex:0 effectiveRange:NULL]==one);
  assert([result attributesAtIndex:large?129:2 effectiveRange:NULL]==(large?empty:two));
  assert([result attributesAtIndex:large?299:5 effectiveRange:NULL]==empty);
  NSCoder *encoded=[NSCoder new];encoded->keyed=YES;[result encodeWithCoder:encoded];
  NSData *out=[encoded decodeObjectForKey:@"NSAttributeInfo"];
  assert([out length]==6&&!memcmp([out bytes],large?big:small,6));
 }
''',
}.items():program=re.sub(r'\b'+key+r'\b',lambda m:value,program)
inc=subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip()
with tempfile.TemporaryDirectory(prefix='qv-attributed-') as tmp:
 src=pathlib.Path(tmp)/'fixture.m';exe=pathlib.Path(tmp)/'fixture';src.write_text(program)
 subprocess.run(['clang','-O1','-g','-fobjc-runtime=gcc','-fconstant-string-class=FixtureString','-fobjc-exceptions','-fexceptions','-I'+inc,'-Wno-objc-method-access','-Wno-incompatible-pointer-types','-Wno-incomplete-implementation','-fsanitize=undefined','-fno-sanitize-recover=all',str(src),'-lobjc','-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
