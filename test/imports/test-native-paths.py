#!/usr/bin/env python3
"""Project the owned search-path function onto minimal GNU ObjC storage.

The actual libsystem enumerator is compiled unchanged. Collection, home and
once shims isolate the Foundation domain forwarding and tilde expansion. This
is not a full Darwin runtime test. Build through qv-slot build.
"""
import argparse
from pathlib import Path
import subprocess
p = argparse.ArgumentParser()
p.add_argument('--out', type=Path, required=True)
p.add_argument('--revision')
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=False)
root = Path(__file__).resolve().parents[2]
superproject = root.parents[2]
source = (subprocess.check_output(['git', '-C', str(root), 'show', a.revision + ':src/NSPathUtilities.m'], text=True)
          if a.revision else (root/'src/NSPathUtilities.m').read_text())
source = source[source.index('NSArray *NSSearchPathForDirectoriesInDomains('):]
# GNU ObjC uses method syntax for the two keyed-subscripting expressions.
source = source.replace('searchPaths[@(key)] = paths;', '[searchPaths setObject:paths forKey:@(key)];')
source = source.replace('searchPaths[@(key)]', '[searchPaths objectForKey:@(key)]')
header = (superproject/'Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/NSSystemDirectories.h').read_text()
(a.out/'NSSystemDirectories.h').write_text(header.replace('#include <Availability.h>', '#define __OSX_AVAILABLE_STARTING(a,b)'))
(a.out/'compat.h').write_text('#include <stdlib.h>\n#include <string.h>\nint issetugid(void);\n')
preamble = r'''
#include <objc/runtime.h>
#include <NSSystemDirectories.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <assert.h>
typedef unsigned long NSUInteger;
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc; - (id)init; - (id)copy; - (id)autorelease; - (void)release;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self,0); }
- (id)init { return self; }
- (id)copy { return self; }
- (id)autorelease { return self; }
- (void)release {}
@end
@interface NSNumber : NSObject { @public NSUInteger value; }
+ (id)numberWithUnsignedInteger:(NSUInteger)n;
@end
@implementation NSNumber
+ (id)numberWithUnsignedInteger:(NSUInteger)n { NSNumber *o=[self alloc];o->value=n;return o; }
@end
@interface NSString : NSObject { @public char *value; }
+ (id)stringWithUTF8String:(const char *)s;
- (NSString *)stringByAppendingPathComponent:(NSString *)s;
@end
@implementation NSString
+ (id)stringWithUTF8String:(const char *)s { NSString *o=[self alloc];o->value=strdup(s);return o; }
- (NSString *)stringByAppendingPathComponent:(NSString *)s {
 char path[PATH_MAX];snprintf(path,sizeof(path),"%s%s%s",value,s->value[0]=='/'?"":"/",s->value);
 return [NSString stringWithUTF8String:path];
}
@end
@interface NSArray : NSObject { @public id values[32]; NSUInteger count; }
+ (id)arrayWithObjects:(const id [])items count:(NSUInteger)n;
- (void)addObject:(id)item;
@end
@implementation NSArray
+ (id)arrayWithObjects:(const id [])items count:(NSUInteger)n {
 NSArray *a=[self alloc]; for(NSUInteger i=0;i<n;i++)[a addObject:items[i]];return a;
}
- (void)addObject:(id)item { assert(count<32);values[count++]=item; }
@end
@interface NSMutableArray : NSArray @end
@implementation NSMutableArray @end
@interface NSMutableDictionary : NSObject { NSNumber *keys[32]; id objects[32]; NSUInteger count; }
- (id)objectForKey:(NSNumber *)key; - (void)setObject:(id)o forKey:(NSNumber *)key;
@end
@implementation NSMutableDictionary
- (id)objectForKey:(NSNumber *)key { for(NSUInteger i=0;i<count;i++)if(keys[i]->value==key->value)return objects[i];return nil; }
- (void)setObject:(id)o forKey:(NSNumber *)key { assert(count<32);keys[count]=key;objects[count++]=o; }
@end
typedef long dispatch_once_t;
static void dispatch_once(dispatch_once_t *once, void (^body)(void)) { if(!*once){*once=1;body();} }
static NSString *NSHomeDirectory(void) { return [NSString stringWithUTF8String:"/native-home"]; }
#define PATH_HOME '~'
int issetugid(void) { return 0; }
'''
suffix = r'''
int main(int argc, char **argv) {
 BOOL local = argc==1;
 NSArray *paths=NSSearchPathForDirectoriesInDomains(local?NSApplicationDirectory:NSApplicationSupportDirectory,
                                                   local?NSLocalDomainMask:NSUserDomainMask,YES);
 const char *expected=local?"/Applications":"/native-home/Library/Application Support";
 if(paths->count!=1||strcmp(((NSString *)paths->values[0])->value,expected)) {
  fprintf(stderr,"FAIL %s search returned %lu paths\n",local?"local":"user",paths->count);return 1;
 }
 assert(NSSearchPathForDirectoriesInDomains(NSApplicationDirectory,0,YES)->count==0);
 puts(local?"native Foundation local paths: passed":"native Foundation user paths: passed");
}
'''
(a.out/'paths.m').write_text(preamble+source+suffix)
runtime = superproject.parents[2]/'toolchains/swift-6.3.3-linux-x64/compiler/usr/lib/swift/linux'
subprocess.run(['/usr/bin/clang', '-g', '-O0', '-fblocks', '-fsanitize=address,undefined',
    '-I/usr/lib/gcc/x86_64-linux-gnu/15/include', '-I'+str(a.out), '-include',str(a.out/'compat.h'),
    str(a.out/'paths.m'),str(superproject/'src/libsystem_coreservices/NSSystemDirectories.c'),
    '-l:libobjc.so.4', '-L'+str(runtime), '-Wl,-rpath,'+str(runtime),
    '-lBlocksRuntime','-o',str(a.out/'paths')],check=True)
