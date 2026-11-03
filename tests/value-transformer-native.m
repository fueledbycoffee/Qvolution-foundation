/* Linux fixture: production methods are inserted verbatim by the runner. */
#include <objc/runtime.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
+ (id)new;
+ (Class)class;
- (Class)class;
- (id)init;
- (id)retain;
- (id)autorelease;
- (void)release;
- (void)dealloc;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self, 0); }
+ (id)new { return [[self alloc] init]; }
+ (Class)class { return self; }
- (Class)class { return object_getClass(self); }
- (id)init { return self; }
- (id)retain { return self; }
- (id)autorelease { return self; }
- (void)release {}
- (void)dealloc { object_dispose(self); }
@end
@interface NSString : NSObject { @public const char *bytes; unsigned length; }
@end
@implementation NSString @end
@interface NSArray : NSObject { @public id item; }
@end
@implementation NSArray @end
@interface NSNumber : NSObject { @public BOOL value; }
+ (id)numberWithBool:(BOOL)value;
- (BOOL)boolValue;
@end
@implementation NSNumber
+ (id)numberWithBool:(BOOL)v { NSNumber *n = [self new]; n->value = v; return n; }
- (BOOL)boolValue { return value; }
@end
@interface NSException : NSObject
+ (void)raise:(id)name format:(id)format;
@end
@implementation NSException
+ (void)raise:(id)name format:(id)format { @throw [self new]; }
@end
static id NSInvalidArgumentException;
static int registryLock;
static void OSSpinLockLock(int *lock) { assert(!*lock && "registry lock poisoned"); *lock = 1; }
static void OSSpinLockUnlock(int *lock) { assert(*lock); *lock = 0; }
static BOOL throwingMutation;
static BOOL throwingAfterMutation;
@interface NSMutableDictionary : NSObject { @public id stored, key; }
- (void)setObject:(id)object forKey:(id)key;
- (void)removeObjectForKey:(id)key;
- (id)objectForKey:(id)key;
- (id)allKeys;
@end
@implementation NSMutableDictionary
- (void)setObject:(id)object forKey:(id)k {
    if (!object || throwingMutation) @throw [NSException new];
    [object retain];
    id old = stored;
    stored = object; key = k;
    [old release];
    if (throwingAfterMutation) @throw [NSException new];
}
- (void)removeObjectForKey:(id)k {
    if (throwingMutation) @throw [NSException new];
    if (k == key) { id old = stored; stored = nil; key = nil; [old release]; }
    if (throwingAfterMutation) @throw [NSException new];
}
- (id)objectForKey:(id)k { return k == key ? stored : nil; }
- (id)allKeys { NSArray *a = [NSArray new]; a->item = key; return a; }
@end
static NSMutableDictionary *registry;
static void checkAndHookSplashScreenTransformer(Class cls) {}
static Class NSClassFromString(id name) { return Nil; }
@interface NSValueTransformer : NSObject
+ (NSMutableDictionary *)_transformerRegistry;
+ (void)setValueTransformer:(id)value forName:(id)name;
+ (id)valueTransformerForName:(id)name;
+ (NSArray *)valueTransformerNames;
+ (BOOL)allowsReverseTransformation;
+ (Class)transformedValueClass;
- (id)transformedValue:(id)value;
- (id)reverseTransformedValue:(id)value;
@end
@implementation NSValueTransformer
+ (NSMutableDictionary *)_transformerRegistry { return registry; }
PRODUCTION_REGISTRY
@end
@interface _NSSharedValueTransformer : NSValueTransformer @end
@implementation _NSSharedValueTransformer @end
@interface _NSNegateBooleanTransformer : _NSSharedValueTransformer @end
@interface _NSIsNilTransformer : _NSNegateBooleanTransformer @end
@interface _NSIsNotNilTransformer : _NSNegateBooleanTransformer @end
PRODUCTION_BOOLEANS

