#!/usr/bin/env python3
"""Execute production method regions against controlled native storage dependencies.
Run under qv-slot build; --expect-fail checks the failing baseline per section.
This deliberately does not claim full CF/ObjC integration coverage.
"""
import argparse
from pathlib import Path
import shlex
import subprocess
p=argparse.ArgumentParser()
p.add_argument('--core-source',type=Path,required=True)
p.add_argument('--foundation-revision')
p.add_argument('--core-revision')
p.add_argument('--out',type=Path,required=True)
p.add_argument('--expect-fail',action='store_true')
p.add_argument('--sections',nargs='+',default=['undo','operation','hash','paths','defaults','encoding','stream','zone','zone_locale','notification'])
a=p.parse_args();f=Path(__file__).resolve().parents[1];c=a.core_source
out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
def source(root,path,revision):
 return subprocess.check_output(['git','-C',str(root),'show',revision+':'+path],text=True) if revision else (root/path).read_text()
def method(s,start):
 at=s.index(start); end=s.index('\n}',at)+2;return s[at:end]+'\n'
def emit(name,s): (out/(name+'.inc')).write_text(s)
def fm(path):return source(f,'src/'+path,a.foundation_revision)
def cm(path):return source(c,path,a.core_revision)
emit('undogroup',method(fm('NSUndoGroup.m'),'- (void) removeInvocationsWithTarget:'))
emit('undo',method(fm('NSUndoManager.m'),'- (void) removeAllActionsWithTarget:'))
s=fm('NSOperation.m');s=s[s.index('@implementation NSOperation\n'):]
emit('operation',method(s,'- (BOOL)isConcurrent')+(method(s,'- (BOOL)isAsynchronous') if '- (BOOL)isAsynchronous' in s else ''))
emit('hash',method(fm('NSConcreteHashTable.m'),'- (void) addObject:'))
s=fm('NSPathUtilities.m');emit('paths','\n'.join(method(s,m) for m in ['- (NSArray *)pathComponents','- (NSString *)lastPathComponent','- (NSString *)stringByAppendingPathComponent:']))
emit('pathstore',method(fm('NSPathStore.m'),'+ (NSPathStore2 *)pathWithComponents:'))
emit('defaults',method(fm('NSUserDefaults.m'),'- (BOOL)boolForKey:'))
emit('encoding',method(fm('NSString.m'),'- (NSData *)dataUsingEncoding:(NSStringEncoding)encoding allowLossyConversion:'))
s=cm('NSInputStream.m');s=s[s.index('@implementation __NSCFInputStream'):];emit('stream',method(s,'- (BOOL)getBuffer:'))
s=cm('NSTimeZone.m');emit('zone',method(s[s.index('@implementation __NSTimeZone\n'):],'- (NSString *)abbreviationForDate:')+method(s,'- (id)initWithName:(NSString *)name\n'))
s=fm('NSNotificationCenter.m');emit('notification',method(s,'- (void)removeObserver:(id)observer name:'))
s=cm('CFStringEncodingConverter.c');emit('fallback',s[s.index('#define ASCIINewLine'):s.index('static CFIndex __CFDefaultToUnicodeFallbackProc')])
cc=['/usr/bin/clang','-g','-O0','-fblocks','-fobjc-exceptions','-fexceptions','-fconstant-string-class=NativeConstantString','-Wno-objc-method-access','-Wno-incompatible-pointer-types','-Wno-objc-property-no-attribute','-I'+str(out),'-I'+subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip(),str(f/'tests/foundation2-native.m'),'-l:libobjc.so.4','-L/home/sean/Documents/Codex/Projects/Qvolution-work/toolchains/swift-6.3.3-linux-x64/compiler/usr/lib/swift/linux','-Wl,-rpath,/home/sean/Documents/Codex/Projects/Qvolution-work/toolchains/swift-6.3.3-linux-x64/compiler/usr/lib/swift/linux','-lBlocksRuntime','-pthread','-o',str(out/'fixture')]
cc += shlex.split(subprocess.check_output(['pkg-config','--cflags','--libs','icu-i18n'],text=True))
r=subprocess.run(cc,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(out/'build.log').write_bytes(r.stdout)
if r.returncode:print(r.stdout.decode()[-7000:]);raise SystemExit(r.returncode)
failed=[]
for section in a.sections:
 r=subprocess.run([str(out/'fixture'),section],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (out/(section+'.log')).write_bytes(r.stdout)
 print(section,'exit',r.returncode,r.stdout.decode().strip())
 if (r.returncode==0)==a.expect_fail:failed.append(section)
if failed:raise SystemExit('Unexpected result: '+','.join(failed))
print('PASS: '+('baseline fails' if a.expect_fail else 'modified methods pass'))
