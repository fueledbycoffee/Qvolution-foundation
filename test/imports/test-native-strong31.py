#!/usr/bin/env python3
"""Project owned methods onto GNU ObjC storage; this is not a Darwin runtime test."""
import argparse
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--out', type=Path, required=True)
p.add_argument('--case', choices=['relative', 'io'], required=True)
p.add_argument('--revision')
a = p.parse_args()
root = Path(__file__).resolve().parents[2]
a.out.mkdir(parents=True, exist_ok=False)

def source(name):
    if a.revision:
        return subprocess.check_output(['git', '-C', str(root), 'show', a.revision + ':src/' + name], text=True)
    return (root / 'src' / name).read_text()

def method(text, signature):
    start = text.index(signature)
    end = text.index('{', start) + 1
    depth = 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]

common = r'''
#include <objc/runtime.h>
#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
typedef unsigned long NSUInteger;
typedef long NSInteger;
#define MIN(a,b) ((a)<(b)?(a):(b))
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)new;
+ (Class)class;
- (BOOL)isKindOfClass:(Class)cls;
@end
@implementation NSObject
+ (id)new { return class_createInstance(self, 0); }
+ (Class)class { return self; }
- (BOOL)isKindOfClass:(Class)cls {
    for (Class c=object_getClass(self); c; c=class_getSuperclass(c)) if(c==cls)return YES;
    return NO;
}
@end
'''
if a.case == 'relative':
    text = source('NSRelativeDateTimeFormatter.m')
    native = r'''
#include <unicode/ureldatefmt.h>
#include <unicode/unum.h>
enum { NSRelativeDateTimeFormatterStyleNumeric, NSRelativeDateTimeFormatterStyleNamed };
enum { NSRelativeDateTimeFormatterUnitsStyleFull, NSRelativeDateTimeFormatterUnitsStyleSpellOut,
       NSRelativeDateTimeFormatterUnitsStyleShort, NSRelativeDateTimeFormatterUnitsStyleAbbreviated };
enum { NSFormattingContextUnknown, NSFormattingContextDynamic, NSFormattingContextStandalone,
       NSFormattingContextListItem, NSFormattingContextBeginningOfSentence };
#define NSUndefinedDateComponent LONG_MAX
@interface NSString : NSObject { @public char value[2048]; }
+ (id)stringWithCharacters:(const UChar *)chars length:(NSUInteger)length;
- (const char *)UTF8String;
@end
@implementation NSString
+ (id)stringWithCharacters:(const UChar *)chars length:(NSUInteger)length {
    NSString *s=[self new];
    assert(length<sizeof(s->value));
    for(NSUInteger i=0;i<length;i++) { assert(chars[i]<128); s->value[i]=chars[i]; }
    return s;
}
- (const char *)UTF8String { return value; }
@end
@interface NSLocale : NSObject
- (NSString *)localeIdentifier;
@end
@implementation NSLocale
- (NSString *)localeIdentifier {
    NSString *s=[NSString new]; strcpy(s->value,"en_US"); return s;
}
@end
@interface NSDateComponents : NSObject { @public NSInteger v[7]; }
- (NSInteger)year; - (NSInteger)month; - (NSInteger)weekOfYear; - (NSInteger)day;
- (NSInteger)hour; - (NSInteger)minute; - (NSInteger)second;
@end
@implementation NSDateComponents
- (NSInteger)year {return v[0];} - (NSInteger)month {return v[1];}
- (NSInteger)weekOfYear {return v[2];} - (NSInteger)day {return v[3];}
- (NSInteger)hour {return v[4];} - (NSInteger)minute {return v[5];}
- (NSInteger)second {return v[6];}
@end
@interface NSRelativeDateTimeFormatter : NSObject {
@public NSLocale *_locale; NSInteger _dateTimeStyle, _unitsStyle, _formattingContext;
}
@end
@implementation NSRelativeDateTimeFormatter
'''
    native += method(text, '- (NSString *)_formatValue:') + '\n'
    native += method(text, '- (NSString *)localizedStringFromDateComponents:')
    native += r'''
@end
static void expect(NSRelativeDateTimeFormatter *f, NSDateComponents *c, const char *expected) {
    const char *actual=[[f localizedStringFromDateComponents:c] UTF8String];
    if(!actual||strcmp(actual,expected)) {
        fprintf(stderr,"expected '%s', got '%s'\n",expected,actual?actual:"nil"); exit(1);
    }
}
int main(void) {
    NSRelativeDateTimeFormatter *f=[NSRelativeDateTimeFormatter new]; f->_locale=[NSLocale new];
    NSDateComponents *c=[NSDateComponents new];
    // Darling CoreFoundation NSDateComponents.init uses INT_MAX; public sentinel is LONG_MAX.
    const NSInteger sentinels[]={INT_MAX,LONG_MAX,0};
    for(unsigned s=0;s<3;s++) {
        for(unsigned i=0;i<7;i++)c->v[i]=sentinels[s];
        c->v[3]=-1; f->_dateTimeStyle=NSRelativeDateTimeFormatterStyleNumeric;
        expect(f,c,"1 day ago");
        f->_dateTimeStyle=NSRelativeDateTimeFormatterStyleNamed; expect(f,c,"yesterday");
        c->v[3]=sentinels[s]; c->v[5]=2; f->_dateTimeStyle=NSRelativeDateTimeFormatterStyleNumeric;
        expect(f,c,"in 2 minutes");
    }
    for(unsigned i=0;i<7;i++)c->v[i]=LONG_MAX;
    expect(f,c,"in 0 seconds");
    puts("PASS relative components: internal/public sentinels, numeric/named, zero");
}
'''
    libs = ['-licui18n', '-licuuc']
