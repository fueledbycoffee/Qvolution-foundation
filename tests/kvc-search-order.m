#import <Foundation/Foundation.h>
#import <CoreFoundation/CFNumber.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

static unsigned failures;
#define CHECK(c, label) do { if (!(c)) { fprintf(stderr, "FAIL %s\n", label); ++failures; } } while (0)
#define SAME(a, b, label) CHECK([(a) isEqual:(b)], label)
#define RUN(f) do { @try { f(); } @catch (NSException *e) { fprintf(stderr, "FAIL " #f " exception\n"); ++failures; } } while (0)

#define GETTER_CLASS(name, methods) \
@interface name : NSObject @end \
@implementation name methods @end
GETTER_CLASS(KVCGetOnly, - (id)getToken { return @"get"; })
GETTER_CLASS(KVCPlainOnly, - (id)token { return @"plain"; })
GETTER_CLASS(KVCIsOnly, - (id)isToken { return @"is"; })
GETTER_CLASS(KVCUnderscoreOnly, - (id)_token { return @"underscore"; })
GETTER_CLASS(KVCGetWins,
    - (id)getToken { return @"get"; }
    - (id)token { return @"plain"; }
    - (id)isToken { return @"is"; }
    - (id)_token { return @"underscore"; })
GETTER_CLASS(KVCPlainWins,
    - (id)token { return @"plain"; }
    - (id)isToken { return @"is"; }
    - (id)_token { return @"underscore"; })
GETTER_CLASS(KVCIsWins,
    - (id)isToken { return @"is"; }
    - (id)_token { return @"underscore"; })
GETTER_CLASS(KVCUnderscoreWins,
    - (id)_getToken { return @"undocumented"; }
    - (id)_token { return @"underscore"; })
GETTER_CLASS(KVCPrimitiveOnly,
    - (id)getPrimitiveToken { return @"primitive"; }
    - (id)primitiveToken { return @"primitive"; }
    - (id)_getToken { return @"undocumented"; }
    - (id)valueForUndefinedKey:(NSString *)key { return @"undefined"; })

static void getters(void)
{
    Class classes[] = {[KVCGetOnly class], [KVCPlainOnly class], [KVCIsOnly class],
        [KVCUnderscoreOnly class], [KVCGetWins class], [KVCPlainWins class],
        [KVCIsWins class], [KVCUnderscoreWins class], [KVCPrimitiveOnly class]};
    NSString *answers[] = {@"get", @"plain", @"is", @"underscore", @"get", @"plain", @"is", @"underscore", @"undefined"};
    for (unsigned i = 0; i < sizeof(classes) / sizeof(classes[0]); ++i) {
        id o = [[[classes[i] alloc] init] autorelease];
        for (unsigned j = 0; j < 3; ++j)
            SAME([o valueForKey:@"token"], answers[i], "getter pattern and cached result");
    }
}

#define IVAR_CLASS(name, declarations, initializers, result) \
@interface name : NSObject { @public declarations } - (id)selected; @end \
@implementation name \
- (id)init { if ((self = [super init])) { initializers } return self; } \
- (id)selected { return result; } \
@end
IVAR_CLASS(KVCUnderIvar, id _token;, _token = @"under";, _token)
IVAR_CLASS(KVCUnderIsIvar, id _isToken;, _isToken = @"under-is";, _isToken)
IVAR_CLASS(KVCPlainIvar, id token;, token = @"plain";, token)
IVAR_CLASS(KVCIsIvar, id isToken;, isToken = @"is";, isToken)
IVAR_CLASS(KVCAllIvars, id _token; id _isToken; id token; id isToken;,
    _token = @"under"; _isToken = @"under-is"; token = @"plain"; isToken = @"is";, _token)
IVAR_CLASS(KVCUnderIsWins, id _isToken; id token; id isToken;,
    _isToken = @"under-is"; token = @"plain"; isToken = @"is";, _isToken)
