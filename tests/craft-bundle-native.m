// Native fixture for the byte-identical bundleForClass: method excerpt.
// Linux Swift lacks ObjC interoperability: image lookup, NSString, NSBundle,
// and value retention are fixtures. CFDictionary and Swift metadata are real.
#include <CoreFoundation/CFDictionary.h>
#include <objc/runtime.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)new;
@end
@implementation NSObject
+ (id)new { return class_createInstance(self, 0); }
@end

@interface NSString : NSObject { @public char *text; }
+ (id)stringWithUTF8String:(const char *)value;
- (BOOL)isEqualToString:(NSString *)other;
@end
@implementation NSString
+ (id)stringWithUTF8String:(const char *)value {
    NSString *s = [self new]; s->text = strdup(value); return s;
}
- (BOOL)isEqualToString:(NSString *)other {
    return other && strcmp(text, other->text) == 0;
}
@end

@interface NSBundle : NSObject { @public NSString *path; unsigned retains; }
+ (NSBundle *)bundleForClass;
+ (NSBundle *)mainBundle;
+ (NSBundle *)bundleWithPath:(NSString *)value;
+ (NSBundle *)bundleForClass:(Class)value;
- (NSString *)bundlePath;
@end
static NSBundle *mainFixture;
static unsigned creations, resolutions;
static const void *keys[8];
static const char *images[8];
static const char *fixtureImageName(Class key) {
    __atomic_add_fetch(&resolutions, 1, __ATOMIC_RELAXED);
    for (unsigned i = 0; i < 8; ++i) if (keys[i] == key) return images[i];
    abort();
}
static Class fixtureMetaClass(id key) { return (Class)key; }
static BOOL fixtureResponds(Class key, SEL selector) { return NO; }
#define class_getImageName fixtureImageName
#define object_getClass fixtureMetaClass
#define class_respondsToSelector fixtureResponds
static NSString *_NSFrameworkPathFromLibraryPath(NSString *value) {
    return strstr(value->text, ".framework/") ? [NSString stringWithUTF8String:"/Fixture.framework"] : nil;
}
static NSString *_NSBundlePathFromExecutablePath(NSString *value) {
    if (strcmp(value->text, "unresolved") == 0) return nil;
    if (strcmp(value->text, "invalid") == 0) return [NSString stringWithUTF8String:"invalid"];
    return [NSString stringWithUTF8String:"/Fixture.app"];
}
static const void *retainBundle(CFAllocatorRef allocator, const void *value) {
    __atomic_add_fetch(&((NSBundle *)value)->retains, 1, __ATOMIC_RELAXED);
    return value;
}
static void releaseBundle(CFAllocatorRef allocator, const void *value) {
    __atomic_sub_fetch(&((NSBundle *)value)->retains, 1, __ATOMIC_RELAXED);
}
static const CFDictionaryValueCallBacks fixtureValues = {0, retainBundle, releaseBundle, NULL, NULL};
#define kCFTypeDictionaryValueCallBacks fixtureValues
#ifdef BASELINE
// The old NSMutableDictionary copies its keys. A Swift class has no copy
// operation; fail deterministically instead of messaging foreign GNU metadata.
static const void *copyClassKey(CFAllocatorRef allocator, const void *value) {
    fputs("EXPECTED REGRESSION: copying dictionary requested copy of Swift class key\n", stderr);
    exit(70);
}
@interface NSMutableDictionary : NSObject { CFMutableDictionaryRef contents; }
+ (id)alloc;
- (id)init;
- (id)objectForKey:(Class)key;
- (void)setObject:(id)value forKey:(Class)key;
@end
@implementation NSMutableDictionary
+ (id)alloc { return [self new]; }
- (id)init {
    CFDictionaryKeyCallBacks callbacks = {0, copyClassKey, NULL, NULL, NULL, NULL};
    contents = CFDictionaryCreateMutable(NULL, 0, &callbacks, &fixtureValues);
    return self;
}
- (id)objectForKey:(Class)key { return (id)CFDictionaryGetValue(contents, key); }
- (void)setObject:(id)value forKey:(Class)key { CFDictionarySetValue(contents, key, value); }
@end
#endif
#include "craft-bundle-cache.inc"
@implementation NSBundle
+ (NSBundle *)bundleForClass { abort(); }
+ (NSBundle *)mainBundle { return mainFixture; }
+ (NSBundle *)bundleWithPath:(NSString *)value {
    __atomic_add_fetch(&creations, 1, __ATOMIC_RELAXED);
    if (strcmp(value->text, "invalid") == 0) return nil;
    NSBundle *b = [self new]; b->path = value; return b;
}
- (NSString *)bundlePath { return path; }
#include "craft-bundle-method.inc"
@end

void configureBundleFixture(const void *root, const void *subclass, const void *framework,
                            const void *dynamic, const void *unresolved, const void *invalid,
                            const void *concurrent, const void *late) {
    const void *input[] = {root, subclass, framework, dynamic, unresolved, invalid, concurrent, late};
    const char *paths[] = {"/Fixture.app/Contents/MacOS/Fixture", "/Fixture.app/Contents/MacOS/Fixture",
                          "/Fixture.framework/Versions/A/Fixture", NULL, "unresolved", "invalid",
                          "/Fixture.framework/Versions/A/Fixture", "invalid"};
    memcpy(keys, input, sizeof(keys)); memcpy(images, paths, sizeof(images));
    mainFixture = [NSBundle new]; mainFixture->path = [NSString stringWithUTF8String:"/Fixture.app"];
#include "craft-bundle-init.inc"
}
void checkBundleFixture(const void *key, int expected) {
    NSBundle *b = [NSBundle bundleForClass:(Class)key];
    assert(b);
    if (expected == 1) assert(b == mainFixture);
    else {
        assert(b != mainFixture);
        assert(strcmp(b->path->text, "/Fixture.framework") == 0);
    }
    assert([NSBundle bundleForClass:(Class)key] == b);
}
void finishBundleFixture(void) {
    assert([NSBundle bundleForClass:Nil] == mainFixture);
#ifndef BASELINE
    assert(mainFixture->retains == 5); // main, subclass and three fallback keys
    unsigned before = resolutions;
    for (unsigned i = 0; i < 7; ++i) checkBundleFixture(keys[i], i == 2 || i == 6 ? 2 : 1);
    assert(resolutions == before); // warm calls do no image/path resolution
    NSBundle *saved = mainFixture;
    mainFixture = nil;
    assert([NSBundle bundleForClass:(Class)keys[7]] == nil);
    assert(CFDictionaryGetValue(classToBundle, keys[7]) == NULL);
    mainFixture = saved;
    checkBundleFixture(keys[7], 1); // absence was not cached
    CFRelease(classToBundle);
    assert(mainFixture->retains == 0);
#endif
    puts("PASS: extracted bundleForClass, real CF pointer cache, strong values, main identity, fallbacks, concurrent access");
}
