//
//  NSNotificationCenter.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSNotification.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSIndexSet.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>
#import <Foundation/NSOperation.h>
#import "NSNotificationInternal.h"
#import <dispatch/dispatch.h>
#import <pthread.h>

extern id objc_initWeakOrNil(id *location, id value);
extern id objc_loadWeakRetained(id *location);
extern void objc_destroyWeak(id *location);

@interface _NSNotificationObserver : NSObject
{
	// Selector registrations do not keep the observer alive (Apple, NotificationCenter
	// addObserver(_:selector:name:object:): since macOS 10.11 an observer that is never
	// removed is cleaned up the next time the center would have posted to it). _weakObserver
	// is a zeroing weak reference; _observer is only an identity for removal and is never
	// messaged unless the observer's class cannot be weakly referenced (_weakCapable NO).
	id _observer;
	id _weakObserver;
	BOOL _weakCapable;
	BOOL _active;
	SEL _selector;
	NSString* _name;
	id _object;
	NSOperationQueue* _queue;
	void (^_block)(NSNotification *note);
}

@property (nonatomic, readonly) id observer;
@property (nonatomic, readonly) SEL selector;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) id object;
@property (nonatomic, readonly) NSOperationQueue *queue;
@property (nonatomic, readonly) void (^block)(NSNotification *note);

- (id)initWithObserver:(id)observer selector:(SEL)selector name:(NSString *)name object:(id)object queue:(NSOperationQueue *)queue block:(void (^)(NSNotification *note))block;
@end

@implementation _NSNotificationObserver

@synthesize observer = _observer;
@synthesize selector = _selector;
@synthesize name = _name;
@synthesize object = _object;
@synthesize queue = _queue;
@synthesize block = _block;

- (id)initWithObserver:(id)observer selector:(SEL)selector name:(NSString *)name object:(id)object queue:(NSOperationQueue *)queue block:(void (^)(NSNotification *note))block
{
    self = [super init];
    if (self)
    {
        _active = YES;
        _observer = observer;
        _weakCapable = observer == nil || objc_initWeakOrNil(&_weakObserver, observer) != nil;
        _selector = selector;
        _name = [name copy];
        _object = object;
        _queue = [queue retain];
        _block = Block_copy(block);
    }
    return self;
}

- (void)dealloc
{
    objc_destroyWeak(&_weakObserver);
    [_name release];
    [_queue release];
    [_block release];
    [super dealloc];
}

// The observer to message, retained; nil once a weakly referenced observer is gone.
- (id)retainedTarget
{
    if (_block != NULL || _selector == NULL || _observer == nil)
        return nil;
    if (_weakCapable)
        return objc_loadWeakRetained(&_weakObserver);
    return [_observer retain];
}

- (BOOL)isStale
{
    if (_block != NULL || !_weakCapable || _observer == nil)
        return NO;
    id target = objc_loadWeakRetained(&_weakObserver);
    [target release];
    return target == nil;
}

- (void)invalidate
{
    __atomic_store_n(&_active, NO, __ATOMIC_RELEASE);
}

- (void)postNotification:(NSNotification *)notif target:(id)target
{
    if (!__atomic_load_n(&_active, __ATOMIC_ACQUIRE))
        return;
    if (_queue != nil && _block != NULL)
    {
        // Deliver the posted notification itself. NSNotification objects are immutable
        // (Apple, NSNotification), so the block may keep it or hand it to another thread;
        // it stays alive until the operation has run.
        NSNotification *delivered = [notif retain];
        [_queue addOperationWithBlock:^{
            _block(delivered);
            [delivered release];
        }];
    }
    else if (_block != NULL)
    {
        _block(notif);
    }
    else if (target != nil)
    {
        [target performSelector:_selector withObject:notif];
    }
}

@end

@implementation NSNotificationCenter

+ (NSNotificationCenter *)defaultCenter
{
    static NSNotificationCenter *defaultCenter = nil;
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        defaultCenter = [[NSNotificationCenter alloc] init];
    });
    return defaultCenter;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        pthread_mutexattr_t attrs;
        pthread_mutexattr_init(&attrs);
        pthread_mutexattr_settype(&attrs, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_observersLock, &attrs);
        pthread_mutexattr_destroy(&attrs);

        _observers = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_observers release];
    [super dealloc];
}

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName object:(id)anObject
{
    _NSNotificationObserver *notifObserver = [[_NSNotificationObserver alloc] initWithObserver:observer selector:aSelector name:aName object:anObject queue:nil block:NULL];
    pthread_mutex_lock(&_observersLock);
    [_observers addObject:notifObserver];
    pthread_mutex_unlock(&_observersLock);
    [notifObserver release];
}

