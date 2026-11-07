//
//  NSNotificationQueue.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSNotificationQueue.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNotification.h>

#import <CoreFoundation/CFRunLoop.h>
#include <limits.h>

static NSString *NSDefaultNotificationQueue = @"NSDefaultNotificationQueue";

@interface NSNotificationQueue (Delivery)
- (void)_postNotifications:(NSPostingStyle)style;
@end

@interface _NSNotificationQueueEntry : NSObject
{
@public
    NSNotification *notification;
    NSArray *modes;
    NSNotificationQueue *owner;
    NSPostingStyle style;
    CFRunLoopObserverRef observer;
}
@end

@implementation _NSNotificationQueueEntry
- (void)dealloc
{
    if (observer != NULL)
    {
        CFRunLoopObserverInvalidate(observer);
        CFRelease(observer);
    }
    [notification release];
    [modes release];
    [super dealloc];
}
@end

static BOOL matchesNotification(NSNotification *notification, NSUInteger mask, _NSNotificationQueueEntry *entry)
{
    return mask != NSNotificationNoCoalescing &&
        (!(mask & NSNotificationCoalescingOnName) || [entry->notification.name isEqualToString:notification.name]) &&
        (!(mask & NSNotificationCoalescingOnSender) || entry->notification.object == notification.object);
}

static BOOL coalesceNotification(NSNotification *notification, NSUInteger mask, NSMutableArray *array, BOOL remove)
{
    BOOL found = NO;
    for (NSUInteger i = [array count]; i > 0; i--)
    {
        _NSNotificationQueueEntry *entry = [array objectAtIndex:i - 1];
        if (matchesNotification(notification, mask, entry))
        {
            found = YES;
            if (remove)
                [array removeObjectAtIndex:i - 1];
        }
    }
    return found;
}

