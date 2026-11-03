#!/usr/bin/env python3
"""Compile/run production class on Linux libobjc; run under qv-slot build.
Primitive Foundation operations are doubles. This is not a guest/runtime gate.
--baseline uses the committed parent (formatter class absent), requiring failure.
"""
import argparse,pathlib,subprocess,re
p=argparse.ArgumentParser();p.add_argument('--baseline',action='store_true');a=p.parse_args()
repo=pathlib.Path(__file__).resolve().parents[1];out=repo.parent/'native';out.mkdir(exist_ok=True)
assert not subprocess.check_output(['git','-C',str(repo),'status','--porcelain'],text=True).strip(),'commit before testing'
def stripped(text):return '\n'.join(x for x in text.splitlines() if not x.startswith('#import'))
program=(repo/'tests/person-name-native-support.h').read_text()+'\n'
for h in ['NSPersonNameComponents','NSPersonNameComponentsFormatter']:
 program+=stripped((repo/('include/Foundation/'+h+'.h')).read_text())+'\n'
program+=stripped((repo/'src/NSPersonNameComponents.m').read_text())+'\n'
if not a.baseline:program+=stripped((repo/'src/NSPersonNameComponentsFormatter.m').read_text())+'\n'
else:
 r=subprocess.run(['git','-C',str(repo),'cat-file','-e','HEAD^:src/NSPersonNameComponentsFormatter.m'],capture_output=True)
 assert r.returncode,'baseline must not already contain formatter'
program+=(repo/'tests/person-name-native.m').read_text()
label='before' if a.baseline else 'after';src=out/(label+'.m');exe=out/label;src.write_text(program)
include=subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip()
cmd=['clang','-O1','-g','-fobjc-runtime=gcc','-fconstant-string-class=FixtureConstantString','-fobjc-exceptions','-fexceptions','-I'+include,'-Wno-objc-method-access','-Wno-incomplete-implementation','-Wno-protocol','-Wno-nullability-completeness','-Wno-incompatible-pointer-types','-fsanitize=undefined','-fno-sanitize-recover=all',str(src),'-lobjc','-licuuc','-licui18n','-o',str(exe)]
if a.baseline:cmd.insert(1,'-DQV_PERSON_NAME_BASELINE')
r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(out/(label+'-build.log')).write_bytes(r.stdout)
if r.returncode:print(r.stdout.decode());raise SystemExit(r.returncode)
r=subprocess.run([str(exe)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(out/(label+'.log')).write_bytes(r.stdout);print(r.stdout.decode(),end='')
assert (r.returncode==1 and b'formatterClass != Nil' in r.stdout) if a.baseline else r.returncode==0
print(label+': expected result confirmed')
