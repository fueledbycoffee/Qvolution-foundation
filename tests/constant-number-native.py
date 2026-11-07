#!/usr/bin/env python3
"""Exercise production literal conversion and comparison methods using ABI fixtures."""
from pathlib import Path
import subprocess, argparse, re, resource
resource.setrlimit(resource.RLIMIT_CORE,(0,0))
p=argparse.ArgumentParser();p.add_argument('--ref');p.add_argument('--output',type=Path,required=True);a=p.parse_args()
r=Path(__file__).resolve().parents[1];a.output.mkdir(parents=True,exist_ok=True)
s=subprocess.check_output(['git','show',a.ref+':src/NSConstantNumbers.m'],cwd=r,text=True) if a.ref else (r/'src/NSConstantNumbers.m').read_text()
def method(key):
 start=s.index(key);i=s.index('{',start)+1;depth=1
 while depth:
  if s[i]=='{':depth+=1
  elif s[i]=='}':depth-=1
  i+=1
 return s[start:i]
comparison=method('- (NSComparisonResult)compare:').replace('\\\n','\n')
program=r'''
#include <objc/runtime.h>
#include <stdio.h>
#include <assert.h>
#include <stdint.h>
#include <limits.h>
#include <math.h>
typedef long NSComparisonResult;typedef void *CFNumberRef;typedef long CFComparisonResult;
__attribute__((objc_root_class))
@interface NSNumber { Class isa; @public double value; }
+ (id)new; - (double)doubleValue; - (float)floatValue; - (id)_equivalentNumber; - (BOOL)respondsToSelector:(SEL)s; - (NSComparisonResult)compare:(id)other;
@end
@implementation NSNumber
+ (id)new{return class_createInstance(self,0);}
- (double)doubleValue{return value;}
- (id)_equivalentNumber{return self;}
- (BOOL)respondsToSelector:(SEL)s{return class_getInstanceMethod(object_getClass(self),s)!=0;}
- (NSComparisonResult)compare:(id)o {double d=[o doubleValue];return value<d?-1:value>d?1:0;}
@end
static CFComparisonResult CFNumberCompare(CFNumberRef a,CFNumberRef b,void *c){double x=[(id)a doubleValue],y=[(id)b doubleValue];if(x==0 && y==0 && signbit(x)!=signbit(y))return signbit(x)?-1:1;return x<y?-1:x>y?1:0;}
struct __NSConstantIntegerNumberLayout {Class isa;const char *encoding;long long value;};
#define INTEGER_LAYOUT(o) ((struct __NSConstantIntegerNumberLayout *)(o))
@interface NSConstantIntegerNumber:NSNumber @end
@implementation NSConstantIntegerNumber
'''
helper=s[s.index('static BOOL integerEncodingIsUnsigned'):s.index('- (float)floatValue\n')] if 'static BOOL integerEncodingIsUnsigned' in s else ''
program+=helper+method('- (float)floatValue\n')+'\n'+method('- (double)doubleValue\n')+'\n@end\n'
program+='@interface LiteralZero:NSNumber @end\n@implementation LiteralZero\n- (id)_equivalentNumber { NSNumber *n=[NSNumber new];n->value=value;return n; }\n'+comparison+'\n@end\n'
program+=r'''
static int failures;
#define CHECK(x) do { if(!(x)){printf("FAIL: %s\n",#x);failures++;} } while(0)
int main(void){
 struct __NSConstantIntegerNumberLayout n={objc_getClass("NSConstantIntegerNumber"),"Q",-1};
 CHECK([(id)&n doubleValue]==-1);CHECK([(id)&n floatValue]==-1);
 NSNumber *zero=[NSNumber new];zero->value=0;
 LiteralZero *minus=[LiteralZero new];minus->value=-0.0;
 CHECK([minus compare:zero]==0);CHECK([zero compare:minus]==0);
 printf("%s: production literal conversions and zero comparison\n",failures?"FAIL":"PASS");return failures?1:0;
}
'''
source=a.output/'fixture.m';source.write_text(program);exe=a.output/'fixture'
subprocess.run(['clang','-fobjc-runtime=gcc','-I'+subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip(),str(source),'-lobjc','-o',str(exe)],check=True)
subprocess.run([str(exe)],check=True)
