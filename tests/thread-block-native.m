/* Production block target and thread methods run unchanged with only the base
 * object storage and pthread start machinery doubled. Full run-loop delivery is
 * covered separately by thread_selectors in qv-diff-batch. */
#include <objc/runtime.h>
#include <objc/message.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <Block.h>

static int copies, releases, liveObjects, workers;
static pthread_mutex_t workerLock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t workerCondition = PTHREAD_COND_INITIALIZER;
static void *copyBlock(const void *block) {
    __atomic_add_fetch(&copies, 1, __ATOMIC_SEQ_CST);
    return _Block_copy(block);
}
static void releaseBlock(const void *block) {
    __atomic_add_fetch(&releases, 1, __ATOMIC_SEQ_CST);
    _Block_release(block);
}
#undef Block_copy
#undef Block_release
#define Block_copy(b) ((__typeof__(b))copyBlock(b))
#define Block_release(b) releaseBlock(b)
#define CF_PRIVATE

__attribute__((objc_root_class))
@interface NSObject { Class isa; int refs; }
+ (id)alloc;
+ (Class)class;
- (id)init;
- (id)retain;
- (void)release;
- (void)dealloc;
@end
@implementation NSObject
+ (Class)class { return self; }
+ (id)alloc {
    NSObject *object = class_createInstance(self, 0);
    object->refs = 1;
    __atomic_add_fetch(&liveObjects, 1, __ATOMIC_SEQ_CST);
    return object;
}
- (id)init { return self; }
- (id)retain { __atomic_add_fetch(&refs, 1, __ATOMIC_SEQ_CST); return self; }
- (void)release { if (__atomic_sub_fetch(&refs, 1, __ATOMIC_SEQ_CST) == 0) [self dealloc]; }
- (void)dealloc {
    __atomic_sub_fetch(&liveObjects, 1, __ATOMIC_SEQ_CST);
    object_dispose(self);
}
@end

@interface NSThread : NSObject {
@public
    id _target; SEL _selector; id _argument; pthread_t _thread;
}
- (id)initWithTarget:(id)target selector:(SEL)selector object:(id)argument;
- (id)initWithBlock:(void (^)(void))block;
+ (void)detachNewThreadWithBlock:(void (^)(void))block;
- (void)start;
- (void)main;
@end

static void nativeSend(id target, SEL selector, id argument) {
    ((void (*)(id, SEL, id))objc_msg_lookup(target, selector))(target, selector, argument);
}
#define objc_msgSend nativeSend
#include "thread-block-target.inc"

static void *entry(void *context) {
    NSThread *thread = context;
    [thread main];
    [thread release];
    pthread_mutex_lock(&workerLock);
    --workers;
    pthread_cond_signal(&workerCondition);
    pthread_mutex_unlock(&workerLock);
    return NULL;
}
@implementation NSThread
#include "thread-block-methods.inc"
- (void)start {
    pthread_mutex_lock(&workerLock);
    ++workers;
    pthread_mutex_unlock(&workerLock);
    [self retain];
    if (pthread_create(&_thread, NULL, entry, self)) abort();
    pthread_detach(_thread);
}
- (void)dealloc { [_target release]; [_argument release]; [super dealloc]; }
@end

static void waitForWorkers(void) {
    pthread_mutex_lock(&workerLock);
    while (workers) pthread_cond_wait(&workerCondition, &workerLock);
    pthread_mutex_unlock(&workerLock);
}
static int failures;
#define EXPECT(b, label) do { BOOL ok = (b); printf("%s %s\n", ok ? "PASS" : "FAIL", label); failures += !ok; } while (0)
static NSThread *stackThread(int *result, pthread_t *callbackThread) {
    int captured = 73;
    return [[NSThread alloc] initWithBlock:^{ *result = captured; *callbackThread = pthread_self(); }];
}
int main(void) {
    if (!class_getInstanceMethod([NSThread class], @selector(initWithBlock:)) ||
        !class_getClassMethod(objc_getClass("NSThread"), @selector(detachNewThreadWithBlock:))) {
        puts("FAIL missing block thread API"); return 1;
    }
    int value = 0; pthread_t callbackThread;
    NSThread *thread = stackThread(&value, &callbackThread);
    EXPECT(value == 0, "initialization defers block execution");
    EXPECT(copies == 1, "initialization copies the stack block");
    [thread start]; waitForWorkers();
    EXPECT(value == 73, "copied stack capture survives its creating frame");
    EXPECT(pthread_equal(callbackThread, thread->_thread) && !pthread_equal(callbackThread, pthread_self()),
           "block executes on the target pthread");
    EXPECT(releases == 0, "thread owns its block until deallocation");
    [thread release];
    EXPECT(releases == 1 && liveObjects == 0, "thread deallocation releases block and private target");
    thread = stackThread(&value, &callbackThread); [thread release];
    EXPECT(copies == 2 && releases == 2 && liveObjects == 0, "unstarted thread releases its copied block");
    __block int detached = 0; int capture = 91;
    [NSThread detachNewThreadWithBlock:^{ detached = capture; }];
    waitForWorkers();
    EXPECT(detached == 91 && liveObjects == 0, "detached block runs and relinquishes ownership");
    EXPECT(copies == 3 && releases == 3, "all block copies have matching releases");
    printf("RESULT failures=%d\n", failures);
    return failures != 0;
}
