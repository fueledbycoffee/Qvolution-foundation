/* Production regions run against controlled storage and CF scheduling boundaries.
 * These controls establish algorithm behavior, not Darling integration MATCH. */
#include "order-native-support.h"
#define NSDefaultRunLoopMode @"default"
#define NSRunLoopCommonModes @"common"
#define kCFRunLoopCommonModes NSRunLoopCommonModes
#define NSNotificationNoCoalescing 0
#define NSNotificationCoalescingOnName 1
#define NSNotificationCoalescingOnSender 2
#define NSNotFound ((NSUInteger)-1)
typedef NSUInteger NSPostingStyle;
enum { NSPostWhenIdle=1,NSPostASAP=2,NSPostNow=3 };
typedef NSUInteger CFRunLoopActivity,CFOptionFlags;
enum { kCFRunLoopEntry=1,kCFRunLoopBeforeTimers=2,kCFRunLoopBeforeSources=4,kCFRunLoopBeforeWaiting=32,kCFRunLoopExit=128,kCFRunLoopAllActivities=255 };
typedef NSString *CFStringRef;
typedef struct Observer *CFRunLoopObserverRef;
typedef void *CFRunLoopRef;
typedef struct { int version;void *info;const void *(*retain)(const void *);void(*release)(const void *);void*copyDescription; } CFRunLoopObserverContext;
struct Observer { BOOL active,repeat;CFOptionFlags activities;long order;void (*call)(CFRunLoopObserverRef,CFRunLoopActivity,void*);void *info;NSArray *modes; };
static struct Observer *observers[2048];static NSUInteger observerCount;
static NSString *currentMode;
static CFRunLoopRef CFRunLoopGetCurrent(void) { return (void*)1; }
static CFStringRef CFRunLoopCopyCurrentMode(CFRunLoopRef loop) { return [currentMode retain]; }
static CFRunLoopObserverRef CFRunLoopObserverCreate(void *a,CFOptionFlags flags,BOOL repeats,long order,void(*call)(CFRunLoopObserverRef,CFRunLoopActivity,void*),CFRunLoopObserverContext *ctx) {
 struct Observer *o=calloc(1,sizeof(*o));o->active=YES;o->repeat=repeats;o->activities=flags;o->order=order;o->call=call;o->info=ctx?ctx->info:NULL;o->modes=[NSArray alloc];assert(observerCount<2048);observers[observerCount++]=o;return o;
}
static void CFRunLoopAddObserver(CFRunLoopRef loop,CFRunLoopObserverRef o,CFStringRef mode){[o->modes addObject:mode];}
static BOOL CFRunLoopContainsObserver(CFRunLoopRef loop,CFRunLoopObserverRef o,CFStringRef mode){return o->active&&([o->modes containsObject:mode]||([o->modes containsObject:NSRunLoopCommonModes]&&[mode isEqual:NSDefaultRunLoopMode]));}
static void CFRunLoopObserverInvalidate(CFRunLoopObserverRef o){o->active=NO;}
static const void *CFRetain(const void *o){return o;}
/* Observers remain allocated for deterministic invalidation assertions. */
static void CFRelease(const void *o){}
static void *CFCopyDescription;
static void runMode(NSString *mode){NSString *previous=currentMode;currentMode=mode;NSUInteger n=observerCount;CFRunLoopActivity phases[]={kCFRunLoopEntry,kCFRunLoopBeforeTimers,kCFRunLoopBeforeSources,kCFRunLoopBeforeWaiting,kCFRunLoopExit};for(unsigned p=0;p<5;p++)for(NSUInteger i=0;i<n;i++){struct Observer *o=observers[i];if(o->active&&(o->activities&phases[p])&&CFRunLoopContainsObserver(NULL,o,mode)){o->call(o,phases[p],o->info);if(!o->repeat)o->active=NO;}}currentMode=previous;}
@class NSNotificationCenter, NSMutableDictionary;
@interface NSNotification : NSObject { NSString *_name;id _object;@public int sequence; }
@property(readonly) NSString *name;@property(readonly) id object;
@end
@implementation NSNotification
@synthesize name=_name,object=_object;
@end
@interface Note : NSNotification
+ (id)name:(NSString *)name sender:(id)sender number:(int)n;
@end
@implementation Note
+ (id)name:(NSString *)name sender:(id)sender number:(int)n { Note *o=[self alloc];object_setIvar(o,class_getInstanceVariable([NSNotification class],"_name"),name);object_setIvar(o,class_getInstanceVariable([NSNotification class],"_object"),sender);o->sequence=n;return o; }
@end
@interface NSNull : NSObject
+ (id)null;
@end
@implementation NSNull
+ (id)null { static id o;if(!o)o=[self alloc];return o; }
@end
@interface NSOperationQueue : NSObject
- (void)addOperationWithBlock:(void(^)(void))b;
@end
@implementation NSOperationQueue
- (void)addOperationWithBlock:(void(^)(void))b { b(); }
@end
@interface _NSNotificationObserver : NSObject { @public id _observer,_object;NSString *_name;NSOperationQueue *_queue;void(^_block)(NSNotification *);SEL _selector;BOOL _active; }
@property(readonly) id observer,object;@property(readonly) NSString *name;
- (id)retainedTarget;- (BOOL)isStale;- (void)invalidate;
@end
@implementation _NSNotificationObserver
@synthesize observer=_observer,object=_object,name=_name;
- (id)retainedTarget { return nil; }- (BOOL)isStale { return NO; }
#include "observer.inc"
@end
@interface NSNotificationCenter : NSObject { @public pthread_mutex_t _observersLock;NSMutableArray *_observers;int recorded[128];NSUInteger delivered; }
+ (id)defaultCenter;- (void)postNotification:(NSNotification *)note;
@end
@implementation NSNotificationCenter
+ (id)defaultCenter { static id c;if(!c)c=[[self alloc] init];return c; }
- (id)init { _observers=[NSMutableArray alloc];pthread_mutexattr_t a;pthread_mutexattr_init(&a);pthread_mutexattr_settype(&a,PTHREAD_MUTEX_RECURSIVE);pthread_mutex_init(&_observersLock,&a);pthread_mutexattr_destroy(&a);return self; }
#include "center.inc"
@end
@interface RecordingCenter : NSNotificationCenter { @public void (^during)(NSNotification *); } @end
@implementation RecordingCenter
- (void)postNotification:(NSNotification *)n { assert(delivered<128);recorded[delivered++]=n->sequence;if(during)during(n); }
@end
@interface NSThread : NSObject
+ (id)currentThread;- (id)threadDictionary;
@end
@implementation NSThread
+ (id)currentThread{return nil;}- (id)threadDictionary{return nil;}
@end
@interface NSNotificationQueue : NSObject {
#include "queue-ivars.inc"
}
- (id)initWithNotificationCenter:(NSNotificationCenter *)c;
- (void)enqueueNotification:(NSNotification *)n postingStyle:(NSUInteger)s coalesceMask:(NSUInteger)m forModes:(NSArray *)modes;
- (void)dequeueNotificationsMatching:(NSNotification *)n coalesceMask:(NSUInteger)m;
@end
#include "queue.inc"
/* Boundary controls for the production join method. */
typedef NSMutableArray *CFMutableStringRef;
static CFMutableStringRef CFStringCreateMutable(void*a,int n){return [NSMutableArray alloc];}
static void CFStringAppend(CFMutableStringRef s,CFStringRef x){[s addObject:x];}
static CFStringRef CFStringCreateCopy(void*a,CFMutableStringRef parts){unichar buffer[2048];NSUInteger n=0;for(NSString *s in parts)for(NSUInteger i=0;i<[s length];i++)buffer[n++]=[s characterAtIndex:i];return [NSString stringWithCharacters:buffer length:n];}
static CFStringRef CFStringCreateWithFormat(void*a,void*b,CFStringRef f,id x){return @"error";}
@implementation NSArray (Join)
#include "join.inc"
@end
/* CF deadline helper with a controlled monotonic clock measured in microseconds. */
typedef uint32_t mach_msg_timeout_t;typedef BOOL Boolean;typedef double CFTimeInterval;
#define TIMEOUT_INFINITY UINT32_MAX
static uint64_t now;
static uint64_t mach_absolute_time(void){return now;}
static double __CFTSRToTimeInterval(uint64_t ticks){return ticks/1000000.0;}
#include "wait.inc"
/* Production KVO push/pop with controlled observer validity and CF storage. */
@class NSKeyValueContainerClass,NSKeyValueProperty,NSKeyValueSetter,NSKeyValueObservationInfo,NSKeyValueObservance;
#define NSMutableDictionary NSObject
#define NSSet NSObject
#define NSIndexSet NSArray
typedef int NSKeyValueChange,NSKeyValueSetMutationKind;
typedef struct { int kind;id oldValue,newValue,indexes,extraData; } NSKeyValueChangeDetails;
typedef void *CFMutableSetRef,*CFMutableDictionaryRef;
typedef struct PendingArray *CFMutableArrayRef;
#include "kvo-types.inc"
@interface NSKeyValueObservance : NSObject { @public NSObject *_observer; }
@property(readonly) NSObject *observer;
@end
@implementation NSKeyValueObservance
@synthesize observer=_observer;
@end
struct PendingArray { NSKVOPendingNotificationInfo *values[128];NSInteger count; };
static inline const void *_NSKVOPendingNotificationRetain(void*,const void*);
static inline void _NSKVOPendingNotificationRelease(void*,const void*);
typedef void *CFAllocatorRef;
static NSInteger CFArrayGetCount(CFMutableArrayRef a){return a->count;}
static void *CFArrayGetValueAtIndex(CFMutableArrayRef a,NSInteger i){assert(i>=0&&i<a->count);return a->values[i];}
static void CFArrayAppendValue(CFMutableArrayRef a,void*v){assert(a->count<128);a->values[a->count++]=(void*)_NSKVOPendingNotificationRetain(NULL,v);}
static void CFArrayRemoveValueAtIndex(CFMutableArrayRef a,NSInteger i){assert(i>=0&&i<a->count);void*v=a->values[i];memmove(a->values+i,a->values+i+1,(--a->count-i)*sizeof(void*));_NSKVOPendingNotificationRelease(NULL,v);}
static id removedObservance;
static BOOL __NSKeyValueCheckObservationInfoForPendingNotification(id o,id v,NSUInteger i){return v!=removedObservance;}
#include "kvo.inc"
static NSUInteger modeChecks;
@interface CountingModes : NSArray @end
@implementation CountingModes
- (BOOL)containsObject:(id)o { modeChecks++; return [super containsObject:o]; }
- (id)copy { return [self retain]; }
@end
static void queueScanTests(void) {
 for (unsigned n=8;n<=32;n*=2) {
  RecordingCenter *c=[[RecordingCenter alloc] init];
  NSNotificationQueue *q=[[NSNotificationQueue alloc] initWithNotificationCenter:c];
  CountingModes *custom=[CountingModes arrayWithObjects:(id[]){@"custom"} count:1];
  for(unsigned i=0;i<n;i++) [q enqueueNotification:[Note name:@"custom" sender:nil number:i] postingStyle:NSPostASAP coalesceMask:0 forModes:custom];
  for(unsigned i=0;i<n;i++) [q enqueueNotification:[Note name:@"default" sender:nil number:i] postingStyle:NSPostASAP coalesceMask:0 forModes:nil];
  modeChecks=0;currentMode=NSDefaultRunLoopMode;
  [q _postNotifications:NSPostASAP];
  printf("ineligible=%u eligible=%u delivered=%lu ineligible-mode-checks=%lu\n",n,n,(unsigned long)c->delivered,(unsigned long)modeChecks);
  fflush(stdout);
  assert(c->delivered==n);
  assert(modeChecks<=2*n);
  for(unsigned i=0;i<n;i++) assert(c->recorded[i]==i);
  currentMode=@"custom";[q _postNotifications:NSPostASAP];
  assert(c->delivered==2*n);
  for(unsigned i=0;i<n;i++) assert(c->recorded[n+i]==i);
  currentMode=nil;[q release];[c release];[custom release];
 }
}
static void queueTests(void){
 id sender=[NSObject alloc],other=[NSObject alloc];
 for(int style=1;style<=3;style++)for(int mask=0;mask<4;mask++){
  RecordingCenter *c=[[RecordingCenter alloc] init];NSNotificationQueue*q=[[NSNotificationQueue alloc] initWithNotificationCenter:c];
  NSString *names[]={@"N1",@"N1",@"N2",@"N1"};id senders[]={sender,sender,sender,other};
  for(int i=0;i<4;i++)[q enqueueNotification:[Note name:names[i] sender:senders[i] number:i] postingStyle:style coalesceMask:mask forModes:nil];
  if(style!=3){assert(c->delivered==0);runMode(NSDefaultRunLoopMode);}
  int counts[]={4,2,2,3};assert(c->delivered==(style==3?4:counts[mask]));assert(c->recorded[0]==0);
  if(style!=3&&mask==1)assert(c->recorded[1]==2);
  if(style!=3&&mask==2)assert(c->recorded[1]==3);
  if(style!=3&&mask==3)assert(c->recorded[1]==2&&c->recorded[2]==3);
  [q release];
 }
 RecordingCenter *c=[[RecordingCenter alloc] init];NSNotificationQueue*q=[[NSNotificationQueue alloc] initWithNotificationCenter:c];
 NSArray *custom=[NSArray arrayWithObjects:(id[]){@"custom"} count:1];
 [q enqueueNotification:[Note name:@"a" sender:sender number:1] postingStyle:2 coalesceMask:0 forModes:custom];
 [q enqueueNotification:[Note name:@"b" sender:sender number:2] postingStyle:2 coalesceMask:0 forModes:nil];
 runMode(NSDefaultRunLoopMode);assert(c->delivered==1&&c->recorded[0]==2);runMode(@"custom");assert(c->delivered==2&&c->recorded[1]==1);
 for(int i=0;i<3;i++)[q enqueueNotification:[Note name:@"a" sender:sender number:3+i] postingStyle:2 coalesceMask:0 forModes:nil];
 [q dequeueNotificationsMatching:[Note name:@"a" sender:sender number:0] coalesceMask:3];runMode(NSDefaultRunLoopMode);assert(c->delivered==2);
 [q enqueueNotification:[Note name:@"a" sender:sender number:9] postingStyle:2 coalesceMask:0 forModes:nil];[q release];runMode(NSDefaultRunLoopMode);assert(c->delivered==2);
 c=[[RecordingCenter alloc] init];q=[[NSNotificationQueue alloc] initWithNotificationCenter:c];
 NSArray *both=[NSArray arrayWithObjects:(id[]){NSDefaultRunLoopMode,@"custom"} count:2];
 [q enqueueNotification:[Note name:@"a" sender:sender number:10] postingStyle:2 coalesceMask:0 forModes:both];
 runMode(@"custom");runMode(NSDefaultRunLoopMode);assert(c->delivered==1);
 NSArray *common=[NSArray arrayWithObjects:(id[]){NSRunLoopCommonModes} count:1];
 [q enqueueNotification:[Note name:@"a" sender:sender number:11] postingStyle:2 coalesceMask:0 forModes:common];runMode(NSDefaultRunLoopMode);assert(c->delivered==2);
 currentMode=NSDefaultRunLoopMode;[q enqueueNotification:[Note name:@"a" sender:sender number:12] postingStyle:3 coalesceMask:0 forModes:custom];assert(c->delivered==2);currentMode=nil;
 __block BOOL nested=NO;
 c->during=^(NSNotification*n){if(!nested){nested=YES;runMode(NSDefaultRunLoopMode);}};
 [q enqueueNotification:[Note name:@"a" sender:sender number:13] postingStyle:2 coalesceMask:0 forModes:nil];
 [q enqueueNotification:[Note name:@"b" sender:sender number:14] postingStyle:2 coalesceMask:0 forModes:nil];
 runMode(NSDefaultRunLoopMode);assert(c->delivered==4&&c->recorded[2]==13&&c->recorded[3]==14);c->during=NULL;[q release];
}
static void queueMutationTests(void) {
 for (NSUInteger style=NSPostWhenIdle;style<=NSPostASAP;style++) {
  RecordingCenter *c=[[RecordingCenter alloc] init];
  NSNotificationQueue *q=[[NSNotificationQueue alloc] initWithNotificationCenter:c];
  NSArray *custom=[NSArray arrayWithObjects:(id[]){@"custom"} count:1];
  [q enqueueNotification:[Note name:@"cancel" sender:nil number:1] postingStyle:style coalesceMask:0 forModes:custom];
  [q enqueueNotification:[Note name:@"custom" sender:nil number:2] postingStyle:style coalesceMask:0 forModes:custom];
  [q enqueueNotification:[Note name:@"first" sender:nil number:3] postingStyle:style coalesceMask:0 forModes:nil];
  [q enqueueNotification:[Note name:@"cancel" sender:nil number:4] postingStyle:style coalesceMask:0 forModes:nil];
  [q enqueueNotification:[Note name:@"last" sender:nil number:5] postingStyle:style coalesceMask:0 forModes:nil];
  c->during=^(NSNotification *note) {
   if(note->sequence!=3)return;
   [q dequeueNotificationsMatching:[Note name:@"cancel" sender:nil number:0] coalesceMask:NSNotificationCoalescingOnName];
   [q enqueueNotification:[Note name:@"new" sender:nil number:6] postingStyle:style coalesceMask:0 forModes:nil];
   currentMode=@"custom";[q _postNotifications:style];currentMode=NSDefaultRunLoopMode;
  };
  currentMode=NSDefaultRunLoopMode;[q _postNotifications:style];currentMode=nil;
  assert(c->delivered==4);
  assert(c->recorded[0]==3&&c->recorded[1]==2&&c->recorded[2]==5&&c->recorded[3]==6);
  c->during=NULL;[q release];[c release];[custom release];
 }
}
static void centerTests(void){
 for(int named=0;named<2;named++){
 NSNotificationCenter*c=[[NSNotificationCenter alloc] init];_NSNotificationObserver *a=[_NSNotificationObserver alloc],*b=[_NSNotificationObserver alloc],*d=[_NSNotificationObserver alloc];a->_active=b->_active=d->_active=YES;
 a->_name=b->_name=d->_name=@"a";
 __block int events=0;a->_block=^(NSNotification*n){events=events*10+1;if(named)[c removeObserver:b name:@"a" object:nil];else [c removeObserver:b];};b->_block=^(NSNotification*n){events=events*10+2;};d->_block=^(NSNotification*n){events=events*10+3;};
 [c->_observers addObject:a];[c->_observers addObject:b];[c->_observers addObject:d];[c postNotification:[Note name:@"a" sender:nil number:0]];assert(events==13);
 }
}
static void joinTests(void){id no=@"NO";NSArray *a=[NSArray arrayWithObjects:(id[]){no,no,no} count:3];assert([[a componentsJoinedByString:@","] isEqual:@"NO,NO,NO"]);assert([[[NSArray alloc] componentsJoinedByString:@","] isEqual:@""]);assert([[[NSArray arrayWithObjects:&no count:1] componentsJoinedByString:@","] isEqual:no]);}
static void waitTests(void){now=100;assert(__CFRunLoopWaitTimeout(2101,NO)==3);assert(__CFRunLoopWaitTimeout(2100,NO)==2);assert(__CFRunLoopWaitTimeout(101,NO)==1);assert(__CFRunLoopWaitTimeout(100,NO)==0);assert(__CFRunLoopWaitTimeout(UINT64_MAX,NO)==TIMEOUT_INFINITY);assert(__CFRunLoopWaitTimeout(2101,YES)==0);}
static void push(CFMutableArrayRef a,id object,id key,NSKeyValueObservance **obs,int count){NSKeyValueObservingTSD t={.pendingNotifications=a,.nextIsObservationInfo=YES,.recursionLevel=1};for(int i=0;i<count;i++)_NSKeyValuePushPendingNotificationsPerThread(object,key,obs[i],(NSKeyValueForwardingValues){0},&t,(NSKeyValueChangeDetails){0});}
static int pop(CFMutableArrayRef a,id object,id key){NSKVOPopNotificationResult r={.pendingNotifications=a,.pendingNotificationCount=a->count,.relevantNotificationIndex=-1,.recursionLevel=1};NSKeyValueObservance *o;NSKeyValueChangeDetails d;NSKeyValueForwardingValues f;id k;int n=0;while(_NSKeyValuePopPendingNotificationPerThread(object,key,&o,&d,&f,&k,&r))n++;return n;}
static void kvoTests(void){struct PendingArray a={0};id o=[NSObject alloc];NSKeyValueObservance *obs[]={ [NSKeyValueObservance alloc],[NSKeyValueObservance alloc] };
 push(&a,o,@"value",obs,2);push(&a,o,@"other",obs,1);push(&a,o,@"value",obs,2);assert(pop(&a,o,@"value")==2);assert(a.count==3);push(&a,o,@"other",obs,1);assert(pop(&a,o,@"other")==1);assert(pop(&a,o,@"other")==1);assert(pop(&a,o,@"value")==2);assert(a.count==0);
 push(&a,o,@"value",obs,1);push(&a,o,@"value",obs,2);removedObservance=obs[0];assert(pop(&a,o,@"value")==1);assert(a.count==1);removedObservance=nil;assert(pop(&a,o,@"value")==1);assert(a.count==0);
}
int main(int argc,char **argv){[NSString class];assert(argc==2);if(!strcmp(argv[1],"queue"))queueTests();else if(!strcmp(argv[1],"queue-mutations"))queueMutationTests();else if(!strcmp(argv[1],"queue-scans"))queueScanTests();else if(!strcmp(argv[1],"center"))centerTests();else if(!strcmp(argv[1],"join"))joinTests();else if(!strcmp(argv[1],"wait"))waitTests();else if(!strcmp(argv[1],"kvo"))kvoTests();else abort();printf("PASS %s production region\n",argv[1]);}
