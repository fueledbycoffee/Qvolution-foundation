#!/usr/bin/env python3
"""Run owned NSString methods with GNU ObjC and source-built Linux CoreFoundation.

This is a method projection, not the candidate Darwin runtime. No Foundation
method bodies are replaced. The shim supplies only storage and CF bridging.
Pass the toolchain root and a fresh output directory. Build via qv-slot build.
"""
import argparse
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--toolchain', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=False)
root = Path(__file__).resolve().parents[2]
cf = root.parent / 'corefoundation'
source = (root / 'src/NSString.m').read_text()
def method(signature):
    first = source.index(signature)
    begin = source.index('{', first)
    depth = 1
    end = begin + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[first:end]
methods = [method(s) for s in (
    '- (void)_getBlockStart:', '- (void)getLineStart:',
    '- (void)enumerateSubstringsInRange:', '- (void)enumerateLinesUsingBlock:')]
preamble = r'''
#include <objc/runtime.h>
#include <CoreFoundation/CoreFoundation.h>
#include "CFStringTokenizer.h"
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef unsigned long NSUInteger;
typedef long NSInteger;
typedef unsigned short unichar;
typedef struct { NSUInteger location, length; } NSRange;
static NSRange NSMakeRange(NSUInteger p, NSUInteger n) { return (NSRange){p,n}; }
static NSUInteger NSMaxRange(NSRange r) { return r.location+r.length; }
typedef NSUInteger NSStringEnumerationOptions;
enum { NSStringEnumerationByLines=0, NSStringEnumerationByParagraphs=1,
 NSStringEnumerationByWords=3, NSStringEnumerationBySentences=4,
 NSStringEnumerationReverse=1UL<<8, NSStringEnumerationSubstringNotRequired=1UL<<9 };
#define MIN(a,b) ((a)<(b)?(a):(b))
#define MAX(a,b) ((a)>(b)?(a):(b))
#define NSRangeException nil
__attribute__((objc_root_class))
@interface NSString { Class isa; @public CFStringRef text; }
+ (id)from:(const char *)utf8;
- (NSUInteger)length;
- (unichar)characterAtIndex:(NSUInteger)i;
- (NSString *)substringWithRange:(NSRange)r;
- (void)getLineStart:(NSUInteger *)s end:(NSUInteger *)e contentsEnd:(NSUInteger *)c forRange:(NSRange)r;
- (void)enumerateLinesUsingBlock:(void (^)(NSString *, BOOL *))block;
@end
@interface NSException : NSString
+ (void)raise:(id)name format:(id)message;
@end
@implementation NSException
+ (void)raise:(id)name format:(id)message { abort(); }
@end
static CFStringTokenizerRef bridgeTokenizer(CFAllocatorRef a, NSString *s, CFRange r, CFOptionFlags o, CFLocaleRef l) {
 return CFStringTokenizerCreate(a,s->text,r,o,l);
}
#define CFStringTokenizerCreate(a,s,r,o,l) bridgeTokenizer(a,(NSString *)(s),r,o,l)
#define CarriageReturn '\r'
#define NewLine '\n'
#define NextLine 0x0085
#define LineSeparator 0x2028
#define ParaSeparator 0x2029
static Boolean isALineSeparatorTypeCharacter(UniChar ch, Boolean lines) {
 return ch=='\n'||ch=='\r'||ch==0x2029||(lines&&(ch==0x85||ch==0x2028));
}
@implementation NSString
+ (id)from:(const char *)utf8 {
 NSString *s=class_createInstance(self,0);
 s->text=CFStringCreateWithCString(NULL,utf8,kCFStringEncodingUTF8); return s;
}
- (NSUInteger)length { return CFStringGetLength(text); }
- (unichar)characterAtIndex:(NSUInteger)i {
 if(i>=[self length]) { fprintf(stderr,"native bounds violation: index %lu length %lu\n",i,[self length]); exit(2); }
 return CFStringGetCharacterAtIndex(text,i);
}
- (NSString *)substringWithRange:(NSRange)r {
 NSString *s=class_createInstance(object_getClass(self),0);
 s->text=CFStringCreateWithSubstring(NULL,text,CFRangeMake(r.location,r.length)); return s;
}
'''
suffix = r'''
@end
static void check(const char *input, const char **expected, size_t count, BOOL stop) {
 __block size_t n=0;
 [[NSString from:input] enumerateLinesUsingBlock:^(NSString *line, BOOL *done) {
  if(n>=count) { fprintf(stderr,"too many lines\n"); exit(1); }
  CFStringRef e=CFStringCreateWithCString(NULL,expected[n],kCFStringEncodingUTF8);
  if(!CFEqual(line->text,e)) { fprintf(stderr,"line content mismatch in %s\n",input); exit(1); }
  CFRelease(e); n++; if(stop)*done=YES;
 }];
 if(n!=count) { fprintf(stderr,"line count mismatch\n"); exit(1); }
}
int main(int argc, char **argv) {
 if(argc>1) {
  NSUInteger s=0,e=0,c=0;
  [[NSString from:"last"] getLineStart:&s end:&e contentsEnd:&c forRange:NSMakeRange(4,0)];
  assert(s==0&&e==4&&c==4); puts("native end bounds: passed"); return 0;
 }
 const char *one[]={"éclair"}; check("éclair\r\nlast",one,1,YES);
 const char *two[]={"two words","last"}; check("two words\r\nlast",two,2,NO);
 check("",NULL,0,NO);
 const char *empty[]={"","",""}; check("\n\r\n\r",empty,3,NO);
 const char *unicode[]={"a","b","c","d"}; check("a\xc2\x85" "b\xe2\x80\xa8" "c\xe2\x80\xa9" "d",unicode,4,NO);
 __block size_t reverse=0;
 [[NSString from:"a\r\nb\r\n"] enumerateSubstringsInRange:NSMakeRange(0,6)
  options:NSStringEnumerationReverse usingBlock:^(NSString *line, NSRange part, NSRange enclosing, BOOL *done) {
   assert(part.location==(reverse?0:3)&&part.length==1&&enclosing.length==3); reverse++;
 }];
 assert(reverse==2);
 __block size_t clipped=0;
 [[NSString from:"ab\r\ncd"] enumerateSubstringsInRange:NSMakeRange(1,4)
  options:NSStringEnumerationSubstringNotRequired usingBlock:^(NSString *line, NSRange part, NSRange enclosing, BOOL *done) {
   assert(line==nil&&part.location==(clipped?4:1)&&part.length==1);
   assert(enclosing.location==part.location&&enclosing.length==(clipped?1:3)); clipped++;
 }];
 assert(clipped==2);
 puts("native line methods: passed");
}
'''
(a.out / 'lines.m').write_text(preamble + '\n'.join(methods) + suffix)
# Select Linux CF declarations while keeping the owned tokenizer body unchanged.
tokenizer = (cf / 'CFStringTokenizer.c').read_text()
for header in ('CFBase.h', 'CFRuntime.h'):
    tokenizer = tokenizer.replace('"' + header + '"', '<CoreFoundation/' + header + '>')
(a.out / 'tokenizer.c').write_text(tokenizer)
lib = a.toolchain / 'lib/swift/linux'
includes = ['-I'+str(a.toolchain/'lib/swift'), '-I'+str(a.toolchain/'lib/swift/CoreFoundation'), '-I'+str(cf)]
command = ['/usr/bin/clang', '-g', '-O0', '-fblocks', '-fsanitize=address',
           '-fno-omit-frame-pointer', '-include', 'stdlib.h', '-I/usr/lib/gcc/x86_64-linux-gnu/15/include',
           *includes, str(a.out/'lines.m'), str(a.out/'tokenizer.c'),
           '-L'+str(lib), '-Wl,-rpath,'+str(lib), '-lFoundation', '-lBlocksRuntime',
           '-l:libobjc.so.4', '-licui18n', '-licuuc', '-o', str(a.out/'lines')]
subprocess.run(command, check=True)
print(a.out/'lines')