IVAR_CLASS(KVCPlainIvarWins, id token; id isToken;,
    token = @"plain"; isToken = @"is";, token)
IVAR_CLASS(KVCUpperIvar, id _URL;, _URL = @"upper";, _URL)

static void ivars(void)
{
    Class classes[] = {[KVCUnderIvar class], [KVCUnderIsIvar class], [KVCPlainIvar class],
        [KVCIsIvar class], [KVCAllIvars class], [KVCUnderIsWins class], [KVCPlainIvarWins class], [KVCUpperIvar class]};
    for (unsigned i = 0; i < sizeof(classes) / sizeof(classes[0]); ++i) {
        id o = [[[classes[i] alloc] init] autorelease];
        NSString *key = i == 7 ? @"URL" : @"token";
        SAME([o valueForKey:key], [o selected], "ivar getter order");
        [o setValue:@"written" forKey:key];
        SAME([o selected], @"written", "ivar setter order");
        SAME([o valueForKey:key], @"written", "ivar setter readback");
    }
    KVCUnderIsWins *o = [[[KVCUnderIsWins alloc] init] autorelease];
    [o setValue:@"changed" forKey:@"token"];
    SAME(o->token, @"plain", "lower precedence ivar unchanged");
    SAME(o->isToken, @"is", "last precedence ivar unchanged");
}

@interface KVCSetterBase : NSObject { @public id written; id _token; } @end
@implementation KVCSetterBase
- (void)dealloc { [written release]; [_token release]; [super dealloc]; }
@end
@interface KVCSetterOnly : KVCSetterBase @end
@implementation KVCSetterOnly
- (void)setToken:(id)v { [written autorelease]; written = [v retain]; }
@end
@interface KVCPrivateSetterOnly : KVCSetterBase @end
@implementation KVCPrivateSetterOnly
- (void)_setToken:(id)v { [written autorelease]; written = [v retain]; }
@end
@interface KVCSetterWins : KVCPrivateSetterOnly @end
@implementation KVCSetterWins
- (void)setToken:(id)v { [written autorelease]; written = [[@"public:" stringByAppendingString:v] retain]; }
@end
@interface KVCNoDirect : KVCSetterBase { @public id unknown; } @end
@implementation KVCNoDirect
+ (BOOL)accessInstanceVariablesDirectly { return NO; }
- (id)valueForUndefinedKey:(NSString *)key { return @"undefined"; }
- (void)setValue:(id)v forUndefinedKey:(NSString *)key { unknown = v; }
- (void)setPrimitiveToken:(id)v { written = v; }
@end

static void settersAndUndefined(void)
{
    Class classes[] = {[KVCSetterOnly class], [KVCPrivateSetterOnly class], [KVCSetterWins class]};
    for (unsigned i = 0; i < 3; ++i) {
        KVCSetterBase *o = [[[classes[i] alloc] init] autorelease];
        [o setValue:@"written" forKey:@"token"];
        SAME(o->written, i == 2 ? @"public:written" : @"written", "setter accessor order");
        CHECK(o->_token == nil, "setter beats ivar");
        if (i != 2) {
            [o setValue:nil forKey:@"token"];
            CHECK(o->written == nil, "nil object setter");
        }
    }
    KVCSetterBase *root = [[[KVCSetterBase alloc] init] autorelease];
    [root setValue:[[[KVCUnderscoreOnly alloc] init] autorelease] forKey:@"token"];
    SAME([root valueForKeyPath:@"token.token"], @"underscore", "key path final accessor hop");
    KVCNoDirect *o = [[[KVCNoDirect alloc] init] autorelease];
    SAME([o valueForKey:@"token"], @"undefined", "direct ivars disabled getter");
    [o setValue:@"fallback" forKey:@"token"];
    SAME(o->unknown, @"fallback", "direct ivars disabled setter fallback");
    CHECK(o->_token == nil && o->written == nil, "primitive setter excluded");
    NSObject *plain = [[[NSObject alloc] init] autorelease];
    BOOL raised = NO;
    @try { [plain valueForKey:@"absent"]; }
    @catch (NSException *e) { raised = [[e name] isEqual:NSUndefinedKeyException]; }
    CHECK(raised, "default undefined getter exception");
    raised = NO;
    @try { [plain setValue:@1 forKey:@"absent"]; }
    @catch (NSException *e) { raised = [[e name] isEqual:NSUndefinedKeyException]; }
    CHECK(raised, "default undefined setter exception");
}

