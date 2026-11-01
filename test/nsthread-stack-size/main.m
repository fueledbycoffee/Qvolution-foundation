// -[NSThread setStackSize:] must size the thread that -start creates. The thread below asks for
// 8 MiB and then uses about 4 MiB of stack, well past the 512 KiB default for secondary threads.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expect(BOOL condition, const char *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", label);
    failures += !condition;
}

static unsigned long useStack(unsigned depth)
{
    volatile char frame[2048];
    frame[0] = (char)depth;
    frame[sizeof(frame) - 1] = (char)depth;
    if (depth == 0)
        return frame[0];
    return useStack(depth - 1) + frame[sizeof(frame) - 1];
}

@interface QVStackUser : NSObject
@property (atomic) BOOL done;
@property (atomic) NSUInteger reportedStackSize;
@end

@implementation QVStackUser
- (void)run:(id)unused
{
    self.reportedStackSize = [[NSThread currentThread] stackSize];
    useStack(2048); // about 4 MiB
    self.done = YES;
}
@end

int main(void)
{
    @autoreleasepool
    {
        QVStackUser *user = [[QVStackUser new] autorelease];
        NSThread *thread = [[[NSThread alloc] initWithTarget:user selector:@selector(run:) object:nil] autorelease];
        [thread setStackSize:8 * 1024 * 1024];
        expect([thread stackSize] == 8 * 1024 * 1024, "stackSize reports the requested size before start");
        [thread start];
        for (int i = 0; i < 500 && !user.done; i++)
            usleep(10000);
        expect(user.done, "thread used 4 MiB of an 8 MiB stack and finished");
        expect(user.reportedStackSize == 8 * 1024 * 1024, "the running thread reports the requested stack size");
    }
    printf("RESULT failures=%d\n", failures);
    return failures != 0;
}