- (void)postNotification:(NSNotification *)notification
{
    NSString *name = [notification name];
    id object = [notification object];
    
    // Matching registrations and their observers are taken under the lock and kept alive
    // until delivery ends, so an observer released by an earlier observer's handler during
    // this post still receives it (observed on macOS 12.7.6). Entries whose observer is
    // gone are removed instead.
    NSMutableArray *observers = [[NSMutableArray alloc] init];
    NSMutableArray *targets = [[NSMutableArray alloc] init];
    pthread_mutex_lock(&_observersLock);
    NSMutableIndexSet *stale = nil;
    NSUInteger index = 0;
    for (_NSNotificationObserver *observer in _observers)
    {
        if ((name == nil || observer.name == nil || [observer.name isEqualToString:name]) &&
            (object == nil || observer.object == nil || object == observer.object))
        {
            id target = [observer retainedTarget];
            if (target == nil && [observer isStale])
            {
                if (stale == nil)
                    stale = [NSMutableIndexSet indexSet];
                [stale addIndex:index];
            }
            else
            {
                [observers addObject:observer];
                [targets addObject:target != nil ? target : (id)[NSNull null]];
            }
            [target release];
        }
        index++;
    }
    if (stale != nil)
        [_observers removeObjectsAtIndexes:stale];
    pthread_mutex_unlock(&_observersLock);

    NSUInteger count = [observers count];
    for (NSUInteger i = 0; i < count; i++)
    {
        id target = [targets objectAtIndex:i];
        [[observers objectAtIndex:i] postNotification:notification target:target == [NSNull null] ? nil : target];
    }
    [targets release];
    [observers release];
}

- (void)postNotificationName:(NSString *)aName object:(id)anObject
{
    [self postNotificationName:aName object:anObject userInfo:nil];
}

- (void)postNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    // A fresh notification per post: observers may retain it (for example to forward it
    // with performSelectorOnMainThread:withObject:waitUntilDone:NO), and NSNotification
    // objects are immutable, so it must not be cleared or reused after posting.
    NSNotification *notif = [[NSConcreteNotification alloc] initWithName:aName object:anObject userInfo:aUserInfo];
    [self postNotification:notif];
    [notif release];
}

- (void)removeObserver:(id)observer
{
    pthread_mutex_lock(&_observersLock);
    NSIndexSet *indicies = [_observers indexesOfObjectsPassingTest:^BOOL(_NSNotificationObserver *notifObserver, NSUInteger idx, BOOL *stop) {
        // observer may be a user controlled object, or an instance of _NSNotificationObserver if the block version of 
        // addObserverForName was used
        BOOL matches = notifObserver == observer || notifObserver.observer == observer;
        if (matches)
            [notifObserver invalidate];
        return matches;
    }];
    [_observers removeObjectsAtIndexes:indicies];
    pthread_mutex_unlock(&_observersLock);
}

- (void)removeObserver:(id)observer name:(NSString *)aName object:(id)anObject
{
    pthread_mutex_lock(&_observersLock);
    // A nil name or sender is not a removal criterion (Apple, removeObserver(_:name:object:)).
    // The observer is either a selector registration's observer or a block registration's token.
    NSIndexSet *indicies = [_observers indexesOfObjectsPassingTest:^BOOL(_NSNotificationObserver *notifObserver, NSUInteger idx, BOOL *stop) {
        BOOL matchesObserver = observer != nil && (notifObserver == observer || notifObserver.observer == observer);
        BOOL matchesName = aName == nil || [notifObserver.name isEqualToString:aName];
        BOOL matchesObject = anObject == nil || notifObserver.object == anObject;
        BOOL matches = matchesObserver && matchesName && matchesObject;
        if (matches)
            [notifObserver invalidate];
        return matches;
    }];
    [_observers removeObjectsAtIndexes:indicies];
    pthread_mutex_unlock(&_observersLock);
}

- (id)addObserverForName:(NSString *)name object:(id)obj queue:(NSOperationQueue *)queue usingBlock:(void (^)(NSNotification *note))block
{
    _NSNotificationObserver *notifObserver = [[_NSNotificationObserver alloc] initWithObserver:nil selector:NULL name:name object:obj queue:queue block:block];
    pthread_mutex_lock(&_observersLock);
    [_observers addObject:notifObserver];
    pthread_mutex_unlock(&_observersLock);
    [notifObserver release];
    return notifObserver;
}

@end
