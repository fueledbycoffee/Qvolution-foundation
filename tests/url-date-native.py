#!/usr/bin/env python3
"""Compile unedited production method regions with Linux libobjc/ICU doubles.
The calendar primitive double uses ICU. URL doubles check forwarding, ownership,
nil and rejection; the unchanged qv-diff program checks the real CF URL backend.
Run through qv-slot build. --before requires each missing-method group to fail.
"""
import argparse, pathlib, subprocess, json
p=argparse.ArgumentParser();p.add_argument('--before',action='store_true');p.add_argument('--group',choices=['url','calendar','components','all'],default='all');a=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];out=root.parent/'native'/('before' if a.before else 'after');out.mkdir(parents=True,exist_ok=True)
def source(name):
 return subprocess.check_output(['git','-C',str(root),'show','a2400ec:'+name],text=True) if a.before else (root/name).read_text()
def method(s,start):
 if start not in s:return ''
 b=s.index(start);i=s.index('{',b);depth=1;j=i+1
 while depth:
  if s[j]=='{':depth+=1
  elif s[j]=='}':depth-=1
  j+=1
 return s[b:j]
cal=source('src/NSCalendar.m');url=source('src/NSURLComponents.m')
fields=['era','year','month','day','hour','minute','second','weekday','weekdayOrdinal','quarter','weekOfMonth','weekOfYear','yearForWeekOfYear','nanosecond']
names=[n[0].upper()+n[1:] for n in fields]
units='\n'.join(f'#define NSCalendarUnit{n} (1UL << {i})' for i,n in enumerate(names))
props='\n'.join(f'- (NSInteger){n}; - (void)set{n[0].upper()+n[1:]}:(NSInteger)v;' for n in fields)
impl='\n'.join(f'- (NSInteger){n} {{ return values[{i}]; }} - (void)set{n[0].upper()+n[1:]}:(NSInteger)v {{ values[{i}]=v; }}' for i,n in enumerate(fields))
methods='\n'.join(method(cal,s) for s in ['- (NSDate *)startOfDayForDate:', '- (NSDate *)dateByAddingUnit:'])
comp=cal.split('@implementation NSDateComponents (NSCalendarComponents)',1)[1].rsplit('@end',1)[0] if '@implementation NSDateComponents (NSCalendarComponents)' in cal else ''
urlmethods='\n'.join(method(url,s) for s in ['- (NSString *)percentEncodedPath','- (void)setPercentEncodedPath:', '- (NSString *)query','- (void)setQuery:', '- (NSString *)fragment','- (void)setFragment:', '- (NSString *)string'])
s=(root/'tests/url-date-native.m').read_text()
for k,v in {'UNITS':units,'PROPS':props,'PROPS_IMPL':impl,'CAL_METHODS':methods,'COMP_METHODS':comp,'URL_METHODS':urlmethods}.items():s=s.replace('/*'+k+'*/',v)
(out/'fixture.m').write_text(s)
inc=subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip()
cmd=['clang','-g','-O1','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions','-I'+inc,'-Wno-incomplete-implementation','-Wno-objc-method-access',str(out/'fixture.m'),'-lobjc','-licui18n','-licuuc','-o',str(out/'fixture')]
r=subprocess.run(cmd,capture_output=True,text=True);(out/'build.log').write_text(r.stdout+r.stderr);assert r.returncode==0,(r.stdout+r.stderr)[-5000:]
for group in (['url','calendar','components'] if a.group=='all' else [a.group]):
 r=subprocess.run([str(out/'fixture'),group],capture_output=True,text=True);(out/(group+'.log')).write_text(r.stdout+r.stderr)
 print(('before' if a.before else 'after'),group,'exit',r.returncode,r.stdout.strip(),flush=True)
 assert (r.returncode!=0) if a.before else (r.returncode==0)
print('PASS: '+('baseline misses all three method groups' if a.before else 'production methods pass native regression'))
