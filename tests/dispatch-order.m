/* Rung 3: public API contracts; FIFO is ordered; equal timer deadlines have no tie-order contract.
 * https://developer.apple.com/tutorials/data/documentation/dispatch/dispatchqueue.json
 * https://developer.apple.com/tutorials/data/documentation/dispatch/dispatchgroup.json
 * https://developer.apple.com/tutorials/data/documentation/dispatch/dispatchqueue/asyncafter(deadline:execute:).json
 */

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#include <stdio.h>
#include <unistd.h>
#include <time.h>

@interface ORDTrace : NSObject
@property(nonatomic,strong) NSMutableArray<NSString *> *events;
- (void)add:(NSString *)s;
- (NSString *)order;
- (NSUInteger)count;
@end
@implementation ORDTrace
- (instancetype)init { if ((self=[super init])) _events=[NSMutableArray array]; return self; }
- (void)add:(NSString *)s { @synchronized(self) { [_events addObject:s]; } }
- (NSString *)order { @synchronized(self) { return [_events componentsJoinedByString:@","]; } }
- (NSUInteger)count { @synchronized(self) { return _events.count; } }
@end
static NSString *ordYesNo(BOOL b) { return b ? @"YES" : @"NO"; }
static NSString *num(NSUInteger n) { return [NSString stringWithFormat:@"%lu",(unsigned long)n]; }
static void output(NSString *key, NSString *value) { printf("%s: %s\n",key.UTF8String,value.UTF8String); }
#define FACT(key, ...) do { @try { output((key),(__VA_ARGS__)); } @catch(NSException *e) { output((key),[@"EXCEPTION " stringByAppendingString:e.name]); } } while(0)
static NSString *key(NSString *api, NSString *item, NSString *scenario) {
    return [NSString stringWithFormat:@"%@.%@(%@)",api,item,scenario];
}
static BOOL pump(NSString *mode, BOOL (^done)(void)) {
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:0.20];
    BOOL reached=NO;
    do { @autoreleasepool {
        [[NSRunLoop currentRunLoop] runMode:mode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.002]];
    } reached=done(); } while (!reached && [deadline timeIntervalSinceNow]>0);
    return reached;
}
static void configure(void) {
    [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"AppleLocale":@"en_US_POSIX"}];
    setbuf(stdout,NULL);
    alarm(4); // A watchdog for OUR process only; no durations are printed.
}

