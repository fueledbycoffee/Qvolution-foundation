// Differential check (qv-diff): an NSPortMessage sent from a background thread to an NSMachPort scheduled on
// the main run loop wakes the main thread promptly, both in -[NSRunLoop runMode:beforeDate:] and while
// AppKit waits in -[NSApplication nextEventMatchingMask:untilDate:inMode:dequeue:]. Latency is bucketed.
//   qv-diff <lane> machport-wakeup.m -fno-objc-arc -framework AppKit
#import <AppKit/AppKit.h>

static double sentAt, handledAt;
static int handled;

static double now(void) { return [NSDate timeIntervalSinceReferenceDate]; }

@interface QVPortReceiver : NSObject <NSMachPortDelegate>
@property (retain) NSPort *port;
@end

@implementation QVPortReceiver
- (void) handlePortMessage: (NSPortMessage *) message {
    handled++;
    handledAt = now();
}
- (void) sendLater: (NSNumber *) delay {
    @autoreleasepool {
        usleep((useconds_t)([delay doubleValue] * 1e6));
        NSPortMessage *message = [[NSPortMessage alloc] initWithSendPort: self.port receivePort: nil components: @[]];
        [message setMsgid: 7];
        sentAt = now();
        [message sendBeforeDate: [NSDate distantFuture]];
        [message release];
    }
}
@end

static const char *latency(void) {
    if (!handled) return "not delivered";
    double d = handledAt - sentAt;
    return d < 0.1 ? "under 100ms" : d < 0.5 ? "under 500ms" : "over 500ms";
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy: NSApplicationActivationPolicyAccessory];
        QVPortReceiver *receiver = [QVPortReceiver new];
        receiver.port = [NSMachPort port];
        [receiver.port setDelegate: receiver];
        [[NSRunLoop currentRunLoop] addPort: receiver.port forMode: NSDefaultRunLoopMode];

        handled = 0;
        [NSThread detachNewThreadSelector: @selector(sendLater:) toTarget: receiver withObject: @0.3];
        [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 3]];
        printf("NSMachPort.runMode:beforeDate:.wake: %s\n", latency());

        handled = 0;
        [NSThread detachNewThreadSelector: @selector(sendLater:) toTarget: receiver withObject: @0.3];
        NSDate *until = [NSDate dateWithTimeIntervalSinceNow: 3];
        while (!handled && [until timeIntervalSinceNow] > 0) {
            NSEvent *event = [NSApp nextEventMatchingMask: NSAnyEventMask untilDate: until
                                                   inMode: NSDefaultRunLoopMode dequeue: YES];
            if (event) [NSApp sendEvent: event];
        }
        printf("NSMachPort.nextEventMatchingMask.wake: %s\n", latency());

        // Sent in the default mode only: not delivered while the run loop runs another mode.
        handled = 0;
        [NSThread detachNewThreadSelector: @selector(sendLater:) toTarget: receiver withObject: @0.1];
        [[NSRunLoop currentRunLoop] runMode: NSEventTrackingRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.6]];
        printf("NSMachPort.otherMode.delivered: %d\n", handled);
        [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 1]];
        printf("NSMachPort.otherMode.thenDefault.delivered: %d\n", handled);
    }
    return 0;
}
