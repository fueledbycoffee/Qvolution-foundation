// Regression test for the per-thread KVO pending-notification array.
//
// Documented contract (rung 3, Key-Value Observing Programming Guide): every
// willChangeValueForKey: is followed by a didChangeValueForKey: for the same key.
// Real code breaks that when an exception, such as NSUndefinedKeyException from
// valueForKey:, is thrown between the two calls and caught further up. The pending
// entry pushed by the unmatched will stays in the array. The tests below leave such
// an entry behind, then make later, correctly paired changes, and require that
// delivering them neither crashes nor corrupts the array.
//
// Each scenario can be run alone by name; with no argument all of them run.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef NS_ENUM(NSInteger, Action) {
    ActionNone,
    ActionLeakWill,   // will for "a", then an exception caught here: no did
    ActionNestedSet,  // a complete, correctly paired change of "a"
    ActionThrow,      // raise NSUndefinedKeyException out of the observer callback
};

@interface PendingObject : NSObject
{
    NSInteger _a;
    NSInteger _b;
    BOOL _throwOnValueForA;
}
@property (nonatomic, assign) BOOL throwOnValueForA;
- (NSInteger)a;
- (void)setA:(NSInteger)value;
- (NSInteger)b;
- (void)setB:(NSInteger)value;
- (NSInteger)dependent;
@end

@implementation PendingObject
@synthesize throwOnValueForA = _throwOnValueForA;
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if ([key isEqualToString:@"a"] || [key isEqualToString:@"b"])
    {
        return NO;
    }
    return [super automaticallyNotifiesObserversForKey:key];
}
+ (NSSet *)keyPathsForValuesAffectingDependent
{
    return [NSSet setWithObjects:@"a", @"b", nil];
}
- (NSInteger)a { return _a; }
- (NSInteger)b { return _b; }
- (NSInteger)dependent { return _a + _b; }
- (void)setA:(NSInteger)value
{
    [self willChangeValueForKey:@"a"];
    _a = value;
    [self didChangeValueForKey:@"a"];
}
- (void)setB:(NSInteger)value
{
    [self willChangeValueForKey:@"b"];
    _b = value;
    [self didChangeValueForKey:@"b"];
}
- (id)valueForKey:(NSString *)key
{
    if (_throwOnValueForA && [key isEqualToString:@"a"])
    {
        [NSException raise:NSUndefinedKeyException format:@"simulated unknown key"];
    }
    return [super valueForKey:key];
}
@end

static char observerContext;

@interface PendingObserver : NSObject
{
    NSUInteger _notifications;
    Action _action;
    PendingObject *_target;
    NSInteger _nestedValue;
}
@property (nonatomic, assign) NSUInteger notifications;
@property (nonatomic, assign) Action action;
@property (nonatomic, assign) PendingObject *target;
@end

@implementation PendingObserver
@synthesize notifications = _notifications;
@synthesize action = _action;
@synthesize target = _target;
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    _notifications++;
    Action action = _action;
    _action = ActionNone; // one shot, so nested changes do not recurse
    if (action == ActionLeakWill)
    {
        // What application code does when something between will and did raises.
        [_target willChangeValueForKey:@"a"];
        @try
        {
            [_target valueForKey:@"missingKey"];
        }
        @catch (NSException *exception)
        {
            if (![[exception name] isEqualToString:NSUndefinedKeyException])
            {
                @throw;
            }
        }
    }
    else if (action == ActionNestedSet)
    {
        [_target setA:++_nestedValue + 1000];
    }
    else if (action == ActionThrow)
    {
        [NSException raise:NSUndefinedKeyException format:@"simulated unknown key in callback"];
    }
}
@end

static void expect(BOOL condition, NSString *what)
{
    if (!condition)
    {
        [NSException raise:NSInternalInconsistencyException format:@"%@", what];
    }
}

// After a scenario one plain change must produce exactly one notification and the
// pending array must be drained, whatever the scenario left behind.
static void expectCleanChange(PendingObject *object, PendingObserver *observer)
{
    // Any leftover entries are consumed by the first change that matches them.
    [object setA:-1];
    NSUInteger before = observer.notifications;
    [object setA:-2];
    expect(observer.notifications == before + 1, @"plain change after scenario was not delivered exactly once");
}