static NSString *tieMembers(NSArray<NSString *> *events) {
    return [[events sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","];
}
static BOOL validTieDelivery(NSArray<NSString *> *events) {
    return events.count==3 && [tieMembers(events) isEqualToString:@"A,B,C"];
}
static BOOL tieContractSelfTest(void) {
    NSArray *valid=@[@[@"A",@"B",@"C"],@[@"A",@"C",@"B"],@[@"B",@"A",@"C"],
                     @[@"B",@"C",@"A"],@[@"C",@"A",@"B"],@[@"C",@"B",@"A"]];
    NSArray *invalid=@[@[],@[@"A",@"B"],@[@"A",@"A",@"C"],@[@"A",@"B",@"D"],
                       @[@"A",@"B",@"C",@"C"]];
    for(NSArray *events in valid) if(!validTieDelivery(events)) return NO;
    for(NSArray *events in invalid) if(validTieDelivery(events)) return NO;
    return YES;
}
static double monotonicSeconds(void) {
    struct timespec ts;
    if(clock_gettime(CLOCK_MONOTONIC,&ts)) abort();
    return (double)ts.tv_sec+(double)ts.tv_nsec/1e9;
}
static char queueKey;
int main(void) { @autoreleasepool { configure();
    BOOL selfTest=tieContractSelfTest();
    FACT(@"dispatch.tieContractSelfTest(permutations-and-invalid-delivery)",ordYesNo(selfTest));
    if(!selfTest) return 4;
    NSArray *names=@[@"serial-async",@"serial-nested",@"serial-sync",@"serial-after-equal",@"group-notify",@"completed-group-notify",@"main-async",@"main-after-equal",@"main-group-notify",@"main-sync-skipped"];
    for(NSUInteger c=0;c<names.count;c++){ @autoreleasepool { @try {
        NSString *name=names[c];BOOL main=c>=6;
        ORDTrace *t=[ORDTrace new];
        dispatch_queue_t queue=main?dispatch_get_main_queue():dispatch_queue_create("org.qvolution.oracle.order",DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(queue,&queueKey,&queueKey,NULL);
        dispatch_semaphore_t delivered=dispatch_semaphore_create(0);
        BOOL equalDeadline=c==3||c==7;
        __block BOOL correctThread=YES,serialExecution=YES,notBeforeDeadline=YES;
        __block int active=0;
        __block double earliest=0;
        void (^record)(NSString *)=^(NSString *s){
            BOOL serial=__sync_add_and_fetch(&active,1)==1;
            BOOL onTime=!equalDeadline||monotonicSeconds()>=earliest;
            @synchronized(t){
                correctThread &= dispatch_get_specific(&queueKey)==&queueKey && (!main||[NSThread isMainThread]);
                serialExecution &= serial;
                notBeforeDeadline &= onTime;
            }
            [t add:s];
            __sync_sub_and_fetch(&active,1);
            dispatch_semaphore_signal(delivered);
        };
        FACT(key(@"dispatch",@"beforeSubmit",name),t.order);
        dispatch_group_t group=dispatch_group_create();
        dispatch_semaphore_t startGate=dispatch_semaphore_create(0);
        if(!main) dispatch_async(queue,^{dispatch_semaphore_wait(startGate,DISPATCH_TIME_FOREVER);});
        NSUInteger expected=c==9?0:3;
        if(c==4||c==8) dispatch_group_enter(group);
        earliest=monotonicSeconds()+0.005;
        dispatch_time_t same=dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_MSEC);
        for(NSUInteger i=0;i<expected;i++){
            NSString *label=@[@"A",@"B",@"C"][i];
            if(c==3||c==7) dispatch_after(same,queue,^{record(label);});
            else if(c==4||c==5||c==8) dispatch_group_notify(group,queue,^{record(label);});
            else if(c==1&&i==0) dispatch_async(queue,^{record(@"A");dispatch_async(queue,^{record(@"D");});});
            else if(c!=2) dispatch_async(queue,^{record(label);});
        }
        // Serial tasks are gated; main tasks cannot run while this main frame is submitting.
        FACT(key(@"dispatch",@"afterSubmit",name),t.order);
        if(!main) dispatch_semaphore_signal(startGate);
        if(c==2) for(NSString *label in @[@"A",@"B",@"C"]) dispatch_sync(queue,^{record(label);});
        if(c==1) expected=4;
        if(c==4||c==8) dispatch_group_leave(group);
        __block NSUInteger received=0;
        BOOL complete=YES;
        if(main&&expected) complete=pump(NSDefaultRunLoopMode,^BOOL{
            while(received<expected&&dispatch_semaphore_wait(delivered,DISPATCH_TIME_NOW)==0) received++;
            return received==expected;
        });
        else for(NSUInteger i=0;i<expected;i++) {
            if(dispatch_semaphore_wait(delivered,dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC))) {complete=NO;break;}
            received++;
        }
        // Drain the owned serial queue after all child submissions have been made.
        if(!main&&complete) dispatch_sync(queue,^{});
        if(equalDeadline) {
            printf("## dispatch.callbackOrder(%s): %s\n",name.UTF8String,t.order.UTF8String);
            FACT(key(@"dispatch",@"callbackMembers",name),tieMembers(t.events));
        } else FACT(key(@"dispatch",@"callbackOrder",name),c==9?@"SKIPPED main sync from main (deadlock)":t.order);
        FACT(key(@"dispatch",@"completed",name),ordYesNo(complete));
        FACT(key(@"dispatch",@"callbackCount",name),num(received));
        FACT(key(@"dispatch",@"queueContextAndMainThread",name),ordYesNo(correctThread));
        FACT(key(@"dispatch",@"serialExecution",name),ordYesNo(serialExecution));
        FACT(key(@"dispatch",@"notBeforeDeadline",name),ordYesNo(notBeforeDeadline));
        if(!complete) return 2;
        if(!correctThread||!serialExecution||!notBeforeDeadline||
           (equalDeadline&&!validTieDelivery(t.events))) return 4;
    } @catch(NSException *e) { FACT(key(@"dispatch",@"scenario",names[c]),[@"EXCEPTION " stringByAppendingString:e.name]); return 3; } } }
} return 0; }
