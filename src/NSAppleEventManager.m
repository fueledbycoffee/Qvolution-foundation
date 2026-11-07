#import <Foundation/NSAppleEventManager.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>
#include <stdlib.h>

static NSAppleEventManager* instance = nil;

@implementation NSAppleEventManager

+ (NSAppleEventManager *)sharedAppleEventManager
{
    @synchronized(self)
    {
        if (instance == nil)
            instance = [[NSAppleEventManager alloc] init];
    }
    return instance;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "@@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

// No Apple event is ever being handled in Darling, so there is no current, reply or suspended event.
- (NSAppleEventDescriptor *)currentAppleEvent
{
    return nil;
}

- (NSAppleEventDescriptor *)currentReplyAppleEvent
{
    return nil;
}

- (NSAppleEventManagerSuspensionID)suspendCurrentAppleEvent
{
    return NULL;
}

- (NSAppleEventDescriptor *)appleEventForSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID
{
    return nil;
}

- (NSAppleEventDescriptor *)replyAppleEventForSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID
{
    return nil;
}

- (void)setCurrentAppleEventAndReplyEventWithSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID
{
}

- (void)resumeWithSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID
{
}

- (void)removeEventHandlerForEventClass:(AEEventClass)eventClass andEventID:(AEEventID)eventID
{
}

- (void) setEventHandler: (id) handler
             andSelector: (SEL) selector
           forEventClass: (AEEventClass) eventClass
              andEventID: (AEEventID) eventID
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
}

@end
