#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static NSUInteger childDeaths;

@interface KVOForwardingChild : NSObject
@property (nonatomic, copy) NSString *c;
@end

@implementation KVOForwardingChild
- (void)dealloc
{
    childDeaths++;
    [_c release];
    [super dealloc];
}
@end

@interface KVOForwardingObject : NSObject
{
    NSAutoreleasePool *_willPool;
}
@property (nonatomic, retain) KVOForwardingChild *b;
@property (nonatomic, readonly) NSString *a;
@end

@implementation KVOForwardingObject
+ (NSSet *)keyPathsForValuesAffectingA
{
    return [NSSet setWithObject:@"b.c"];
}
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if ([key isEqualToString:@"b"])
    {
        return NO;
    }
    return [super automaticallyNotifiesObserversForKey:key];
}
- (NSString *)a
{
    // With Old enabled, KVO invokes this after building forwarding values but
    // before pushing the pending notification. Its result must already be owned.
    NSAutoreleasePool *pool = _willPool;
    _willPool = nil;
    [pool drain];
    return [_b c];
}
- (void)setB:(KVOForwardingChild *)value
{
    _willPool = [NSAutoreleasePool new];
    [self willChangeValueForKey:@"b"];
    [_willPool drain];
    _willPool = nil;
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    [value retain];
    [_b release];
    _b = value;
    [pool drain];
    pool = [NSAutoreleasePool new];
    [self didChangeValueForKey:@"b"];
    [pool drain];
}
- (void)dealloc
{
    [_b release];
    [super dealloc];
}
@end

static char observerContext;

@interface KVOForwardingObserver : NSObject
@property (nonatomic, assign) NSUInteger notifications;
@property (nonatomic, copy) NSString *lastValue;
@property (nonatomic, copy) NSString *observedKeyPath;
@end

@implementation KVOForwardingObserver
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != &observerContext || ![keyPath isEqualToString:self.observedKeyPath])
    {
        [NSException raise:NSInternalInconsistencyException format:@"Unexpected observation"];
    }
    self.notifications++;
    self.lastValue = [object valueForKeyPath:keyPath];
}
- (void)dealloc
{
    [_lastValue release];
    [_observedKeyPath release];
    [super dealloc];
}
@end

static void checkObservation(KVOForwardingObserver *observer, NSUInteger count, NSString *value)
{
    if (observer.notifications != count ||
        !(observer.lastValue == value || [observer.lastValue isEqualToString:value]))
    {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Expected %lu notifications and %@, got %lu and %@",
                           (unsigned long)count, value,
                           (unsigned long)observer.notifications, observer.lastValue];
    }
}

static void runCase(BOOL initiallyNil, BOOL nested, BOOL oldOption)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSUInteger deathsBefore = childDeaths;
    fprintf(stderr, "CASE: initial=%s path=%s old=%d\n", initiallyNil ? "nil" : "object",
            nested ? "b.c" : "a", oldOption);
    KVOForwardingObject *object = [KVOForwardingObject new];
    KVOForwardingObserver *observer = [KVOForwardingObserver new];
    observer.observedKeyPath = nested ? @"b.c" : @"a";
    KVOForwardingChild *oldChild = [KVOForwardingChild new];
    KVOForwardingChild *newChild = [KVOForwardingChild new];
    oldChild.c = @"old";
    newChild.c = @"new";
    if (!initiallyNil)
    {
        object.b = oldChild;
    }
    [object addObserver:observer forKeyPath:observer.observedKeyPath
                options:oldOption ? NSKeyValueObservingOptionOld : 0 context:&observerContext];

    // The first will/did pair saves either NSNull or the old child for b.c.
    object.b = newChild;
    checkObservation(observer, 1, @"new");
    oldChild.c = @"detached";
    checkObservation(observer, 1, @"new");
    newChild.c = @"changed";
    checkObservation(observer, 2, @"changed");

    object.b = nil;
    checkObservation(observer, 3, nil);
    newChild.c = @"also detached";
    checkObservation(observer, 3, nil);

    // Leave the relationship as the child's only owner before will/did releases it.
    KVOForwardingChild *ownedChild = [KVOForwardingChild new];
    ownedChild.c = @"owned";
    object.b = ownedChild;
    [ownedChild release];
    checkObservation(observer, 4, @"owned");
    object.b = nil;
    checkObservation(observer, 5, nil);

    [object removeObserver:observer forKeyPath:observer.observedKeyPath];
    [newChild release];
    [oldChild release];
    [observer release];
    [object release];
    [pool drain];
    if (childDeaths != deathsBefore + 3)
    {
        [NSException raise:NSInternalInconsistencyException format:@"Forwarding leaked a child"];
    }
}

int main(int argc, const char **argv)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int result = 0;
    @try
    {
        if (argc == 1 || (argc == 2 && strcmp(argv[1], "nil") == 0))
        {
            for (NSUInteger iteration = 0; iteration < 32; iteration++)
            {
                runCase(YES, NO, NO);
                runCase(YES, NO, YES);
                runCase(YES, YES, NO);
                runCase(YES, YES, YES);
            }
            puts("PASS: dependent b.c forwarding with initially nil b");
        }
        if (argc == 1 || (argc == 2 && strcmp(argv[1], "object") == 0))
        {
            for (NSUInteger iteration = 0; iteration < 32; iteration++)
            {
                runCase(NO, NO, NO);
                runCase(NO, NO, YES);
                runCase(NO, YES, NO);
                runCase(NO, YES, YES);
            }
            puts("PASS: dependent b.c forwarding with initially non-nil b");
        }
        if (argc > 2 || (argc == 2 && strcmp(argv[1], "nil") != 0 && strcmp(argv[1], "object") != 0))
        {
            fprintf(stderr, "usage: %s [nil|object]\n", argv[0]);
            result = 2;
        }
    }
    @catch (NSException *exception)
    {
        fprintf(stderr, "FAIL: %s: %s\n", [[exception name] UTF8String], [[exception reason] UTF8String]);
        result = 1;
    }
    [pool drain];
    return result;
}