typedef struct { long first; long second; long third; } KVCPair;
typedef struct { unsigned char first; unsigned char second; } KVCTiny;
@interface KVCNumbers : NSObject {
@public
    signed char _signedValue;
    int _integerValue;
    _Bool _truth;
    BOOL _foundationBool;
    NSRange _range;
    KVCPair _pair;
    KVCTiny _tiny;
    id _object;
}
@end
@implementation KVCNumbers
- (id)init { if ((self = [super init])) {
    _signedValue = -7; _integerValue = -345; _truth = 1; _foundationBool = YES;
    _range = NSMakeRange(8, 13); _pair = (KVCPair){2, 4, 8}; _tiny = (KVCTiny){17, 29};
} return self; }
- (signed char)signedMethod { return _signedValue; }
- (void)setSignedMethod:(signed char)v { _signedValue = v; }
- (int)integerMethod { return _integerValue; }
- (void)setIntegerMethod:(int)v { _integerValue = v; }
- (_Bool)truthMethod { return _truth; }
- (void)setTruthMethod:(_Bool)v { _truth = v; }
- (BOOL)foundationBoolMethod { return _foundationBool; }
- (NSRange)rangeMethod { return _range; }
- (void)setRangeMethod:(NSRange)v { _range = v; }
- (KVCPair)pairMethod { return _pair; }
- (void)setPairMethod:(KVCPair)v { _pair = v; }
- (KVCTiny)tinyMethod { return _tiny; }
- (void)setTinyMethod:(KVCTiny)v { _tiny = v; }
- (id)objectMethod { return nil; }
@end
@interface KVCNilOverride : KVCNumbers { @public unsigned nilCalls; } @end
@implementation KVCNilOverride
- (void)setNilValueForKey:(NSString *)key { ++nilCalls; }
@end

