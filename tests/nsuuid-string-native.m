#include <objc/runtime.h>
#include <uuid/uuid.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef unsigned long NSUInteger;
#define NSASCIIStringEncoding 1
static unsigned destroyed, created, released, failures;
#define CHECK(x) do { if (!(x)) { ++failures; printf("FAIL line %d: %s\n", __LINE__, #x); } } while (0)
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
- (id)init;
- (void)release;
- (void)dealloc;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self, 0); }
- (id)init { return self; }
- (void)release { [self dealloc]; }
- (void)dealloc { ++destroyed; object_dispose(self); }
@end
@interface NSString : NSObject { @public const char *text; NSUInteger size; }
+ (id)string:(const char *)s length:(NSUInteger)n;
- (NSUInteger)length;
- (BOOL)getCString:(char *)b maxLength:(NSUInteger)n encoding:(NSUInteger)e;
@end
@implementation NSString
+ (id)string:(const char *)s length:(NSUInteger)n { NSString *v = [self alloc]; v->text = s; v->size = n; return v; }
- (NSUInteger)length { return size; }
- (BOOL)getCString:(char *)b maxLength:(NSUInteger)n encoding:(NSUInteger)e {
    assert(e == NSASCIIStringEncoding);
    if (n <= size) return NO;
    for (NSUInteger i = 0; i < size; ++i) if ((unsigned char)text[i] >= 128) return NO;
    memcpy(b, text, size); b[size] = 0; return YES;
}
@end
static void *kCFAllocatorDefault;
typedef unsigned char *CFUUIDRef;
typedef NSString *CFStringRef;
static CFUUIDRef CFUUIDCreateWithBytes(void *a, unsigned char b0, unsigned char b1,
 unsigned char b2, unsigned char b3, unsigned char b4, unsigned char b5,
 unsigned char b6, unsigned char b7, unsigned char b8, unsigned char b9,
 unsigned char b10, unsigned char b11, unsigned char b12, unsigned char b13,
 unsigned char b14, unsigned char b15) {
    unsigned char bytes[] = {b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15};
    CFUUIDRef u = malloc(16); memcpy(u, bytes, 16); ++created; return u;
}
/* Control the baseline CF parser result; UUID syntax is tested by libuuid. */
static CFUUIDRef CFUUIDCreateFromString(void *a, CFStringRef s) {
    if (!s || !s->size) return NULL;
    CFUUIDRef u = calloc(1, 16); uuid_parse(s->text, u); ++created; return u;
}
static void CFRelease(CFUUIDRef u) { assert(u != NULL); ++released; free(u); }
@interface NativeUUID : NSObject { @public CFUUIDRef _cfUUID; }
- (id)initWithUUIDString:(NSString *)s;
- (id)initWithUUIDBytes:(const uuid_t)bytes;
@end
@implementation NativeUUID
PRODUCTION_METHODS
@end
static void valid(const char *text) {
    NSString *s = [NSString string:text length:strlen(text)];
    NativeUUID *u = [[NativeUUID alloc] initWithUUIDString:s];
    uuid_t expected; assert(uuid_parse(text, expected) == 0);
    CHECK(u != nil);
    if (u) { CHECK(!memcmp(u->_cfUUID, expected, 16)); [u release]; }
    [s release];
}
static void invalid(const char *text, NSUInteger length) {
    NSString *s = text ? [NSString string:text length:length] : nil;
    unsigned before = destroyed;
    NativeUUID *u = [[NativeUUID alloc] initWithUUIDString:s];
    CHECK(u == nil);
    CHECK(destroyed == before + 1);
    // Do not dereference a baseline object with no CF UUID.
    if (u && u->_cfUUID) [u release];
    [s release];
}
int main(void) {
    const char *good[] = {"00000000-0000-0000-0000-000000000000",
        "12345678-1234-5678-9abc-def012345678", "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"};
    for (unsigned i = 0; i < 3; ++i) valid(good[i]);
    const char *bad[] = {"", "not-a-uuid", "12345678123456789abcdef012345678",
        "12345678-1234-5678-9abc-def01234567", "{12345678-1234-5678-9abc-def012345678}",
        " 12345678-1234-5678-9abc-def012345678", "12345678-1234-5678-9abc-def012345678x"};
    for (unsigned i = 0; i < 7; ++i) invalid(bad[i], strlen(bad[i]));
    invalid(NULL, 0);
    for (unsigned i = 0; i < 36; ++i) {
        char text[37]; memcpy(text, good[1], 37);
        text[i] = 'g'; invalid(text, 36);
    }
    char embedded[37]; memcpy(embedded, good[1], 37); embedded[15] = 0; invalid(embedded, 36);
    embedded[15] = (char)0xff; invalid(embedded, 36);
    CHECK(created == released);
    printf("nsuuid-string-native: %u failures\n", failures);
    return failures ? 1 : 0;
}
