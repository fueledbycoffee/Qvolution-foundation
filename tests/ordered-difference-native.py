#!/usr/bin/env python3
"""Compile unchanged production code with Linux/libobjc collection doubles.
Run under qv-slot build. Baseline demonstrates the missing real entry point.
"""
import argparse, pathlib, subprocess, re, shlex
parser=argparse.ArgumentParser()
parser.add_argument("--baseline", help="Git revision whose implementation must fail the regression")
parser.add_argument("--regression", default="all")
args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[1]
out=root.parent/'native';out.mkdir(exist_ok=True)
def stripped(p):return re.sub(r'^#(?:import|include) <Foundation/[^>]+>\n','',p.read_text(),flags=re.M)
headers='\n'.join(stripped(root/'include/Foundation'/n) for n in ['NSOrderedCollectionChange.h','NSOrderedCollectionDifference.h'])
header=(root/'tests/ordered-difference-native-support.h').read_text()+headers
production=stripped(root/'src/NSOrderedCollectionDifference.m')
test=(root/'tests/ordered-difference-native.m').read_text()
inc=subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip()
graph=['rule cc','  command = $cmd']
baseline=None if not args.baseline else re.sub(r'^#(?:import|include) <Foundation/[^>]+>\n','',subprocess.check_output(['git','-C',str(root),'show',args.baseline+':src/NSOrderedCollectionDifference.m'],text=True),flags=re.M)
for name,body in [('before',baseline if args.baseline else '#define BASELINE\n'),('after',production)]:
 src=out/(name+'.m');exe=out/name;src.write_text(header+body+test)
 cmd=['clang','-g','-O1','-fblocks','-fobjc-exceptions','-fexceptions','-fconstant-string-class=FixtureString','-I'+inc,'-Wno-objc-method-access','-Wno-incomplete-implementation','-fsanitize=undefined','-fno-sanitize-recover=all',str(src),'-lobjc','-o',str(exe)]
 graph+=['build '+str(exe)+': cc '+str(src),'  cmd = '+shlex.join(cmd)]
(out/'build.ninja').write_text('\n'.join(graph)+'\n')
subprocess.run(['ninja','-C',str(out),'-j6'],check=True)
subprocess.run(['ninja','-C',str(out),'-n'],check=True)
for name,expected in [('before',1),('after',0)]:
 p=subprocess.run([str(out/name), args.regression],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 (out/(name+'.log')).write_text(p.stdout);print(name,p.returncode,p.stdout.strip());assert p.returncode==expected