static void boxing(void)
{
    KVCNumbers *o = [[[KVCNumbers alloc] init] autorelease];
    for (unsigned method = 0; method < 2; ++method) {
        NSString *suffix = method ? @"Method" : @"";
        NSString *signedKey = [@"signed" stringByAppendingString:method ? suffix : @"Value"];
        NSString *integerKey = [@"integer" stringByAppendingString:method ? suffix : @"Value"];
        NSString *truthKey = [@"truth" stringByAppendingString:suffix];
        SAME([o valueForKey:signedKey], @(-7), "signed char boxing");
        SAME([o valueForKey:integerKey], @(-345), "int boxing");
        CHECK([o valueForKey:truthKey] == (id)kCFBooleanTrue, "B encoding CFBoolean true identity");
        NSString *boolKey = [@"foundationBool" stringByAppendingString:suffix];
        CHECK([[o valueForKey:boolKey] boolValue], "BOOL value");
        if (@encode(BOOL)[0] == 'B' || @encode(BOOL)[0] == 'c') CHECK([o valueForKey:boolKey] == (id)kCFBooleanTrue, "BOOL B identity");
        CHECK([o valueForKey:[@"object" stringByAppendingString:suffix]] == nil, "object nil");
        NSValue *range = [o valueForKey:[@"range" stringByAppendingString:suffix]];
        CHECK(NSEqualRanges([range rangeValue], NSMakeRange(8, 13)), "range boxing");
        KVCPair pair = {0}; KVCTiny tiny = {0};
        [[o valueForKey:[@"pair" stringByAppendingString:suffix]] getValue:&pair];
        [[o valueForKey:[@"tiny" stringByAppendingString:suffix]] getValue:&tiny];
        CHECK(pair.first == 2 && pair.second == 4 && pair.third == 8, "large struct boxing");
        CHECK(tiny.first == 17 && tiny.second == 29, "small struct boxing");
        [o setValue:@NO forKey:truthKey];
        CHECK([o valueForKey:truthKey] == (id)kCFBooleanFalse, "B encoding CFBoolean false identity");
        [o setValue:@YES forKey:truthKey];
        [o setValue:@(-11) forKey:signedKey];
        CHECK(o->_signedValue == -11, "signed char unboxing");
        for (int value = 0; value <= 1; ++value) {
            [o setValue:@(value) forKey:signedKey];
            CHECK([o valueForKey:signedKey] == (id)(value ? kCFBooleanTrue : kCFBooleanFalse), "c encoding boolean singleton identity");
        }
        [o setValue:@(-7) forKey:signedKey];
        BOOL raised = NO;
        @try { [o setValue:nil forKey:integerKey]; }
        @catch (NSException *e) { raised = [[e name] isEqual:NSInvalidArgumentException]; }
        CHECK(raised, "nil scalar default exception");
    }
    KVCPair pair = {32, 64, 128}; KVCTiny tiny = {41, 43};
    [o setValue:[NSValue value:&pair withObjCType:@encode(KVCPair)] forKey:@"pairMethod"];
    CHECK(o->_pair.third == 128, "large struct method unboxing");
    [o setValue:[NSValue value:&tiny withObjCType:@encode(KVCTiny)] forKey:@"tinyMethod"];
    CHECK(o->_tiny.second == 43, "small struct method unboxing");
    pair.third = 256;
    [o setValue:[NSValue value:&pair withObjCType:@encode(KVCPair)] forKey:@"pair"];
    CHECK(o->_pair.third == 256, "struct ivar unboxing");
    [o setValue:[NSValue valueWithRange:NSMakeRange(21, 34)] forKey:@"rangeMethod"];
    CHECK(NSEqualRanges(o->_range, NSMakeRange(21, 34)), "known struct method unboxing");
    [o setValue:[NSValue valueWithRange:NSMakeRange(55, 89)] forKey:@"range"];
    CHECK(NSEqualRanges(o->_range, NSMakeRange(55, 89)), "known struct ivar unboxing");
    for (NSString *key in @[@"pair", @"pairMethod"]) {
        BOOL raised = NO;
        @try { [o setValue:[NSValue value:&tiny withObjCType:@encode(KVCTiny)] forKey:key]; }
        @catch (NSException *e) { raised = [[e name] isEqual:NSInvalidArgumentException]; }
        CHECK(raised, "incompatible struct size rejected");
        CHECK(o->_pair.third == 256, "incompatible struct leaves destination unchanged");
    }
    for (NSString *key in @[@"pair", @"pairMethod", @"range", @"rangeMethod"]) {
        BOOL raised = NO;
        @try { [o setValue:nil forKey:key]; }
        @catch (NSException *e) { raised = [[e name] isEqual:NSInvalidArgumentException]; }
        CHECK(raised, "nil struct default exception");
    }
    KVCNilOverride *nilObject = [[[KVCNilOverride alloc] init] autorelease];
    for (NSString *key in @[@"integerValue", @"integerMethod", @"pair", @"pairMethod"])
        [nilObject setValue:nil forKey:key];
    CHECK(nilObject->nilCalls == 4, "setNilValueForKey scalar and struct dispatch");
}

