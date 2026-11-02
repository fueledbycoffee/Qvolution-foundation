/* Test doubles for a focused Linux/libobjc test. No Foundation emulation is
 * claimed: production factory functions and ivar wrappers are extracted without
 * edits. CFSet is deliberately disabled, so this test does not verify caching. */
#include <objc/runtime.h>
#include <objc/message.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>
typedef unsigned long NSUInteger;
typedef struct { NSUInteger location, length; } NSRange;
typedef struct { double x, y; } CGPoint;
typedef struct { double width, height; } CGSize;
typedef struct { CGPoint origin; CGSize size; } CGRect;
typedef struct { long first, second, third; } Pair;
typedef struct { unsigned char first, second; } Tiny;
#define NSUTF8StringEncoding 4
#define CF_PRIVATE
#define DEBUG_BREAK() abort()
#define IVAR_NSRANGE @encode(NSRange)
#define IVAR_CGPOINT @encode(CGPoint)
#define IVAR_CGSIZE @encode(CGSize)
#define IVAR_CGRECT @encode(CGRect)
#define _C_BOOL 'B'

__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
+ (Class)class;
+ (BOOL)accessInstanceVariablesDirectly;
- (id)init;
- (id)retain;
- (id)copy;
- (void)release;
- (void)setNilValueForKey:(id)key;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self, 0); }
+ (Class)class { return self; }
+ (BOOL)accessInstanceVariablesDirectly { return YES; }
- (id)init { return self; }
- (id)retain { return self; }
- (id)copy { return self; }
- (void)release {}
- (void)setNilValueForKey:(id)key { @throw self; }
@end

@interface NSString : NSObject { const char *text; }
+ (id)from:(const char *)s;
- (const char *)UTF8String;
- (NSUInteger)lengthOfBytesUsingEncoding:(int)encoding;
- (BOOL)getCString:(char *)s maxLength:(NSUInteger)n encoding:(int)encoding;
@end
@implementation NSString
+ (id)from:(const char *)s { NSString *o = [self alloc]; o->text = s; return o; }
- (const char *)UTF8String { return text; }
- (NSUInteger)lengthOfBytesUsingEncoding:(int)encoding { return strlen(text); }
- (BOOL)getCString:(char *)s maxLength:(NSUInteger)n encoding:(int)encoding { snprintf(s, n, "%s", text); return YES; }
@end

#define NUMBERS(X) X(Char,signed char) X(UnsignedChar,unsigned char) X(Short,short) X(UnsignedShort,unsigned short) X(Int,int) X(UnsignedInt,unsigned int) X(Long,long) X(UnsignedLong,unsigned long) X(LongLong,long long) X(UnsignedLongLong,unsigned long long) X(Float,float) X(Double,double) X(Bool,BOOL)
@interface NSNumber : NSObject { @public long double number; }
#define DECL(N,T) + (id)numberWith##N:(T)v;
NUMBERS(DECL)
#undef DECL
@end
@implementation NSNumber
#define DEF(N,T) + (id)numberWith##N:(T)v { NSNumber *o = [self alloc]; o->number = v; return o; }
NUMBERS(DEF)
#undef DEF
@end
static id kCFBooleanTrue, kCFBooleanFalse;

static const char *NSGetSizeAndAlignment(const char *t, NSUInteger *size, NSUInteger *align) {
    if (!t) return NULL;
    char normalized[256]; unsigned j = 0;
    for (unsigned i = 0; t[i] && j + 1 < sizeof(normalized); ++i) {
        if (t[i] == '"') { while (t[++i] && t[i] != '"') {} if (!t[i]) break; }
        else normalized[j++] = t[i];
    }
    normalized[j] = 0;
    const char *original = t; t = normalized;
    NSUInteger n = 0;
    if (!strcmp(t, @encode(Pair))) n = sizeof(Pair);
    else if (!strcmp(t, @encode(Tiny))) n = sizeof(Tiny);
    else if (!strcmp(t, @encode(NSRange))) n = sizeof(NSRange);
    else if (!strcmp(t, @encode(CGPoint))) n = sizeof(CGPoint);
    else if (!strcmp(t, @encode(CGSize))) n = sizeof(CGSize);
    else if (!strcmp(t, @encode(CGRect))) n = sizeof(CGRect);
    else return NULL;
    if (size) *size = n;
    if (align) *align = 1;
    return original + strlen(original);
}
@interface NSValue : NSObject { const char *type; unsigned char bytes[64]; }
+ (id)value:(const void *)v withObjCType:(const char *)t;
- (void)getValue:(void *)buffer;
- (const char *)objCType;
@end
@implementation NSValue
+ (id)value:(const void *)v withObjCType:(const char *)t {
    NSValue *o = [self alloc]; NSUInteger n = 0;
    NSGetSizeAndAlignment(t, &n, NULL); o->type = t; memcpy(o->bytes, v, n); return o;
}
- (void)getValue:(void *)buffer { NSUInteger n = 0; NSGetSizeAndAlignment(type, &n, NULL); memcpy(buffer, bytes, n); }
- (const char *)objCType { return type; }
@end
@interface NSException : NSObject
+ (void)raise:(id)name format:(id)format;
@end
@implementation NSException
+ (void)raise:(id)name format:(id)format { @throw [self alloc]; }
@end
static id NSInvalidArgumentException;