static PendingObserver *attach(PendingObject *object, NSString *keyPath, NSKeyValueObservingOptions options)
{
    PendingObserver *observer = [PendingObserver new];
    observer.target = object;
    [object addObserver:observer forKeyPath:keyPath options:options context:&observerContext];
    return observer;
}

static void detach(PendingObject *object, PendingObserver *observer, NSString *keyPath)
{
    [object removeObserver:observer forKeyPath:keyPath];
    [observer release];
}

// Control: a correctly paired nested change from inside a callback.
static void runBalancedNested(void)
{
    PendingObject *object = [PendingObject new];
    PendingObserver *observer = attach(object, @"a", 0);
    observer.action = ActionNestedSet;
    [object setA:1];
    expect(observer.notifications == 2, @"balanced nested change: expected 2 notifications");
    expectCleanChange(object, observer);
    detach(object, observer, @"a");
    [object release];
}

// An unmatched will made inside a callback (level 2 entry), then a later paired
// change whose callback makes a paired nested change of the same key. The nested
// did consumes the stale entry below the outer change's entry, which used to leave
// the outer did's remembered array index past the end of the array.
static void runLeakedWillThenNested(void)
{
    PendingObject *object = [PendingObject new];
    PendingObserver *observer = attach(object, @"a", 0);
    observer.action = ActionLeakWill;
    [object setA:1];
    observer.action = ActionNestedSet;
    [object setA:2];
    expect(observer.notifications >= 4, @"leaked will then nested: notifications lost");
    expectCleanChange(object, observer);
    detach(object, observer, @"a");
    [object release];
}

// The same with two observers of the key and Old requested, so the stale entry
// carries change details that the release callback has to free.
static void runLeakedWillTwoObservers(void)
{
    PendingObject *object = [PendingObject new];
    PendingObserver *first = attach(object, @"a", NSKeyValueObservingOptionOld);
    PendingObserver *second = attach(object, @"a", NSKeyValueObservingOptionOld);
    first.action = ActionLeakWill;
    [object setA:1];
    first.action = ActionNestedSet;
    [object setA:2];
    second.action = ActionNestedSet;
    [object setA:3];
    expect(first.notifications >= 3 && second.notifications >= 3, @"two observers: notifications lost");
    expectCleanChange(object, first);
    detach(object, second, @"a");
    detach(object, first, @"a");
    [object release];
}

// An exception raised out of the observer callback unwinds through did, skipping
// its cleanup, and is caught by the caller. Later changes must still work.
static void runCallbackThrows(void)
{
    PendingObject *object = [PendingObject new];
    PendingObserver *observer = attach(object, @"a", 0);
    observer.action = ActionThrow;
    @try
    {
        [object setA:1];
        expect(NO, @"the callback exception did not propagate");
    }
    @catch (NSException *exception)
    {
        expect([[exception name] isEqualToString:NSUndefinedKeyException], @"unexpected exception");
    }
    observer.action = ActionNestedSet;
    [object setA:2];
    observer.action = ActionLeakWill;
    [object setA:3];
    observer.action = ActionNestedSet;
    [object setA:4];
    expectCleanChange(object, observer);
    detach(object, observer, @"a");
    [object release];
}

// valueForKey: raises while will gathers the Old value for the second observer,
// after the first observer's entry was pushed.
static void runWillThrows(void)
{
    PendingObject *object = [PendingObject new];
    PendingObserver *first = attach(object, @"a", 0);
    PendingObserver *second = attach(object, @"a", NSKeyValueObservingOptionOld);
    object.throwOnValueForA = YES;
    @try
    {
        [object setA:1];
    }
    @catch (NSException *exception)
    {
        expect([[exception name] isEqualToString:NSUndefinedKeyException], @"unexpected exception");
    }
    object.throwOnValueForA = NO;
    first.action = ActionNestedSet;
    [object setA:2];
    second.action = ActionNestedSet;
    [object setA:3];
    expectCleanChange(object, first);
    detach(object, second, @"a");
    detach(object, first, @"a");
    [object release];
}

