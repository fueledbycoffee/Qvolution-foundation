//
//  NSThread.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSThread.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSString.h>
#import <CoreFoundation/CFRunLoop.h>
#import <CoreFoundation/CFNumber.h>
#import <pthread.h>
#import <unistd.h>
#import <objc/message.h>
#import <execinfo.h>

CFRunLoopRef _CFRunLoopGet0(pthread_t t);
CFTypeRef _CFRunLoopGet2(CFRunLoopRef rl);

NSString *const NSWillBecomeMultiThreadedNotification = @"NSWillBecomeMultiThreadedNotification";
NSString *const NSDidBecomeSingleThreadedNotification = @"NSDidBecomeSingleThreadedNotification";
NSString *const NSThreadWillExitNotification = @"NSThreadWillExitNotification";

static pthread_key_t NSThreadKey;

static NSThread *NSMainThread = nil;
static BOOL _NSIsMultiThreaded = NO;

static void NSThreadEnd(void *context);

static void NSThreadInitialize() __attribute__((constructor));
static void NSThreadInitialize()
{
    pthread_key_create(&NSThreadKey, &NSThreadEnd);
    NSMainThread = [NSThread currentThread];
}

CF_PRIVATE
@interface _NSThreadPerformInfo : NSObject
{
@package
    id target;
    SEL selector;
    id argument;
    NSMutableArray *modes;
    NSCondition *waiter;
    BOOL *signalled;
    CFRunLoopSourceRef source;
}
@end

@implementation _NSThreadPerformInfo

- (void)dealloc
{
    [target release];
    target = nil;
    [argument release];
    argument = nil;
    [modes release];
    modes = nil;
    [waiter release];
    waiter = nil;
    if (source != NULL)
    {
        CFRelease(source);
        source = NULL;
    }
    [super dealloc];
}

@end


@interface NSThread (Internal)
- (BOOL)_setThreadPriority:(double)p;
@end

@implementation NSThread

// TODO: do something with the value
@synthesize qualityOfService = _qualityOfService;

static void NSThreadEnd(void *context)
{
    NSThread *thread = (NSThread *)context;
    @autoreleasepool {
       [[NSNotificationCenter defaultCenter] postNotificationName:NSThreadWillExitNotification object:nil userInfo:nil];
    }
    thread->_state = NSThreadFinished;
    [thread release];
}

+ (NSThread *)currentThread
{
    NSThread *thread = pthread_getspecific(NSThreadKey);
    if (thread == nil)
    {
        thread = [[NSThread alloc] init];
        thread->_thread = pthread_self();
        pthread_setspecific(NSThreadKey, thread);
    }
    return thread;
}

+ (void)detachNewThreadSelector:(SEL)selector toTarget:(id)target withObject:(id)argument
{
    NSThread *thread = [[NSThread alloc] initWithTarget:target selector:selector object:argument];
    [thread start];
    [thread release];
}

+ (BOOL)isMultiThreaded
{
    return _NSIsMultiThreaded;
}

+ (void)sleepUntilDate:(NSDate *)date
{
    [self sleepForTimeInterval:[date timeIntervalSinceNow]];
}

+ (void)sleepForTimeInterval:(NSTimeInterval)ti
{
    usleep(1000000ULL * ti);
}

+ (void)exit
{
    pthread_exit(NULL);
}

+ (double)threadPriority
{
    return [[NSThread currentThread] threadPriority];
}

+ (BOOL)setThreadPriority:(double)p
{
    return [[NSThread currentThread] _setThreadPriority:p];
}

+ (NSArray *)callStackReturnAddresses
{
    void *stack[128] = { NULL };
    int count = backtrace(stack, sizeof(stack)/sizeof(stack[0]));
    CFNumberRef returnAddresses[128] = { nil };
    for (int i = 1; i < count; i++)
    {
        returnAddresses[i - 1] = CFNumberCreate(kCFAllocatorDefault, kCFNumberLongType, &stack[i]);
    }

    NSArray *callStackReturnAddresses = [[NSArray alloc] initWithObjects:(id *)returnAddresses count:count - 1];

    for (int i = 1; i < count; i++) {
        CFRelease(returnAddresses[i - 1]);
    }

    return [callStackReturnAddresses autorelease];
}