@interface KVCArray : NSObject { @public NSMutableArray *backing; } @end
@implementation KVCArray
- (id)init { if ((self = [super init])) backing = [[NSMutableArray alloc] initWithObjects:@"a", @"b", nil]; return self; }
- (void)dealloc { [backing release]; [super dealloc]; }
- (NSUInteger)countOfToken { return [backing count]; }
- (id)objectInTokenAtIndex:(NSUInteger)i { return [backing objectAtIndex:i]; }
- (void)insertObject:(id)o inTokenAtIndex:(NSUInteger)i { [backing insertObject:o atIndex:i]; }
- (void)removeObjectFromTokenAtIndex:(NSUInteger)i { [backing removeObjectAtIndex:i]; }
@end
@interface KVCIndexes : NSObject { NSArray *backing; } @end
@implementation KVCIndexes
- (id)init { if ((self = [super init])) backing = [[NSArray alloc] initWithObjects:@"a", @"b", nil]; return self; }
- (void)dealloc { [backing release]; [super dealloc]; }
- (NSUInteger)countOfToken { return [backing count]; }
- (NSArray *)tokenAtIndexes:(NSIndexSet *)i { return [backing objectsAtIndexes:i]; }
@end
@interface KVCSet : NSObject { NSMutableSet *backing; } @end
@implementation KVCSet
- (id)init { if ((self = [super init])) backing = [[NSMutableSet alloc] initWithObjects:@"a", @"b", nil]; return self; }
- (void)dealloc { [backing release]; [super dealloc]; }
- (NSUInteger)countOfToken { return [backing count]; }
- (NSEnumerator *)enumeratorOfToken { return [backing objectEnumerator]; }
- (id)memberOfToken:(id)o { return [backing member:o]; }
- (void)addTokenObject:(id)o { [backing addObject:o]; }
- (void)removeTokenObject:(id)o { [backing removeObject:o]; }
@end

@interface KVCProxyIvars : NSObject { @public id _isToken; id token; } @end
@implementation KVCProxyIvars
- (void)dealloc { [_isToken release]; [token release]; [super dealloc]; }
@end
@interface KVCProxySetter : NSObject { @public id backing; unsigned writes; } @end
@implementation KVCProxySetter
- (id)token { return backing; }
- (void)setToken:(id)value { ++writes; [value retain]; [backing release]; backing = value; }
- (void)dealloc { [backing release]; [super dealloc]; }
@end

static void collections(void)
{
    KVCArray *o = [[[KVCArray alloc] init] autorelease];
    NSArray *proxy = [o valueForKey:@"token"];
    SAME(proxy, (@[@"a", @"b"]), "indexed array proxy");
    NSMutableArray *mutable = [o mutableArrayValueForKey:@"token"];
    [mutable insertObject:@"c" atIndex:1];
    SAME(o->backing, (@[@"a", @"c", @"b"]), "array mutator forwarding");
    CHECK([proxy count] == 3, "array read proxy stays live");
    [mutable removeObjectAtIndex:1];
    SAME(o->backing, (@[@"a", @"b"]), "array removal forwarding");
    KVCIndexes *indexes = [[[KVCIndexes alloc] init] autorelease];
    SAME([indexes valueForKey:@"token"], (@[@"a", @"b"]), "indexes-only array proxy");
    KVCSet *set = [[[KVCSet alloc] init] autorelease];
    NSSet *setProxy = [set valueForKey:@"token"];
    CHECK([setProxy count] == 2 && [setProxy containsObject:@"a"], "set read proxy");
    NSMutableSet *mutableSet = [set mutableSetValueForKey:@"token"];
    [mutableSet addObject:@"c"];
    CHECK([setProxy containsObject:@"c"], "set insertion forwarding");
    [mutableSet removeObject:@"a"];
    CHECK(![setProxy containsObject:@"a"], "set removal forwarding");
    KVCProxyIvars *ivars = [[[KVCProxyIvars alloc] init] autorelease];
    ivars->_isToken = [[NSMutableArray alloc] initWithObjects:@"a", nil];
    ivars->token = [[NSMutableArray alloc] initWithObjects:@"untouched", nil];
    [[ivars mutableArrayValueForKey:@"token"] addObject:@"b"];
    SAME(ivars->_isToken, (@[@"a", @"b"]), "array proxy uses corrected ivar order");
    SAME(ivars->token, (@[@"untouched"]), "array proxy preserves lower precedence ivar");
    [ivars->_isToken release];
    ivars->_isToken = [[NSMutableSet alloc] initWithObjects:@"a", nil];
    [[ivars mutableSetValueForKey:@"token"] addObject:@"b"];
    CHECK([ivars->_isToken containsObject:@"b"], "set proxy uses corrected ivar order");
    SAME(ivars->token, (@[@"untouched"]), "set proxy preserves lower precedence ivar");
    KVCProxySetter *slow = [[[KVCProxySetter alloc] init] autorelease];
    slow->backing = [[NSArray alloc] initWithObjects:@"a", nil];
    [[slow mutableArrayValueForKey:@"token"] addObject:@"b"];
    SAME(slow->backing, (@[@"a", @"b"]), "array proxy setter fallback");
    CHECK(slow->writes == 1, "array proxy invokes setter once");
    [slow->backing release]; slow->backing = [[NSSet alloc] initWithObjects:@"a", nil];
    [[slow mutableSetValueForKey:@"token"] addObject:@"b"];
    CHECK([slow->backing containsObject:@"b"] && slow->writes == 2, "set proxy setter fallback");
}

