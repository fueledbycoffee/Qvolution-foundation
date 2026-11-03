// Differential check (qv-diff): NSNotificationCenter observer lifetime and removal criteria.
// Build without ARC: qv-diff <lane> notification-observer-lifetime.m -fno-objc-arc
// Each case that could message a deallocated observer runs in a forked child, so a crash is reported
// as a line instead of ending the program. One fact per line, deterministic.
#import <Foundation/Foundation.h>
#include <sys/wait.h>
#include <unistd.h>

static int delivered;

@interface QVObserver : NSObject
@property (nonatomic, assign) QVObserver *releaseOnNote;
@end

@implementation QVObserver
- (void) note: (NSNotification *) note {
    delivered++;
    if (_releaseOnNote != nil) {
        QVObserver *victim = _releaseOnNote;
        _releaseOnNote = nil;
        [victim release];
    }
}
@end

static NSString *const A = @"QVLifetimeA";
static NSString *const B = @"QVLifetimeB";

// Runs body in a child; prints "delivered=N" from the child's exit status, or the signal.
static void forked(const char *name, int (^body)(void)) {
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        @autoreleasepool {
            _exit(body());
        }
    }
    int status = 0;
    waitpid(pid, &status, 0);
    if (WIFEXITED(status))
        printf("NSNotificationCenter.%s: delivered=%d\n", name, WEXITSTATUS(status));
    else if (WIFSIGNALED(status))
        printf("NSNotificationCenter.%s: signal=%d\n", name, WTERMSIG(status));
    else
        printf("NSNotificationCenter.%s: status=other\n", name);
}

int main(void) {
    @autoreleasepool {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

        // Control: a live observer receives the notification.
        forked("post(liveObserver)", ^{
            QVObserver *observer = [QVObserver new];
            [center addObserver: observer selector: @selector(note:) name: A object: nil];
            [center postNotificationName: A object: nil];
            return delivered;
        });

        // The observer is deallocated without unregistering, then the name is posted.
        forked("post(afterObserverDealloc)", ^{
            QVObserver *observer = [QVObserver new];
            [center addObserver: observer selector: @selector(note:) name: A object: nil];
            [observer release];
            // Reuse the freed memory with a live object of the same class that is not registered.
            QVObserver *other = [QVObserver new];
            [center postNotificationName: A object: nil];
            [other release];
            return delivered;
        });

        // A sender-specific registration whose observer is gone; another sender posts the same name later.
        forked("post(afterObserverDeallocWithSender)", ^{
            id sender = [NSObject new];
            QVObserver *observer = [QVObserver new];
            [center addObserver: observer selector: @selector(note:) name: A object: sender];
            [observer release];
            QVObserver *other = [QVObserver new];
            [center postNotificationName: A object: sender];
            [other release];
            return delivered;
        });

        // An earlier observer releases a later one while the same notification is being posted.
        forked("post(laterObserverReleasedDuringPost)", ^{
            QVObserver *first = [QVObserver new];
            QVObserver *second = [QVObserver new];
            first.releaseOnNote = second;
            [center addObserver: first selector: @selector(note:) name: A object: nil];
            [center addObserver: second selector: @selector(note:) name: A object: nil];
            [center postNotificationName: A object: nil];
            return delivered;
        });

        // removeObserver:name:object: with a nil name removes the observer's entries for every name.
        forked("removeObserver(name:nil,object:nil)", ^{
            QVObserver *observer = [QVObserver new];
            [center addObserver: observer selector: @selector(note:) name: A object: nil];
            [center addObserver: observer selector: @selector(note:) name: B object: nil];
            [center removeObserver: observer name: nil object: nil];
            [center postNotificationName: A object: nil];
            [center postNotificationName: B object: nil];
            return delivered;
        });

        // A nil name with a sender removes only the entries for that sender.
        forked("removeObserver(name:nil,object:sender)", ^{
            id sender = [NSObject new], otherSender = [NSObject new];
            QVObserver *observer = [QVObserver new];
            [center addObserver: observer selector: @selector(note:) name: A object: sender];
            [center addObserver: observer selector: @selector(note:) name: B object: otherSender];
            [center removeObserver: observer name: nil object: sender];
            [center postNotificationName: A object: sender];
            [center postNotificationName: B object: otherSender];
            return delivered;
        });

        // A name with a nil sender removes the entries for that name from every sender.
        forked("removeObserver(name:A,object:nil)", ^{
            id sender = [NSObject new];
            QVObserver *observer = [QVObserver new];
            [center addObserver: observer selector: @selector(note:) name: A object: sender];
            [center addObserver: observer selector: @selector(note:) name: B object: sender];
            [center removeObserver: observer name: A object: nil];
            [center postNotificationName: A object: sender];
            [center postNotificationName: B object: sender];
            return delivered;
        });

        // A nil observer to removeObserver:name:object: removes nothing that names another observer.
        forked("removeObserver(nil,name:A,object:nil)", ^{
            QVObserver *observer = [QVObserver new];
            [center addObserver: observer selector: @selector(note:) name: A object: nil];
            [center removeObserver: nil name: A object: nil];
            [center postNotificationName: A object: nil];
            return delivered;
        });

        // A block registration's token removed with removeObserver:name:object:.
        forked("removeObserver(token,name:A,object:nil)", ^{
            __block int calls = 0;
            id token = [center addObserverForName: A object: nil queue: nil usingBlock: ^(NSNotification *n) { calls++; }];
            [center removeObserver: token name: A object: nil];
            [center postNotificationName: A object: nil];
            return calls;
        });

        // The same observer registered twice for the same name receives the notification twice.
        forked("post(registeredTwice)", ^{
            QVObserver *observer = [QVObserver new];
            [center addObserver: observer selector: @selector(note:) name: A object: nil];
            [center addObserver: observer selector: @selector(note:) name: A object: nil];
            [center postNotificationName: A object: nil];
            return delivered;
        });
    }
    return 0;
}
