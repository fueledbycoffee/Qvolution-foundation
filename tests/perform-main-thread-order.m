// Differential check (qv-diff): queued performs on the main thread (NSObject
// performSelectorOnMainThread:withObject:waitUntilDone:[modes:]). One fact per line, deterministic.
//   qv-diff <lane> perform-main-thread-order.m -fno-objc-arc
#import <Foundation/Foundation.h>

static NSMutableArray *seen;
static int calls;

@interface QVPerformer : NSObject
@end

@implementation QVPerformer
- (void) record: (NSNumber *) value {
    [seen addObject: value];
}
- (void) count: (id) unused {
    calls++;
}
- (void) queueFromBackground: (NSNumber *) total {
    @autoreleasepool {
        for (int i = 0; i < [total intValue]; i++)
            [self performSelectorOnMainThread: @selector(record:) withObject: @(i) waitUntilDone: NO];
    }
}
- (void) waitFromBackground: (id) unused {
    @autoreleasepool {
        [self performSelectorOnMainThread: @selector(count:) withObject: nil waitUntilDone: YES];
        // Performed before the call returned: calls is already 1 here.
        [self performSelectorOnMainThread: @selector(record:) withObject: @(calls) waitUntilDone: NO];
    }
}
@end

static void spin(double seconds) {
    [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow: seconds];
    while ([until timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: until];
}

static NSString *orderSummary(int total) {
    if ((int)[seen count] != total)
        return [NSString stringWithFormat: @"count=%lu", (unsigned long)[seen count]];
    int outOfPlace = 0;
    for (int i = 0; i < total; i++)
        if ([seen[i] intValue] != i) outOfPlace++;
    return outOfPlace == 0 ? @"in order" : @"out of order";
}

int main(void) {
    @autoreleasepool {
        QVPerformer *performer = [QVPerformer new];
        seen = [NSMutableArray new];

        // 200 queued performs from one background thread, then run the main run loop.
        [NSThread detachNewThreadSelector: @selector(queueFromBackground:) toTarget: performer withObject: @200];
        spin(1.5);
        printf("NSObject.performSelectorOnMainThread(200 from one thread): %s\n", [orderSummary(200) UTF8String]);

        // Same from the main thread itself (waitUntilDone:NO queues).
        [seen removeAllObjects];
        for (int i = 0; i < 200; i++)
            [performer performSelectorOnMainThread: @selector(record:) withObject: @(i) waitUntilDone: NO];
        printf("NSObject.performSelectorOnMainThread(main,wait:NO).beforeRunLoop: %lu\n", (unsigned long)[seen count]);
        spin(0.5);
        printf("NSObject.performSelectorOnMainThread(200 from main): %s\n", [orderSummary(200) UTF8String]);

        // From the main thread with waitUntilDone:YES: performed immediately.
        calls = 0;
        [performer performSelectorOnMainThread: @selector(count:) withObject: nil waitUntilDone: YES];
        printf("NSObject.performSelectorOnMainThread(main,wait:YES).immediate: %d\n", calls);

        // Two modes in one call: performed once.
        calls = 0;
        [performer performSelectorOnMainThread: @selector(count:) withObject: nil waitUntilDone: NO
                                         modes: @[NSDefaultRunLoopMode, @"QVOtherMode"]];
        spin(0.3);
        printf("NSObject.performSelectorOnMainThread(modes:[default,other]).calls: %d\n", calls);

        // A mode the run loop is not running: not performed until that mode runs.
        calls = 0;
        [performer performSelectorOnMainThread: @selector(count:) withObject: nil waitUntilDone: NO
                                         modes: @[@"QVOtherMode"]];
        spin(0.3);
        printf("NSObject.performSelectorOnMainThread(modes:[other]).inDefault: %d\n", calls);
        [[NSRunLoop currentRunLoop] runMode: @"QVOtherMode" beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.3]];
        printf("NSObject.performSelectorOnMainThread(modes:[other]).afterOther: %d\n", calls);

        // Empty mode list: returns without performing.
        calls = 0;
        [performer performSelectorOnMainThread: @selector(count:) withObject: nil waitUntilDone: NO modes: @[]];
        spin(0.3);
        printf("NSObject.performSelectorOnMainThread(modes:[]).calls: %d\n", calls);

        // waitUntilDone:YES from a background thread returns after the main thread performed it.
        calls = 0;
        [seen removeAllObjects];
        [NSThread detachNewThreadSelector: @selector(waitFromBackground:) toTarget: performer withObject: nil];
        spin(1.0);
        printf("NSObject.performSelectorOnMainThread(background,wait:YES).performedBeforeReturn: %d\n",
               [seen count] == 1 ? [seen[0] intValue] : -1);

        // Performs queued in the order: wait:NO then wait:YES from the same thread stay ordered.
        [seen removeAllObjects];
        calls = 0;
        printf("done\n");
    }
    return 0;
}
