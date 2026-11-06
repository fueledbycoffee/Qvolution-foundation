/* Production-method fixture: Linux pipes are real; Foundation, CF and dispatch
 * are controlled doubles. Dispatch callbacks run inline before stack blocks
 * expire, so this does not claim to verify async scheduling or block ownership. */
#include <objc/runtime.h>
#include <objc/message.h>
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
typedef unsigned long NSUInteger;
#define PAGE_SIZE 4096
#define NS_OPTIONS(t,n) t n; enum
#define NS_ENUM(t,n) t n; enum
PRODUCTION_ENUMS
void *_NSConcreteStackBlock[32], *_NSConcreteGlobalBlock[32];
void _Block_object_assign(void *dst, const void *src, int flags) { *(const void **)dst=src; }
void _Block_object_dispose(const void *src, int flags) {}

__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
+ (Class)class;
- (id)init;
- (id)retain;
- (void)release;
- (BOOL)isNSData__;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self,0); }
+ (Class)class { return self; }
- (id)init { return self; }
- (id)retain { return self; }
- (void)release {}
- (BOOL)isNSData__ { return NO; }
@end
@interface NSAutoreleasePool : NSObject
- (void)drain;
@end
@implementation NSAutoreleasePool
- (void)drain {}
@end
@interface NSString : NSObject @end
@implementation NSString @end
@interface FixtureString : NSString { const char *bytes; unsigned long length; } @end
@implementation FixtureString @end
@interface NSNumber : NSObject
+ (id)numberWithUnsignedInt:(unsigned int)n;
@end
@implementation NSNumber
+ (id)numberWithUnsignedInt:(unsigned int)n { return [[self alloc]init]; }
@end
@interface NSData : NSObject { @public void *bytes; NSUInteger length; }
+ (id)data;
+ (id)dataWithBytes:(const void *)p length:(NSUInteger)n;
+ (id)dataWithBytesNoCopy:(void *)p length:(NSUInteger)n;
@end
@implementation NSData
+ (id)data { return [self dataWithBytes:NULL length:0]; }
+ (id)dataWithBytes:(const void *)p length:(NSUInteger)n {
    void *copy=malloc(n?n:1); assert(copy); if(n)memcpy(copy,p,n);
    return [self dataWithBytesNoCopy:copy length:n];
}
+ (id)dataWithBytesNoCopy:(void *)p length:(NSUInteger)n {
    assert(n<=PAGE_SIZE); NSData *d=[self alloc];d->bytes=p;d->length=n;return d;
}
- (BOOL)isNSData__ { return YES; }
@end
@interface NSDictionary : NSObject { @public id keys[4],values[4]; NSUInteger count; }
+ (id)dictionaryWithObjects:(const id *)objects forKeys:(const id *)keys count:(NSUInteger)n;
- (id)objectForKey:(id)key;
@end
@implementation NSDictionary
+ (id)dictionaryWithObjects:(const id *)v forKeys:(const id *)k count:(NSUInteger)n {
    assert(n<=4);NSDictionary *d=[self alloc];d->count=n;
    for(unsigned i=0;i<n;i++){assert(v[i]);d->keys[i]=k[i];d->values[i]=v[i];}return d;
}
- (id)objectForKey:(id)key { for(unsigned i=0;i<count;i++)if(keys[i]==key)return values[i];return nil; }
@end
static id postedInfo,postedObject;
@interface NSNotificationCenter : NSObject
+ (id)defaultCenter;
- (void)postNotificationName:(id)name object:(id)object userInfo:(id)info;
@end
@implementation NSNotificationCenter
+ (id)defaultCenter { static id c;if(!c)c=[self alloc];return c; }
- (void)postNotificationName:(id)name object:(id)object userInfo:(id)info { postedInfo=info;postedObject=object; }
@end
static NSString *NSFileHandleReadCompletionNotification=@"read", *NSFileHandleReadToEndOfFileCompletionNotification=@"end",
 *NSFileHandleDataAvailableNotification=@"available", *NSFileHandleConnectionAcceptedNotification=@"accept",
 *NSFileHandleNotificationDataItem=@"data", *NSFileHandleNotificationFileHandleItem=@"handle";