+ (NSArray *)callStackSymbols
{
    NSMutableArray *array = [NSMutableArray array];

    void *callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);

    for (int i = 1; i < frames; ++i) {
        [array addObject: [NSString stringWithFormat:@"%s", strs[i]]];
    }

    free(strs);

    return array;
}

+ (BOOL)isMainThread
{
    return [[NSThread currentThread] isMainThread];
}

+ (NSThread *)mainThread
{
    return NSMainThread;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _performers = [[NSMutableArray alloc] init];
        _threadDictionary = [[NSMutableDictionary alloc] init];
        _state = NSThreadCreated;
        pthread_attr_init(&_attr);
        // this is what iOS/Mac OS X seem to do, is this right for other operating systems?
        pthread_attr_setscope(&_attr, PTHREAD_SCOPE_SYSTEM);
        pthread_attr_setdetachstate(&_attr, PTHREAD_CREATE_DETACHED);
#ifdef DARLING
        _sharedObjects=[NSMutableDictionary new];
        if(_NSIsMultiThreaded)
            _sharedObjectLock=[NSLock new];
#endif
    }
    return self;
}

- (id)initWithTarget:(id)target selector:(SEL)selector object:(id)argument
{
    self = [self init];
    if (self)
    {
        _target = [target retain];
        _selector = selector;
        _argument = [argument retain];
    }
    return self;
}

- (void)dealloc
{
    [_target release];
    [_argument release];
    [_threadDictionary release];
    [_name release];
    pthread_attr_destroy(&_attr);
#ifdef DARLING
   id oldSharedObjects=_sharedObjects;
   _sharedObjects=nil;
   [oldSharedObjects release];
   [_sharedObjectLock release];
#endif
    [super dealloc];
}

- (NSMutableDictionary *)threadDictionary
{
    return _threadDictionary;
}

- (double)threadPriority
{
    int policy = SCHED_FIFO;
    struct sched_param schedule;
    if (pthread_getschedparam(_thread, &policy, &schedule) != 0)
    {
        return 1.0;
    }
    else
    {
        int min_priority = sched_get_priority_min(policy);
        int max_priority = sched_get_priority_max(policy);
        return (double)(schedule.sched_priority - min_priority) / (double)(max_priority - min_priority);
    }
}

- (BOOL)_setThreadPriority:(double)p
{
    int policy = SCHED_FIFO;
    struct sched_param schedule;
    if (pthread_getschedparam(_thread, &policy, &schedule) != 0)
    {
        return NO;
    }
    else
    {
        if (p > 1.0)
        {
            p = 1.0;
        }
        if (p < 0.0)
        {
            p = 0.0;
        }

        int min_priority = sched_get_priority_min(policy);
        int max_priority = sched_get_priority_max(policy);

        schedule.sched_priority = (int)p * (max_priority - min_priority) + min_priority;
        return pthread_setschedparam(_thread, policy, &schedule) == 0;
    }
}

- (void)setThreadPriority:(double)p
{
    [self _setThreadPriority:p];
}

- (void)setName:(NSString *)n
{
    if (![_name isEqualToString:n])
    {
        [_name release];
        _name = [n copy];
        if (_thread == pthread_self())
        {
            pthread_setname_np([_name UTF8String]);
        }
    }
}

- (NSString *)name
{
    if (_name == nil)
    {
        char name[17] = { '\0' };
        pthread_getname_np(_thread, name, sizeof(name) - 1);
        _name = [[NSString alloc] initWithUTF8String:name];
    }
    return _name;
}

- (NSUInteger)stackSize
{
    size_t sz = 0;
    pthread_attr_getstacksize(&_attr, &sz);
    return sz;
}

- (void)setStackSize:(NSUInteger)s
{
    if (s >= 0x40000000)
    {
        s = 0x40000000;
    }
    pthread_attr_setstacksize(&_attr, s);
}

- (BOOL)isMainThread
{
    return self == NSMainThread;
}

- (BOOL)isExecuting
{
    return _state == NSThreadRunning;
}

- (BOOL)isFinished
{
    return _state == NSThreadFinished;
}

- (BOOL)isCancelled
{
    return _state == NSThreadCancelling;
}

- (void)cancel
{
    _state = NSThreadCancelling;
}