else:
    text = source('NSFileHandle.m')
    native = r'''
@interface NSData : NSObject { @public void *storage; NSUInteger count; }
+ (id)data;
+ (id)dataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length freeWhenDone:(BOOL)owns;
- (const void *)bytes; - (NSUInteger)length;
@end
@implementation NSData
+ (id)data {return [self new];}
+ (id)dataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length freeWhenDone:(BOOL)owns {
    NSData *d=[self new]; d->storage=bytes; d->count=length; return d;
}
- (const void *)bytes {return storage;} - (NSUInteger)length {return count;}
@end
static id NSPOSIXErrorDomain;
@interface NSError : NSObject { @public NSInteger code; }
+ (id)errorWithDomain:(id)domain code:(NSInteger)value userInfo:(id)info;
@end
@implementation NSError
+ (id)errorWithDomain:(id)domain code:(NSInteger)value userInfo:(id)info {
    NSError *e=[self new]; e->code=value; return e;
}
@end
@interface NSException : NSObject @end
@implementation NSException @end
@interface NSFileHandle : NSObject
- (int)fileDescriptor;
@end
@implementation NSFileHandle
- (int)fileDescriptor { return -1; }
@end
enum { NSConcreteFileHandleClosed=2 };
@interface NSConcreteFileHandle : NSFileHandle { @public int _fd; unsigned short _flags; }
@end
@implementation NSConcreteFileHandle
- (int)fileDescriptor {
    if(_flags&NSConcreteFileHandleClosed) {
        fputs("FAIL checked I/O entered legacy closed-descriptor exception path\n",stderr); exit(9);
    }
    return _fd;
}
@end
@interface NSNullFileHandle : NSFileHandle @end
@implementation NSNullFileHandle @end
'''
    native += text[text.index('@implementation NSFileHandle (CheckedIO)'):]
    native += r'''
int main(void) {
    int fds[2]; assert(pipe(fds)==0);
    NSConcreteFileHandle *r=[NSConcreteFileHandle new], *w=[NSConcreteFileHandle new];
    r->_fd=fds[0]; w->_fd=fds[1];
    NSData *d=[NSData new]; d->storage="abc"; d->count=3;
    NSError *e=nil;
    assert([w writeData:d error:&e]&&e==nil);
    NSData *got=[r readDataUpToLength:2 error:&e];
    assert(got->count==2&&!memcmp(got->storage,"ab",2));
    got=[r readDataUpToLength:2 error:&e]; assert(got->count==1);
    close(w->_fd); w->_flags|=NSConcreteFileHandleClosed;
    got=[r readDataUpToLength:2 error:&e]; assert(got&&got->count==0);
    // Reuse the closed fd: checking only the POSIX descriptor would write to a different pipe.
    int other[2]; assert(pipe(other)==0);
    if(other[1]!=w->_fd) { assert(dup2(other[1],w->_fd)==w->_fd); }
    assert(![w writeData:d error:&e]&&e->code==EBADF);
    assert(![w writeData:[NSData data] error:NULL]);
    close(r->_fd); r->_flags|=NSConcreteFileHandleClosed; e=nil;
    assert([r readDataUpToLength:2 error:&e]==nil&&e->code==EBADF);
    assert([r readDataUpToLength:0 error:NULL]==nil);
    NSNullFileHandle *null=[NSNullFileHandle new];
    assert([null writeData:d error:NULL]); assert([[null readDataUpToLength:1 error:NULL] length]==0);
    puts("PASS checked I/O: normal/short/EOF, closed read/write, empty input, reused fd, null device");
}
'''
    libs = []
(a.out / 'probe.m').write_text(common + native)
objc_include = subprocess.check_output(['gcc', '-print-file-name=include'], text=True).strip()
cmd = ['clang', '-g', '-O0', '-fobjc-runtime=gcc', '-fobjc-exceptions', '-isystem', objc_include,
       str(a.out / 'probe.m'), '-lobjc', *libs, '-o', str(a.out / 'probe')]
subprocess.run(cmd, check=True)
subprocess.run([str(a.out / 'probe')], check=True)