/* DispatchData deliberately is not an NSData subclass. */
@interface DispatchData : NSObject { @public unsigned char *bytes;size_t length;int refs; } @end
@implementation DispatchData @end
typedef DispatchData *dispatch_data_t;
static dispatch_data_t dispatch_data_empty;
static dispatch_data_t makeData(const void *bytes,size_t n) {
    DispatchData *d=[DispatchData alloc];d->bytes=malloc(n?n:1);assert(d->bytes);
    if(n)memcpy(d->bytes,bytes,n);d->length=n;d->refs=1;return d;
}
static dispatch_data_t dispatch_data_create_map(dispatch_data_t d,const void **p,size_t *n) {d->refs++;*p=d->bytes;*n=d->length;return d;}
static dispatch_data_t dispatch_data_create_concat(dispatch_data_t a,dispatch_data_t b) {
    dispatch_data_t d=makeData(NULL,0);d->bytes=realloc(d->bytes,a->length+b->length);d->length=a->length+b->length;
    memcpy(d->bytes,a->bytes,a->length);memcpy(d->bytes+a->length,b->bytes,b->length);return d;
}
struct DispatchDouble { int kind,refs,fd;unsigned long data;void (^event)(void),(^cancel)(void); };
typedef struct DispatchDouble *dispatch_source_t,*dispatch_queue_t;
typedef int dispatch_source_type_t;
#define DISPATCH_SOURCE_TYPE_READ 1
#define DISPATCH_SOURCE_TYPE_WRITE 2
static dispatch_source_t activeSource;
static dispatch_queue_t dispatch_queue_create(const char *name,void *unused) {
    dispatch_queue_t q=calloc(1,sizeof(*q));q->kind=1;q->refs=1;return q;
}
static dispatch_source_t dispatch_source_create(int type,int fd,int flags,dispatch_queue_t q) {
    assert(q->refs==1);dispatch_source_t s=calloc(1,sizeof(*s));s->kind=2;s->refs=1;s->fd=fd;return s;
}
static void dispatch_release(void *object) {
    Class c=object_getClass((id)object);
    if(c==[DispatchData class]){dispatch_data_t d=object;assert(d->refs>0);d->refs--;return;}
    struct DispatchDouble *d=object;assert(d->refs>0);d->refs--;
}
static unsigned long dispatch_source_get_data(dispatch_source_t s) { return s->data; }
static void dispatch_source_set_event_handler(dispatch_source_t s,void (^b)(void)) { s->event=b; }
static void dispatch_source_set_cancel_handler(dispatch_source_t s,void (^b)(void)) { s->cancel=b; }
static void dispatch_source_cancel(dispatch_source_t s) { s->cancel(); }
static void dispatch_resume(dispatch_source_t s) { activeSource=s;s->event(); }
static int signals,cfReleases;
typedef void *CFRunLoopSourceRef;
static void CFRunLoopSourceInvalidate(void *p) {}
static void CFRelease(void *p) { cfReleases++; }
static void CFRunLoopSourceSignal(void *p) { signals++; }
static void CFRunLoopWakeUp(void *p) {}
static dispatch_queue_t channel;
static void *runLoopSource,*currentRunLoop;
static ssize_t _NSReadFromFileDescriptor(int fd,void *buf,size_t n) {
    ssize_t r;do {r=read(fd,buf,n);}while(r<0&&errno==EINTR);return r;
}
#define FAIL() @throw self
#define FAIL_IF_CLOSED(retval) if(_flags&NSConcreteFileHandleClosed) { FAIL(); return retval; }
PRODUCTION_CONVERT
@interface NSFileHandle : NSObject @end
@implementation NSFileHandle @end
@interface NSConcreteFileHandle : NSFileHandle {
 @public int _fd,_resultSocket;unsigned short _flags;CFRunLoopSourceRef _source;
 NSFileHandleActivity _activity;unsigned int _error;dispatch_data_t _resultData;
 void (^_readabilityHandler)(NSFileHandle *),(^_writeabilityHandler)(NSFileHandle *);
 dispatch_queue_t _monitoringQueue;
}
- (NSData *)availableData;
- (dispatch_source_t)_monitor:(BOOL)write;
- (void)testEnd:(bool)done data:(dispatch_data_t)data error:(int)error;
@end
@interface NSConcreteFileHandleARCWeakRef : NSObject { NSConcreteFileHandle *ref; }
- (void)storeWeak:(id)fh;
- (id)loadWeak;
@end
@implementation NSConcreteFileHandleARCWeakRef
- (void)storeWeak:(id)fh {ref=fh;}
- (id)loadWeak {return ref;}
@end
@implementation NSConcreteFileHandle
PRODUCTION_AVAILABLE
PRODUCTION_MONITOR
- (void)testEnd:(bool)done data:(dispatch_data_t)data error:(int)error
PRODUCTION_END_CALLBACK
@end
PRODUCTION_PERFORM
static void equalData(NSData *d,const void *p,size_t n) {
    assert([d isNSData__]);assert(d->length==n);if(n)assert(!memcmp(d->bytes,p,n));
}
static NSConcreteFileHandle *reader(const void *p,size_t n) {
    int fds[2];assert(pipe(fds)==0);if(n)assert(write(fds[1],p,n)==n);assert(close(fds[1])==0);
    NSConcreteFileHandle *fh=[NSConcreteFileHandle alloc];fh->_fd=fds[0];return fh;
}
int main(int argc,char **argv) {
    assert(argc==2);setbuf(stdout,NULL);dispatch_data_empty=makeData(NULL,0);
    const unsigned char payload[]={0,1,0,255,10};const char *which=argv[1];
    if(!strcmp(which,"available-payloads")) {
        unsigned char big[4096];for(unsigned i=0;i<sizeof(big);i++)big[i]=i;
        const void *p[]={"abc\n","caf\xc3\xa9 \xe9\x9b\xaa",payload,big};size_t n[]={4,9,5,4096};
        for(unsigned i=0;i<4;i++){NSConcreteFileHandle *fh=reader(p[i],n[i]);equalData([fh availableData],p[i],n[i]);close(fh->_fd);}
    } else if(!strcmp(which,"available-eof")) {
        NSConcreteFileHandle *fh=reader(NULL,0);@try{equalData([fh availableData],NULL,0);equalData([fh availableData],NULL,0);}
        @catch(id e){puts("FAIL EOF raised");return 1;}close(fh->_fd);
    } else if(!strcmp(which,"available-error")) {
        NSConcreteFileHandle *fh=[NSConcreteFileHandle alloc];int p[2];assert(pipe(p)==0);fh->_fd=p[1];
        BOOL raised=NO;@try{[fh availableData];}@catch(id e){raised=YES;}assert(raised);close(p[0]);close(p[1]);
        fh->_fd=-1;raised=NO;@try{[fh availableData];}@catch(id e){raised=YES;}assert(raised);
    } else if(!strncmp(which,"notification",12)) {
        for(int mode=0;mode<2;mode++)for(int empty=0;empty<2;empty++) {
            NSConcreteFileHandle *fh=[NSConcreteFileHandle alloc];fh->_activity=mode?NSFileHandleReadToEndOfFileActivity:NSFileHandleReadActivity;
            dispatch_data_t d=makeData(payload,empty?0:sizeof(payload));fh->_resultData=d;
            BOOL error=!strcmp(which,"notification-error");fh->_error=error?EBADF:0;
            NSConcreteFileHandlePerform(fh);assert(postedObject==fh);
            equalData([postedInfo objectForKey:NSFileHandleNotificationDataItem],payload,error||empty?0:sizeof(payload));
            assert(d->refs==0);assert(fh->_resultData==NULL);assert(fh->_activity==NSFileHandleNoActivity);
        }
    } else if(!strncmp(which,"monitor-",8)) {
        NSConcreteFileHandle *fh=reader(NULL,0);__block int calls=0;
        BOOL eof=!strcmp(which,"monitor-eof");
        fh->_readabilityHandler=^(NSFileHandle *h) {assert(h==fh);calls++;dispatch_source_cancel(activeSource);};
        for(int i=0;i<3;i++) {
            dispatch_source_t s=[fh _monitor:NO];
            if(!eof&&calls!=i+1)dispatch_source_cancel(s);
            assert(fcntl(s->fd,F_GETFD)==-1&&errno==EBADF);assert(s->refs==0);
            assert(fh->_monitoringQueue->refs==1);
        }
        assert(calls==3);close(fh->_fd);
    } else if(!strcmp(which,"read-to-end-empty")) {
        channel=dispatch_queue_create("io",NULL);NSConcreteFileHandle *fh=[NSConcreteFileHandle alloc];
        [fh testEnd:true data:NULL error:0];assert(signals==1&&channel->refs==0&&cfReleases==1);
        channel=dispatch_queue_create("io",NULL);[fh testEnd:true data:dispatch_data_empty error:0];assert(signals==2&&channel->refs==0);
    } else return 2;
    puts("PASS");return 0;
}