static void *__NSThread__main__(void *context)
{
    NSThread *thread = (NSThread *)context;
    @autoreleasepool {
        thread->_state = NSThreadRunning;
        pthread_setspecific(NSThreadKey, thread);
        [thread main];
        thread->_state = NSThreadFinished;
    }
    return NULL;
}

- (void)start
{
    if (_state > NSThreadCreated)
    {
        [NSException raise:NSInvalidArgumentException format:@"Attempting to start a thread more than once"];
        return;
    }
    _state = NSThreadStarted;
    [self retain];
    if (!_NSIsMultiThreaded)
    {
        _NSIsMultiThreaded = 1;
       [[NSNotificationCenter defaultCenter] postNotificationName:NSWillBecomeMultiThreadedNotification object:nil userInfo:nil];
    }
    int err = pthread_create(&_thread, &_attr, &__NSThread__main__, self);
    if (err != 0)
    {
        // GUESS: the documentation does not say how -start reports a thread that cannot be
        // created (for example an oversized -setStackSize:); undo the start and raise.
        _state = NSThreadCreated;
        [self release];
        [NSException raise:NSInternalInconsistencyException format:@"NSThread: unable to create a thread (error %d)", err];
        return;
    }
    while (_state <= NSThreadStarted)
    {
        sched_yield();
    }
}

- (void)main
{
    if (_target && _selector)
    {
        ((void (*)(id, SEL, id))objc_msgSend)(_target, _selector, _argument);
    }
}

// Queued performs run in the order they were queued among those eligible in the current
// run loop mode (Apple, NSObject performSelectorOnMainThread:withObject:waitUntilDone:modes:).
// Every queued perform has one version-0 source, added to each of its modes. Whichever source
// fires performs the oldest queued perform whose source is in the current mode; if that was
// another perform, the fired source is signalled again so its own perform still runs.
static void __NSThreadInfoPerformer(void *info)
{
    _NSThreadPerformInfo *fired = (_NSThreadPerformInfo *)info;
    NSThread *t = [NSThread currentThread];
    CFRunLoopRef rl = CFRunLoopGetCurrent();
    CFStringRef mode = CFRunLoopCopyCurrentMode(rl);
    _NSThreadPerformInfo *chosen = nil;
    @synchronized(t) {
        NSUInteger count = [t->_performers count];
        for (NSUInteger i = 0; i < count; i++)
        {
            _NSThreadPerformInfo *candidate = [t->_performers objectAtIndex:i];
            if (candidate == fired ||
                (mode != NULL && candidate->source != NULL && CFRunLoopContainsSource(rl, candidate->source, mode)))
            {
                chosen = [candidate retain];
                [t->_performers removeObjectAtIndex:i];
                break;
            }
        }
    }
    if (mode != NULL)
        CFRelease(mode);
    if (chosen == nil)
        return;
    if (chosen != fired)
    {
        CFRunLoopSourceSignal(fired->source);
        CFRunLoopWakeUp(rl);
    }
    CFRunLoopSourceInvalidate(chosen->source);
    @autoreleasepool {
        [chosen->target performSelector:chosen->selector withObject:chosen->argument];
    }
    if (chosen->waiter)
    {
        [chosen->waiter lock];
        *chosen->signalled = YES;
        [chosen->waiter signal];
        [chosen->waiter unlock];
    }
    [chosen release];
}

- (void)_nq:(_NSThreadPerformInfo *)info
{
    CFRunLoopSourceContext ctx = {
        .version = 0,
        .info = info,
        .perform = &__NSThreadInfoPerformer,
    };
    info->source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &ctx);
    @synchronized(self) {
        [_performers addObject:info];
    }
    CFRunLoopRef rl = _CFRunLoopGet0(_thread);
    for (NSString *mode in info->modes)
    {
        CFRunLoopAddSource(rl, info->source, (CFStringRef)mode);
    }
    CFRunLoopSourceSignal(info->source);
    CFRunLoopWakeUp(rl);
}

@end

@implementation NSObject (NSThreadPerformAdditions)

- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(id)arg waitUntilDone:(BOOL)waitUntilDone modes:(NSArray *)modes
{
    [self performSelector:aSelector onThread:[NSThread mainThread] withObject:arg waitUntilDone:waitUntilDone modes:modes];
}

