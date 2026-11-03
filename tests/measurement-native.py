#!/usr/bin/env python3
"""Focused Linux libobjc regression: real model source, runtime/coder doubles.
The missing temperature implementation at the baseline must fail native linking.
Run through qv-slot build. Outputs are preserved outside the repository.
"""
import argparse,pathlib,subprocess,re
p=pathlib.Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument('--baseline',default='a2400ec');opt=a.parse_args()
out=p.parent/'native';out.mkdir(exist_ok=True)
models=['NSUnit','NSUnitConverter','NSUnitConverterLinear','NSDimension','NSUnitLength','NSUnitTemperature','NSMeasurement']
headers='\n'.join((p/'include/Foundation'/f'{n}.h').read_text() for n in models)
headers=re.sub(r'^#import[^\n]*','',headers,flags=re.M)
inc=subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip()
for label,ref in [('before',opt.baseline),('after',None)]:
    source=''
    for n in models:
        if ref:
            r=subprocess.run(['git','show',f'{ref}:src/{n}.m'],cwd=p,text=True,capture_output=True)
            source+=r.stdout
        else:source+=(p/'src'/f'{n}.m').read_text()
        source+='\n'
    source=re.sub(r'^#import[^\n]*','',source,flags=re.M)
    program=(p/'tests/measurement-native.m').read_text().replace('PRODUCTION_HEADERS',headers).replace('PRODUCTION_SOURCE',source)
    f=out/(label+'.m');f.write_text(program);exe=out/label
    command=['clang','-O0','-g','-fobjc-runtime=gcc','-fconstant-string-class=FixtureString','-fobjc-exceptions','-fexceptions','-I'+inc,'-Wno-incomplete-implementation','-Wno-objc-method-access','-fsanitize=undefined','-fno-sanitize-recover=all',str(f),'-l:libobjc.so.4','-lm','-o',str(exe)]
    r=subprocess.run(command,text=True,capture_output=True);(out/(label+'-build.log')).write_text(r.stdout+r.stderr)
    if label=='before':
        assert r.returncode!=0 and '__objc_class_name_NSUnitTemperature' in r.stderr,r.stderr
        print('before: expected native link failure: missing NSUnitTemperature');continue
    assert r.returncode==0,r.stderr
    r=subprocess.run([str(exe)],text=True,capture_output=True);(out/(label+'-run.log')).write_text(r.stdout+r.stderr)
    assert r.returncode==0,r.stdout+r.stderr
    print(r.stdout.strip())
