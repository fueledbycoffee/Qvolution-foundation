#!/usr/bin/env python3
"""Run production inversion on libobjc with singular and nonsingular matrices."""
import argparse,pathlib,subprocess,tempfile
root=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--source-ref');a=p.parse_args()
s=subprocess.check_output(['git','show',a.source_ref+':src/NSAffineTransform.m'],cwd=root,text=True) if a.source_ref else (root/'src/NSAffineTransform.m').read_text()
start=s.index('- (void) invert');end=s.index('\n}',start)+2
program=r'''
#include <objc/objc.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
typedef double CGFloat;
typedef struct {double m11,m12,m21,m22,tX,tY;} NSAffineTransformStruct;
__attribute__((objc_root_class)) @interface NSObject {Class isa;}
+ (id)new;
@end
@implementation NSObject
+ (id)new{return class_createInstance(self,0);}
@end
static id NSGenericException;
@interface NSException:NSObject { @public id name;}
+ (void)raise:(id)n format:(id)fmt,...;
@end
@implementation NSException
+ (void)raise:(id)n format:(id)fmt,...{NSException *e=[self new];e->name=n;@throw e;}
@end
#define NSLog(...)
#define NSDebugLLog(...)
#define A _matrix.m11
#define B _matrix.m12
#define C _matrix.m21
#define D _matrix.m22
#define TX _matrix.tX
#define TY _matrix.tY
@interface NSAffineTransform:NSObject { @public NSAffineTransformStruct _matrix;BOOL _isIdentity,_isFlipY;}
- (void)invert;
@end
@implementation NSAffineTransform
'''+s[start:end]+r'''
@end
static unsigned failures;
static void check(BOOL ok,const char *m){if(!ok){fprintf(stderr,"FAIL %s\n",m);failures++;}}
int main(void){
 NSGenericException=[NSObject new];
 NSAffineTransform *t=[NSAffineTransform new];
 NSAffineTransformStruct singulars[]={{0,0,0,0,0,0},{1,2,2,4,7,9}};
 for(unsigned i=0;i<2;i++){
  t->_matrix=singulars[i];BOOL caught=NO;
  @try{[t invert];}@catch(NSException *e){caught=e->name==NSGenericException;}
  check(caught,"singular inverse raises NSGenericException");
  check(memcmp(&t->_matrix,&singulars[i],sizeof(t->_matrix))==0,"singular inverse preserves matrix");
 }
 t->_matrix=(NSAffineTransformStruct){2,0,0,4,8,12};[t invert];
 check(t->_matrix.m11==0.5&&t->_matrix.m22==0.25&&t->_matrix.tX==-4&&t->_matrix.tY==-3,"nonsingular inverse remains correct");
 t->_matrix=(NSAffineTransformStruct){1,0,0,1,8,12};t->_isIdentity=YES;[t invert];
 check(t->_matrix.tX==-8&&t->_matrix.tY==-12,"identity linear transform preserves translation fast path");
 printf("%s affine-invert-native failures=%u\n",failures?"FAIL":"PASS",failures);return failures?1:0;
}
'''
inc=subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip()
with tempfile.TemporaryDirectory(prefix='qv-affine-') as t:
 src=pathlib.Path(t)/'test.m';exe=pathlib.Path(t)/'test';src.write_text(program)
 subprocess.run(['clang','-O1','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions','-I'+inc,'-Wno-objc-root-class','-fsanitize=undefined','-fno-sanitize-recover=all',str(src),'-lobjc','-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