// F1: an observer is removed between will and did. Its entry is dropped by the pop's
// failure branch, which used to read the entry's retain count after freeing it. Under
// MallocScribble the freed count reads as non-zero, the pop gave up, and the observers
// that were still registered were not notified.
static void runRemovedObserver(void)
{
    for (int removeFirst = 0; removeFirst < 2; removeFirst++)
    {
        PendingObject *object = [PendingObject new];
        PendingObserver *first = attach(object, @"a", NSKeyValueObservingOptionOld);
        PendingObserver *second = attach(object, @"a", NSKeyValueObservingOptionOld);
        PendingObserver *removed = removeFirst ? first : second;
        PendingObserver *kept = removeFirst ? second : first;
        [object willChangeValueForKey:@"a"];
        [object removeObserver:removed forKeyPath:@"a"];
        [object didChangeValueForKey:@"a"];
        expect(removed.notifications == 0, @"removed observer was notified");
        expect(kept.notifications == 1, @"remaining observer was not notified exactly once");
        expectCleanChange(object, kept);
        [object removeObserver:kept forKeyPath:@"a"];
        [removed release];
        [kept release];
        [object release];
    }
}

// will for one key, did for a different one (no matching will), then the real did.
static void runMismatchedKeys(void)
{
    PendingObject *object = [PendingObject new];
    PendingObserver *observer = attach(object, @"a", 0);
    [object willChangeValueForKey:@"a"];
    [object didChangeValueForKey:@"b"];
    expect(observer.notifications == 0, @"did for a different key delivered a notification");
    [object didChangeValueForKey:@"a"];
    expect(observer.notifications == 1, @"matching did did not deliver");
    [object didChangeValueForKey:@"a"]; // did with no will at all
    expect(observer.notifications == 1, @"did without will delivered a notification");
    expectCleanChange(object, observer);
    detach(object, observer, @"a");
    [object release];
}

// A key that depends on a and b, observed together with a, with a stale entry
// below a nested dependent change.
static void runDependentKeys(void)
{
    PendingObject *object = [PendingObject new];
    PendingObserver *dependent = attach(object, @"dependent", 0);
    PendingObserver *direct = attach(object, @"a", 0);
    direct.action = ActionLeakWill;
    [object setA:1];
    dependent.action = ActionNestedSet;
    [object setB:2];
    direct.action = ActionNestedSet;
    [object setA:3];
    expect(dependent.notifications >= 2 && direct.notifications >= 3, @"dependent keys: notifications lost");
    expectCleanChange(object, direct);
    detach(object, direct, @"a");
    detach(object, dependent, @"dependent");
    [object release];
}

typedef struct { const char *name; void (*run)(void); } Scenario;

int main(int argc, const char **argv)
{
    static const Scenario scenarios[] = {
        { "balanced-nested", runBalancedNested },
        { "leaked-will-nested", runLeakedWillThenNested },
        { "leaked-will-two-observers", runLeakedWillTwoObservers },
        { "callback-throws", runCallbackThrows },
        { "will-throws", runWillThrows },
        { "mismatched-keys", runMismatchedKeys },
        { "removed-observer", runRemovedObserver },
        { "dependent-keys", runDependentKeys },
    };
    // removed-observer reads freed memory when it fails. Scribbling freed blocks turns that
    // into a deterministic wrong answer instead of an allocator-dependent one.
    if (getenv("MallocScribble") == NULL && argv[0][0] == '/')
    {
        setenv("MallocScribble", "1", 1);
        execv(argv[0], (char *const *)argv);
    }
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int result = 0;
    int matched = 0;
    @try
    {
        for (size_t i = 0; i < sizeof(scenarios) / sizeof(scenarios[0]); i++)
        {
            if (argc > 1 && strcmp(argv[1], scenarios[i].name) != 0)
            {
                continue;
            }
            matched++;
            for (int iteration = 0; iteration < 16; iteration++)
            {
                NSAutoreleasePool *inner = [NSAutoreleasePool new];
                scenarios[i].run();
                [inner drain];
            }
            printf("PASS: %s\n", scenarios[i].name);
            fflush(stdout);
        }
        if (matched == 0)
        {
            fprintf(stderr, "usage: %s [scenario]\n", argv[0]);
            result = 2;
        }
    }
    @catch (NSException *exception)
    {
        printf("FAIL: %s: %s\n", [[exception name] UTF8String], [[exception reason] UTF8String]);
        result = 1;
    }
    [pool drain];
    return result;
}