/* Capture the factory's selected Method/Ivar. Execute that accessor below;
 * allocation, boxing and cache lifetime are intentionally test doubles. */
@interface NSKeyValueAccessor : NSObject { @public Method selectedMethod; Ivar selectedIvar; Class proxyClass; }
- (id)initWithContainerClassID:(Class)c key:(id)key method:(Method)m;
- (id)initWithContainerClassID:(Class)c key:(id)key containerIsa:(Class)isa ivar:(Ivar)i;
- (id)initWithContainerClassID:(Class)c key:(id)key ivar:(Ivar)i;
- (id)initWithContainerClassID:(Class)c key:(id)key containerIsa:(Class)isa;
- (id)initWithContainerClassID:(Class)c key:(id)key methods:(id)m proxyClass:(Class)p;
@end
@implementation NSKeyValueAccessor
- (id)initWithContainerClassID:(Class)c key:(id)key method:(Method)m { selectedMethod = m; return self; }
- (id)initWithContainerClassID:(Class)c key:(id)key containerIsa:(Class)isa ivar:(Ivar)i { selectedIvar = i; return self; }
- (id)initWithContainerClassID:(Class)c key:(id)key ivar:(Ivar)i { selectedIvar = i; return self; }
- (id)initWithContainerClassID:(Class)c key:(id)key containerIsa:(Class)isa { return self; }
- (id)initWithContainerClassID:(Class)c key:(id)key methods:(id)m proxyClass:(Class)p { proxyClass = p; return self; }
@end
#define SUBCLASS(N,B) @interface N : B @end @implementation N @end
SUBCLASS(NSKeyValueGetter,NSKeyValueAccessor)
SUBCLASS(NSKeyValueSetter,NSKeyValueAccessor)
SUBCLASS(NSKeyValueMethodGetter,NSKeyValueGetter)
SUBCLASS(NSKeyValueIvarGetter,NSKeyValueGetter)
SUBCLASS(NSKeyValueUndefinedGetter,NSKeyValueGetter)
SUBCLASS(NSKeyValueMethodSetter,NSKeyValueSetter)
SUBCLASS(NSKeyValueIvarSetter,NSKeyValueSetter)
SUBCLASS(NSKeyValueUndefinedSetter,NSKeyValueSetter)
SUBCLASS(NSKeyValueCollectionGetter,NSKeyValueGetter)
SUBCLASS(NSKeyValueOrderedSet,NSObject)
SUBCLASS(NSKeyValueArray,NSObject)
SUBCLASS(NSKeyValueSet,NSObject)
@interface NativeMethodSet : NSObject { @public Method count, objectAtIndex, indexOfObject, objectsAtIndexes, getObjectsRange, enumerator, member; }
@end
@implementation NativeMethodSet @end
SUBCLASS(NSKeyValueNonmutatingOrderedSetMethodSet,NativeMethodSet)
SUBCLASS(NSKeyValueNonmutatingArrayMethodSet,NativeMethodSet)
SUBCLASS(NSKeyValueNonmutatingSetMethodSet,NativeMethodSet)

typedef struct { void *evil; Class cls; id key; void *implementation, *selector; } NSKVOSetterStruct;
typedef NSKVOSetterStruct NSKVOGetterStruct;
static void *NSKVOSetters, *NSKVOGetters, *kCFAllocatorDefault;
static int _NSKVOSetterCallbacks;
static void *CFSetCreateMutable(void *a, int b, void *c) { return (void *)1; }
static void *CFSetGetValue(void *a, void *b) { return NULL; }
static void CFSetAddValue(void *a, void *b) {}

@interface NSObject (Factory)
+ (id)_createValueSetterWithContainerClassID:(Class)c key:(id)key;
+ (id)_createOtherValueSetterWithContainerClassID:(Class)c key:(id)key;
+ (id)_createValuePrimitiveSetterWithContainerClassID:(Class)c key:(id)key;
+ (id)_createValueGetterWithContainerClassID:(Class)c key:(id)key;
+ (id)_createOtherValueGetterWithContainerClassID:(Class)c key:(id)key;
+ (id)_createValuePrimitiveGetterWithContainerClassID:(Class)c key:(id)key;
@end
static Ivar __NSKeyValueIvarForPattern(Class, NSString *, char *, NSUInteger);
static Method NSKeyValueMethodForPattern(Class, const char *, const char *);
