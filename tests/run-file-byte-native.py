#!/usr/bin/env python3
"""Compile unedited production methods with controlled Linux/libobjc doubles.
Run through qv-slot build. --source-ref retains before-fix failures.
The fixture does not validate ICU localization or the full guest runtime.
"""
import argparse, pathlib, subprocess
p=argparse.ArgumentParser();p.add_argument('--source-ref');p.add_argument('--case',action='append',choices=['byte','compare','path','error']);p.add_argument('--out',type=pathlib.Path,required=True);args=p.parse_args()
r=pathlib.Path(__file__).resolve().parents[1];args.out.mkdir(parents=True,exist_ok=True)
def source(path):
 return subprocess.check_output(['git','show',args.source_ref+':'+path],cwd=r,text=True) if args.source_ref else (r/path).read_text()
def method(text,marker):
 a=text.index(marker);b=text.index('{',a);depth=1;i=b+1
 while depth:
  if text[i]=='{':depth+=1
  elif text[i]=='}':depth-=1
  i+=1
 return text[a:i]
b=source('src/NSByteCountFormatter.m');f=source('src/NSFileManager.m');e=source('src/NSFilesystemItemRemoveOperation.m');h=source('include/Foundation/NSByteCountFormatter.h')
replacements={
 'COMPARE_HELPERS':'#include "NSFileContentsEqual.h"' if '- (BOOL)contentsEqualAtPath:' in f else '',
 'BYTE_ENUMS':h[h.index('typedef NS_OPTIONS'):h.index('@interface')],
 'BYTE_METHOD':method(b,'- (NSString *)stringFromByteCount:'),
 'EXISTS_METHOD':method(f,'- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:'),
 'COMPARE_METHOD':method(f,'- (BOOL)contentsEqualAtPath:') if '- (BOOL)contentsEqualAtPath:' in f else '',
 'ERROR_METHOD':method(e,'+ (NSError *)_errorWithErrno:'),
}
s=(r/'tests/file-byte-native.m').read_text()
for key,value in replacements.items():s=s.replace(key,value)
(args.out/'fixture.m').write_text(s)
inc=subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip()
subprocess.run(['clang','-O1','-g','-fobjc-runtime=gcc','-fconstant-string-class=FixtureString','-fblocks','-fobjc-exceptions','-fexceptions','-I'+inc,'-I'+str(r/'src'),'-Wno-objc-method-access','-Wno-incomplete-implementation','-Wno-incompatible-pointer-types','-fsanitize=undefined','-fno-sanitize-recover=all',str(args.out/'fixture.m'),'-lobjc','-lm','-o',str(args.out/'fixture')],check=True)
failed=0
for case in (args.case or ['byte']):
 result=subprocess.run([str(args.out/'fixture'),case],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 (args.out/(case+'.log')).write_text(result.stdout+'exit='+str(result.returncode)+'\n');print(case,result.returncode,result.stdout.strip());failed|=result.returncode!=0
raise SystemExit(failed)
