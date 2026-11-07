#!/usr/bin/env python3
"""Run verbatim production regions using Linux ObjC/CF storage boundary controls."""
import argparse, resource, signal, subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--core-source',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--before',action='store_true');a=p.parse_args()
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
f=Path(__file__).resolve().parents[1];out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
def read(root,file,base):
 return subprocess.check_output(['git','-C',str(root),'show',base+':'+file],text=True) if a.before else (root/file).read_text()
def method(s,start):
 i=s.index(start);return s[i:s.index('\n}',i)+2]+'\n'
def emit(name,s):(out/(name+'.inc')).write_text(s)
s=read(f,'src/NSNotificationQueue.m','c55eb6b');emit('queue','\n'.join(l for l in s.splitlines() if not l.startswith('#import')))
s=read(f,'src/NSNotificationCenter.m','c55eb6b');emit('center','\n'.join(method(s,t) for t in ['- (void)postNotification:(NSNotification *)notification','- (void)removeObserver:(id)observer\n','- (void)removeObserver:(id)observer name:']))
start='- (void)invalidate\n';emit('observer',(method(s,start) if start in s else '')+method(s,'- (void)postNotification:(NSNotification *)notif target:'))
s=read(a.core_source,'NSArray.m','3f34c24');emit('join',method(s,'- (NSString *)componentsJoinedByString:'))
s=read(a.core_source,'CFRunLoop.c','3f34c24');emit('wait',method(s,'static mach_msg_timeout_t __CFRunLoopWaitTimeout('))
s=read(f,'src/NSKeyValueObserving.m','c55eb6b');emit('kvo',s[s.index('static inline const void *_NSKVOPendingNotificationRetain('):s.index('static CFArrayCallBacks _NSKVOPendingNotificationArrayCallbacks =')]+method(s,'void _NSKeyValuePushPendingNotificationsPerThread(')+method(s,'BOOL _NSKeyValuePopPendingNotificationPerThread('))
h=(f/'src/NSKeyValueObservingInternal.h').read_text();emit('kvo-types',h[h.index('enum {'):h.index('typedef void (*NSKeyValueWillChangeApplyFunction)')])
cc=['/usr/bin/clang','-g','-O0','-fblocks','-fobjc-exceptions','-fexceptions','-fconstant-string-class=NativeConstantString','-Wno-objc-method-access','-Wno-incompatible-pointer-types','-Wno-incompatible-pointer-types-discards-qualifiers','-Wno-objc-root-class','-I'+str(out),'-I'+subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip(),str(f/'tests/order-native.m'),'-l:libobjc.so.4','-L/home/sean/Documents/Codex/Projects/Qvolution-work/toolchains/swift-6.3.3-linux-x64/compiler/usr/lib/swift/linux','-Wl,-rpath,/home/sean/Documents/Codex/Projects/Qvolution-work/toolchains/swift-6.3.3-linux-x64/compiler/usr/lib/swift/linux','-lBlocksRuntime','-pthread','-o',str(out/'fixture')]
r=subprocess.run(cc,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(out/'build.log').write_bytes(r.stdout)
if r.returncode:print(r.stdout.decode()[-12000:]);raise SystemExit(r.returncode)
failed=[]
for section in ['queue','center','join','kvo','wait']:
 r=subprocess.run([str(out/'fixture'),section],stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(out/(section+'.log')).write_bytes(r.stdout);print(section,'exit',r.returncode,r.stdout.decode().strip())
 expected_failure=r.returncode == -signal.SIGABRT and b'Assertion' in r.stdout
 if not (expected_failure if a.before else r.returncode == 0):failed.append(section)
if failed:raise SystemExit('Unexpected results: '+','.join(failed))
print('PASS: baseline fails' if a.before else 'PASS: production regions')