static void modeProbe(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {}

static BOOL currentModeMatches(NSArray *modes, CFStringRef mode)
{
    if (mode == NULL || [modes containsObject:(NSString *)mode])
        return YES;
    if (![modes containsObject:NSRunLoopCommonModes])
        return NO;
    CFRunLoopRef loop = CFRunLoopGetCurrent();
    CFRunLoopObserverRef probe = CFRunLoopObserverCreate(NULL, kCFRunLoopBeforeWaiting, false, 0, modeProbe, NULL);
    CFRunLoopAddObserver(loop, probe, kCFRunLoopCommonModes);
    BOOL matches = CFRunLoopContainsObserver(loop, probe, mode);
    CFRunLoopObserverInvalidate(probe);
    CFRelease(probe);
    return matches;
}

static void postNotifications(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    _NSNotificationQueueEntry *entry = info;
    NSNotificationQueue *queue = [entry->owner retain];
    NSPostingStyle style = entry->style;
    @try
    {
        [queue _postNotifications:style];
    }
    @finally
    {
        [queue release];
    }
}

@implementation NSNotificationQueue

+ (id)defaultQueue
{
    NSMutableDictionary *tls = [[NSThread currentThread] threadDictionary];
    NSNotificationQueue *queue = [tls objectForKey:NSDefaultNotificationQueue];
    if (queue == nil)
    {
        queue = [[NSNotificationQueue alloc] init];
        [tls setObject:queue forKey:NSDefaultNotificationQueue];
        [queue release];
    }
    return queue;
}

- (id)init
{
    return [self initWithNotificationCenter:[NSNotificationCenter defaultCenter]];
}

- (id)initWithNotificationCenter:(NSNotificationCenter *)notificationCenter
{
    self = [super init];
    if (self)
    {
        _notificationCenter = [notificationCenter retain];
        _asapQueue = [[NSMutableArray alloc] init];
        _idleQueue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self _flushNotificationQueue];
    [_notificationCenter release];
    [super dealloc];
}

- (void)enqueueNotification:(NSNotification *)notification postingStyle:(NSPostingStyle)postingStyle
{
    [self enqueueNotification:notification postingStyle:postingStyle coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender forModes:nil];
}

- (void)_postNotifications:(NSPostingStyle)style
{
    NSMutableArray *queue = style == NSPostASAP ? _asapQueue : _idleQueue;
    CFRunLoopRef loop = CFRunLoopGetCurrent();
    CFStringRef mode = CFRunLoopCopyCurrentMode(loop);
    @try
    {
        NSUInteger index = 0;
        while (index < [queue count])
        {
            _NSNotificationQueueEntry *entry = [queue objectAtIndex:index];
            BOOL eligible = [entry->modes containsObject:(NSString *)mode] ||
                ([entry->modes containsObject:NSRunLoopCommonModes] &&
                 CFRunLoopContainsObserver(loop, entry->observer, mode));
            if (!eligible)
            {
                index++;
                continue;
            }
            NSNotification *notification = [entry->notification retain];
            // Remove before calling out so nested loops cannot deliver this entry twice.
            [queue removeObjectAtIndex:index];
            @try
            {
                [_notificationCenter postNotification:notification];
            }
            @finally
            {
                [notification release];
            }
            index = 0;
        }
    }
    @finally
    {
        if (mode != NULL)
            CFRelease(mode);
    }
}

- (void)enqueueNotification:(NSNotification *)notification postingStyle:(NSPostingStyle)postingStyle coalesceMask:(NSUInteger)coalesceMask forModes:(NSArray *)modes
{
    if (modes == nil)
        modes = @[NSDefaultRunLoopMode];

    switch (postingStyle)
    {
        case NSPostWhenIdle:
            if (coalesceNotification(notification, coalesceMask, _asapQueue, NO) ||
                coalesceNotification(notification, coalesceMask, _idleQueue, NO))
                return;
            break;
        case NSPostASAP:
            coalesceNotification(notification, coalesceMask, _idleQueue, YES);
            if (coalesceNotification(notification, coalesceMask, _asapQueue, NO))
                return;
            break;
        case NSPostNow:
            coalesceNotification(notification, coalesceMask, _asapQueue, YES);
            coalesceNotification(notification, coalesceMask, _idleQueue, YES);
            CFStringRef mode = CFRunLoopCopyCurrentMode(CFRunLoopGetCurrent());
            @try
            {
                if (currentModeMatches(modes, mode))
                    [_notificationCenter postNotification:notification];
            }
            @finally
            {
                if (mode != NULL)
                    CFRelease(mode);
            }
            return;
    }

    _NSNotificationQueueEntry *entry = [[_NSNotificationQueueEntry alloc] init];
    entry->notification = [notification retain];
    entry->modes = [modes copy];
    entry->owner = self;
    entry->style = postingStyle;
    CFRunLoopObserverContext context = {0};
    context.info = entry;
    CFOptionFlags activities = postingStyle == NSPostASAP ?
        kCFRunLoopBeforeWaiting | kCFRunLoopExit : kCFRunLoopBeforeWaiting;
    entry->observer = CFRunLoopObserverCreate(kCFAllocatorDefault, activities, true,
        postingStyle == NSPostASAP ? 0 : LONG_MAX, postNotifications, &context);
    NSMutableArray *queue = postingStyle == NSPostASAP ? _asapQueue : _idleQueue;
    [queue addObject:entry];
    for (NSString *mode in modes)
        CFRunLoopAddObserver(CFRunLoopGetCurrent(), entry->observer, (CFStringRef)mode);
    [entry release];
}

- (void)dequeueNotificationsMatching:(NSNotification *)notification coalesceMask:(NSUInteger)coalesceMask
{
    coalesceNotification(notification, coalesceMask, _asapQueue, YES);
    coalesceNotification(notification, coalesceMask, _idleQueue, YES);
}

- (void)_flushNotificationQueue
{
    [_asapQueue release];
    [_idleQueue release];
    _asapQueue = nil;
    _idleQueue = nil;
}

@end
