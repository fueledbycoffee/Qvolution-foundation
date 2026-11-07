#!/usr/bin/env python3
"""Run the production NSString comparison boundary with a CF contract double."""
from pathlib import Path
import argparse, subprocess, resource
resource.setrlimit(resource.RLIMIT_CORE,(0,0))
p=argparse.ArgumentParser();p.add_argument('--ref');p.add_argument('--output',type=Path,required=True);a=p.parse_args()
r=Path(__file__).resolve().parents[1];a.output.mkdir(parents=True,exist_ok=True)
s=subprocess.check_output(['git','show',a.ref+':src/NSString.m'],cwd=r,text=True) if a.ref else (r/'src/NSString.m').read_text()
start=s.index('- (NSComparisonResult)compare:(NSString *)string options:(NSStringCompareOptions)mask range:(NSRange)compareRange locale:');end=s.index('\n- (',start+1)
method=s[start:end]
program=r'''
#include <objc/runtime.h>
#include <assert.h>
#include <stdio.h>
typedef unsigned long NSUInteger;typedef long NSComparisonResult;typedef NSUInteger NSStringCompareOptions;typedef NSUInteger CFStringCompareFlags;typedef void *CFStringRef;typedef void *CFLocaleRef;
typedef struct {NSUInteger location,length;} NSRange;typedef NSRange CFRange;
static CFRange CFRangeMake(NSUInteger l,NSUInteger n){return (CFRange){l,n};}
enum {NSLiteralSearch=2,kCFCompareNonliteral=16,NSOrderedDescending=1};
static NSUInteger flagsSeen;static CFRange rangeSeen;static void *localeSeen;
static long CFStringCompareWithOptionsAndLocale(CFStringRef a,CFStringRef b,CFRange range,CFStringCompareFlags flags,CFLocaleRef locale){flagsSeen=flags;rangeSeen=range;localeSeen=locale;return flags&kCFCompareNonliteral?0:1;}
__attribute__((objc_root_class))
@interface NSString {Class isa;}
+ (id)new;
- (NSComparisonResult)compare:(NSString *)s options:(NSStringCompareOptions)o range:(NSRange)r locale:(id)l;
@end
@implementation NSString
+ (id)new {return class_createInstance(self,0);}
'''+method+r'''
@end
int main(void){NSString *s=[NSString new],*other=[NSString new];
 assert(([s compare:other options:0 range:(NSRange){1,2} locale:(id)3]==0));
 assert(flagsSeen==16 && rangeSeen.location==1 && rangeSeen.length==2 && localeSeen==(void *)3);
 assert(([s compare:other options:2 range:(NSRange){0,1} locale:0]==1));
 assert(!(flagsSeen&16));
 for(NSUInteger flags=0;flags<1024;flags++){
  [s compare:other options:flags range:(NSRange){2,3} locale:0];
  assert((flagsSeen&~16UL)==(flags&~16UL));
  assert((flagsSeen&16UL)==((flags&2)?(flags&16UL):16UL));
 }
 puts("PASS: default canonical comparison, literal option and option/range/locale forwarding");
}
'''
source=a.output/'fixture.m';source.write_text(program);exe=a.output/'fixture'
subprocess.run(['clang','-fobjc-runtime=gcc','-I'+subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip(),str(source),'-lobjc','-o',str(exe)],check=True)
subprocess.run([str(exe)],check=True)