@interface KVCObserver : NSObject { @public unsigned count; id old; id new; } @end
@implementation KVCObserver
- (void)observeValueForKeyPath:(NSString *)key ofObject:(id)o change:(NSDictionary *)change context:(void *)context {
    ++count; [old release]; [new release];
    old = [[change objectForKey:NSKeyValueChangeOldKey] retain];
    new = [[change objectForKey:NSKeyValueChangeNewKey] retain];
}
- (void)dealloc { [old release]; [new release]; [super dealloc]; }
@end
@interface KVCObserved : NSObject { id _token; int _other; } @end
@implementation KVCObserved
- (id)init { if ((self = [super init])) _token = [@"before" retain]; return self; }
- (id)token { return _token; }
- (void)setToken:(id)v { [v retain]; [_token release]; _token = v; }
- (int)other { return _other; }
- (void)setOther:(int)v { _other = v; }
- (void)dealloc { [_token release]; [super dealloc]; }
@end

static void observing(void)
{
    KVCObserver *observer = [[[KVCObserver alloc] init] autorelease];
    KVCObserved *o = [[[KVCObserved alloc] init] autorelease];
    [o addObserver:observer forKeyPath:@"other" options:0 context:NULL];
    [o setValue:@"before" forKey:@"token"]; // Cache object IMP on notifying subclass before observing token.
    [o addObserver:observer forKeyPath:@"token" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:NULL];
    [o setValue:@"after" forKey:@"token"];
    CHECK(observer->count == 1, "cached object setter KVO notification");
    SAME(observer->old, @"before", "KVO old value");
    SAME(observer->new, @"after", "KVO new value");
    SAME([o valueForKey:@"token"], @"after", "notifying subclass getter");
    [o removeObserver:observer forKeyPath:@"token"];
    [o removeObserver:observer forKeyPath:@"other"];
    KVCUnderIvar *ivar = [[[KVCUnderIvar alloc] init] autorelease];
    observer->count = 0;
    [ivar addObserver:observer forKeyPath:@"token" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:NULL];
    [ivar setValue:@"after" forKey:@"token"];
    CHECK(observer->count == 1, "ivar setter KVO notification");
    SAME(observer->new, @"after", "ivar KVO value");
    [ivar removeObserver:observer forKeyPath:@"token"];
}

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    RUN(getters); RUN(ivars); RUN(settersAndUndefined); RUN(boxing); RUN(collections); RUN(observing);
    fprintf(stdout, "kvc-search-order: %u failures; BOOL encoding=%s\n", failures, @encode(BOOL));
    [pool drain];
    return failures ? 1 : 0;
}