+ (void)performSelectorOnMainThread:(SEL)aSelector withObject:(id)arg waitUntilDone:(BOOL)waitUntilDone modes:(NSArray *)modes
{
    [self performSelector:aSelector onThread:[NSThread mainThread] withObject:arg waitUntilDone:waitUntilDone modes:modes];   
}

- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(id)arg waitUntilDone:(BOOL)waitUntilDone
{
    [self performSelector:aSelector onThread:[NSThread mainThread] withObject:arg waitUntilDone:waitUntilDone modes:@[(id)kCFRunLoopCommonModes]];
}

+ (void)performSelectorOnMainThread:(SEL)aSelector withObject:(id)arg waitUntilDone:(BOOL)waitUntilDone
{
    [self performSelector:aSelector onThread:[NSThread mainThread] withObject:arg waitUntilDone:waitUntilDone modes:@[(id)kCFRunLoopCommonModes]];   
}

static void NSThreadPerform(id self, SEL aSelector, NSThread *thr, id arg, BOOL waitUntilDone, NSArray *modes)
{
    // "If you specify nil or an empty array for this parameter, this method returns without
    // performing the specified selector."
    if ([modes count] == 0)
        return;
    if ([NSThread currentThread] == thr && waitUntilDone)
    {
        ((void (*)(id, SEL, id))objc_msgSend)(self, aSelector, arg);
        return;
    }
    BOOL signalled = NO;
    _NSThreadPerformInfo *info = [[_NSThreadPerformInfo alloc] init];
    info->target = [self retain];
    info->selector = aSelector;
    info->argument = [arg retain];
    info->modes = [modes copy];
    info->signalled = &signalled;
    if (waitUntilDone)
    {
        info->waiter = [[NSCondition alloc] init];
    }
    else
    {
        info->waiter = NULL;
    }
    [thr _nq:info];
    if (waitUntilDone)
    {
        [info->waiter lock];
        while (!signalled)
        {
            [info->waiter wait];
        }
        [info->waiter unlock];
    }
    [info release];
}

- (void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)waitUntilDone modes:(NSArray *)modes
{
    NSThreadPerform(self, aSelector, thr, arg, waitUntilDone, modes);
}

+ (void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)waitUntilDone modes:(NSArray *)modes
{
    NSThreadPerform(self, aSelector, thr, arg, waitUntilDone, modes);
}

- (void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)waitUntilDone
{
    [self performSelector:aSelector onThread:thr withObject:arg waitUntilDone:waitUntilDone modes:@[(id)kCFRunLoopCommonModes]];
}

- (void)performSelectorInBackground:(SEL)aSelector withObject:(id)arg
{
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:aSelector object:arg];
    [thread start];
    [thread autorelease];
}

@end

#ifdef DARLING

static inline id _NSThreadSharedInstance(NSThread *thread,NSString *className,BOOL create) {
   NSMutableDictionary *shared=thread->_sharedObjects;
   if(!shared)
      return nil;
   id result=nil;
   [thread->_sharedObjectLock lock];
   result=[shared objectForKey:className];
   [thread->_sharedObjectLock unlock];

   if(result==nil && create){
      // do not hold lock during object allocation
      result=[NSClassFromString(className) new];
      [thread->_sharedObjectLock lock];
      [shared setObject:result forKey:className];
      [thread->_sharedObjectLock unlock];
      [result release];
   }

   return result;
}


FOUNDATION_EXPORT NSThread *NSCurrentThread(void) {
   return [NSThread currentThread];
}


FOUNDATION_EXPORT id NSThreadSharedInstance(NSString *className) {
   return _NSThreadSharedInstance(NSCurrentThread(),className,YES);
}

FOUNDATION_EXPORT id NSThreadSharedInstanceDoNotCreate(NSString *className) {
   return _NSThreadSharedInstance(NSCurrentThread(),className,NO);
}


@implementation NSThread (CocotronAdditions)

-(NSMutableDictionary *)sharedDictionary {
   return _sharedObjects;
}

- (id) sharedObjectForClassName:(NSString *)className {
   return _NSThreadSharedInstance(self,className,YES);
}

-(void)setSharedObject:object forClassName:(NSString *)className {
   [_sharedObjectLock lock];
   if(object==nil)
    [_sharedObjects removeObjectForKey:className];
   else
    [_sharedObjects setObject:object forKey:className];
   [_sharedObjectLock unlock];
}
@end

#endif
