// Differential check (qv-diff): where and when NSUserDefaults change notifications and
// NSUserDefaultsController KVO arrive when the main thread sets values. One fact per line.
//   qv-diff <lane> defaults-change-thread.m -fno-objc-arc -framework AppKit
#import <AppKit/AppKit.h>

static int notesSync, notesOnMain, notesOffMain, kvoSync, kvoOnMain, kvoOffMain;
static BOOL inSet;

@interface QVWatch : NSObject
@end
@implementation QVWatch
- (void) changed: (NSNotification *) n {
    if (inSet) notesSync++;
    if ([NSThread isMainThread]) notesOnMain++; else notesOffMain++;
}
- (void) observeValueForKeyPath: (NSString *) k ofObject: (id) o change: (NSDictionary *) c context: (void *) ctx {
    if (inSet) kvoSync++;
    if ([NSThread isMainThread]) kvoOnMain++; else kvoOffMain++;
}
@end

static void spin(double s) {
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow: s];
    while ([until timeIntervalSinceNow] > 0) [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: until];
}

static void reset(void) { notesSync = notesOnMain = notesOffMain = kvoSync = kvoOnMain = kvoOffMain = 0; }

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d removeObjectForKey: @"QVLiveA"]; [d removeObjectForKey: @"QVLiveB"];
        QVWatch *w = [QVWatch new];
        [[NSNotificationCenter defaultCenter] addObserver: w selector: @selector(changed:) name: NSUserDefaultsDidChangeNotification object: nil];
        NSUserDefaultsController *c = [NSUserDefaultsController sharedUserDefaultsController];
        [c addObserver: w forKeyPath: @"values.QVLiveA" options: 0 context: NULL];
        spin(0.3); reset();

        const char *names[] = {"first set", "second set", "same value again", "other key"};
        for (int i = 0; i < 4; i++) {
            reset();
            inSet = YES;
            if (i == 0) [d setObject: @"one" forKey: @"QVLiveA"];
            if (i == 1) [d setObject: @"two" forKey: @"QVLiveA"];
            if (i == 2) [d setObject: @"two" forKey: @"QVLiveA"];
            if (i == 3) [d setObject: @1 forKey: @"QVLiveB"];
            inSet = NO;
            spin(0.5);
            printf("NSUserDefaults.setObject(%s).didChangeNotification: sync>0=%d onMain>0=%d offMain>0=%d\n",
                   names[i], notesSync > 0, notesOnMain > 0, notesOffMain > 0);
            printf("NSUserDefaultsController.values.QVLiveA KVO(%s): sync>0=%d onMain>0=%d offMain>0=%d\n",
                   names[i], kvoSync > 0, kvoOnMain > 0, kvoOffMain > 0);
        }
        [c removeObserver: w forKeyPath: @"values.QVLiveA"];
        [d removeObjectForKey: @"QVLiveA"]; [d removeObjectForKey: @"QVLiveB"];
    }
    return 0;
}