static unsigned destroyed;
static id expectedKey;
@interface ReentrantTransformer : NSValueTransformer { @public unsigned refs; }
@end
@implementation ReentrantTransformer
- (id)init { refs = 1; return self; }
- (id)retain { assert(refs); ++refs; return self; }
- (void)release { assert(refs); if (!--refs) [self dealloc]; }
- (void)dealloc {
    assert([NSValueTransformer valueTransformerNames]->item == expectedKey);
    ++destroyed;
    [super dealloc];
}
@end

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    assert(argc == 2);
    registry = [NSMutableDictionary new];
    if (!strcmp(argv[1], "registry")) {
        id name = @"QVOffset", a = [NSValueTransformer new], b = [NSValueTransformer new];
        assert([NSValueTransformer valueTransformerForName:nil] == nil);
        assert([NSValueTransformer valueTransformerForName:name] == nil);
        [NSValueTransformer setValueTransformer:a forName:name];
        assert([NSValueTransformer valueTransformerForName:name] == a);
        assert([NSValueTransformer valueTransformerNames]->item == name);
        [NSValueTransformer setValueTransformer:b forName:name];
        assert([NSValueTransformer valueTransformerForName:name] == b);
        [NSValueTransformer setValueTransformer:nil forName:name];
        assert([NSValueTransformer valueTransformerForName:name] == nil);
        assert([NSValueTransformer valueTransformerNames]->item == nil);
        [NSValueTransformer setValueTransformer:nil forName:name];
        BOOL raised = NO;
        @try { [NSValueTransformer setValueTransformer:a forName:nil]; }
        @catch (id error) { raised = YES; }
        assert(raised && !registryLock);
        assert([a transformedValue:b] == b && [a reverseTransformedValue:b] == b);
    } else if (!strcmp(argv[1], "reverse")) {
        Class classes[] = {[_NSNegateBooleanTransformer class], [_NSIsNilTransformer class], [_NSIsNotNilTransformer class]};
        for (unsigned i = 0; i < 3; ++i) {
            assert([classes[i] allowsReverseTransformation]);
            assert([classes[i] transformedValueClass] == [NSNumber class]);
            NSValueTransformer *t = [classes[i] new];
            id values[] = {nil, [NSNumber numberWithBool:NO], [NSNumber numberWithBool:YES]};
            for (unsigned j = 0; j < 3; ++j) {
                BOOL expected = i == 0 ? j != 2 : (i == 1 ? j == 0 : j != 0);
                assert([[t transformedValue:values[j]] boolValue] == expected);
                assert([[t reverseTransformedValue:values[j]] boolValue] == expected);
            }
        }
    } else if (!strcmp(argv[1], "exception")) {
        for (unsigned i = 0; i < 2; ++i) {
            BOOL raised = NO;
            throwingMutation = YES;
            @try { [NSValueTransformer setValueTransformer:i ? nil : [NSValueTransformer new] forName:@"throwing"]; }
            @catch (id error) { raised = YES; }
            assert(raised && !registryLock);
            throwingMutation = NO;
            [NSValueTransformer setValueTransformer:[NSValueTransformer new] forName:@"valid"];
            assert([NSValueTransformer valueTransformerForName:@"valid"] != nil);
        }
    } else {
        id name = @"lifetime";
        ReentrantTransformer *old = [ReentrantTransformer new];
        id replacement = [NSValueTransformer new];
        [NSValueTransformer setValueTransformer:old forName:name];
        [old release];
        assert(old->refs == 1 && !destroyed);
        if (!strcmp(argv[1], "same-transformer")) {
            [NSValueTransformer setValueTransformer:old forName:name];
            assert(old->refs == 1 && !destroyed && !registryLock);
        } else if (!strcmp(argv[1], "replacement-reentry")) {
            expectedKey = name;
            [NSValueTransformer setValueTransformer:replacement forName:name];
            assert(destroyed == 1 && !registryLock && registry->stored == replacement);
        } else if (!strcmp(argv[1], "mutation-exception")) {
            for (unsigned remove = 0; remove < 2; ++remove) {
                BOOL raised = NO;
                throwingMutation = YES;
                @try { [NSValueTransformer setValueTransformer:remove ? nil : replacement forName:name]; }
                @catch (id error) { raised = YES; }
                throwingMutation = NO;
                assert(raised && !registryLock && old->refs == 1 && !destroyed);
            }
            for (unsigned remove = 0; remove < 2; ++remove) {
                if (remove) {
                    old = [ReentrantTransformer new];
                    [NSValueTransformer setValueTransformer:old forName:name];
                    [old release];
                }
                expectedKey = remove ? nil : name;
                BOOL raised = NO;
                throwingAfterMutation = YES;
                @try { [NSValueTransformer setValueTransformer:remove ? nil : replacement forName:name]; }
                @catch (id error) { raised = YES; }
                throwingAfterMutation = NO;
                assert(raised && !registryLock && destroyed == remove + 1);
            }
        }
        expectedKey = nil;
        [NSValueTransformer setValueTransformer:nil forName:name];
        assert(destroyed == (!strcmp(argv[1], "mutation-exception") ? 2 : 1));
        assert(!registryLock && registry->stored == nil);
    }
    printf("value-transformer-native %s: PASS\n", argv[1]);
    return 0;
}
