/* Linux fixture for extracted production methods. Transport and serialization
 * are controlled doubles; this does not exercise Mach IPC or object coding. */
#include <objc/runtime.h>
#include <dispatch/dispatch.h>
#include <Block/Block.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned long NSUInteger;
typedef unsigned char Boolean;
typedef unsigned long NSXPCConnectionMessageOptions;
enum { NSXPCConnectionMessageOptionsNoninvocation = 4,
       NSXPCConnectionMessageOptionsDesistProxy = 8,
       NSXPCConnectionMessageOptionsProgressMessage = 16 };
static int failures;
static unsigned retains, attachments;
static id attached;
#define CHECK(c, label) do { if (!(c)) { ++failures; puts("FAIL " label); } } while (0)
#define os_log_debug(...) ((void)0)
#define os_log_fault(...) ((void)0)
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)new;
- (void)release;
- (id)retain;
- (BOOL)isKindOfClass:(Class)c;
@end
@implementation NSObject
+ (id)new { return class_createInstance(self, 0); }
- (void)release {}
- (id)retain { ++retains; return self; }
- (BOOL)isKindOfClass:(Class)c { return object_getClass(self) == c; }
@end
@interface NSString : NSObject
- (const char *)UTF8String;
@end
@implementation NSString
- (const char *)UTF8String { return "v@:@"; }
@end
@interface NSException : NSObject
+ (void)raise:(id)n format:(id)f, ...;
@end
@implementation NSException
+ (void)raise:(id)n format:(id)f, ... { abort(); }
@end
static id NSInvalidArgumentException;
@interface NSMethodSignature : NSObject
+ (id)signatureWithObjCTypes:(const char *)s;
- (NSUInteger)numberOfArguments;
- (const char *)getArgumentTypeAtIndex:(NSUInteger)i;
@end
@implementation NSMethodSignature
+ (id)signatureWithObjCTypes:(const char *)s { return [self new]; }
- (NSUInteger)numberOfArguments { return 3; }
- (const char *)getArgumentTypeAtIndex:(NSUInteger)i { return "@"; }
@end
@interface NSInvocation : NSObject { @public SEL _selector; }
+ (id)invocationWithMethodSignature:(id)s;
- (void)setSelector:(SEL)s;
- (SEL)selector;
- (void)getArgument:(void *)p atIndex:(NSUInteger)i;
- (void)_addAttachedObject:(id)o;
@end
@implementation NSInvocation
+ (id)invocationWithMethodSignature:(id)s { return [self new]; }
- (void)setSelector:(SEL)s { _selector = s; }
- (SEL)selector { return _selector; }
- (void)getArgument:(void *)p atIndex:(NSUInteger)i { *(id *)p = nil; }
- (void)_addAttachedObject:(id)o { CHECK(o != nil, "nil argument never inserted into invocation retention array"); ++attachments; attached = o; }
@end
@interface NSArray : NSObject @end
@implementation NSArray @end
@interface _NSXPCDistantObject : NSObject @end
@implementation _NSXPCDistantObject @end
@interface NSXPCInterface : NSObject { @public NSArray *requestClasses, *replyClasses; }
- (NSArray *)_allowedClassesForSelector:(SEL)s reply:(BOOL)reply;
- (id)_interfaceForArgument:(NSUInteger)i ofSelector:(SEL)s reply:(BOOL)reply;
@end
@implementation NSXPCInterface
- (NSArray *)_allowedClassesForSelector:(SEL)s reply:(BOOL)reply { return reply ? replyClasses : requestClasses; }
- (id)_interfaceForArgument:(NSUInteger)i ofSelector:(SEL)s reply:(BOOL)reply { return nil; }
@end
@interface _NSXPCDistantObject (Interface)
- (void)set_remoteInterface:(id)i;
@end
struct NSXPCObject { NSUInteger offset; };
struct NSXPCDeserializer { int unused; };
typedef void *xpc_object_t;
static const char *_NSXPCSerializationASCIIStringForObject(void *d, struct NSXPCObject *o) { return "request:"; }
static id _NSXPCSerializationStringForObject(void *d, struct NSXPCObject *o) { return [NSString new]; }
static void _NSXPCSerializationIterateArrayObject(void *d, void *o, Boolean (^b)(struct NSXPCObject *)) {
    for (NSUInteger i = 0; i < 3; ++i) { struct NSXPCObject item = {i}; if (!b(&item)) break; }
}
static const char *stripQualifiersAndComments(const char *s) { return s; }
static NSArray *expectedClasses;
static id decodedObject;
static unsigned decodeCalls;
static void _NSXPCSerializationDecodeInvocationArgumentArray(id i, id s, id decoder, void *d, void *o, NSArray *classes, BOOL reply) {
    ++decodeCalls;
    CHECK(classes == expectedClasses, "argument classes follow message direction");
}
@interface NSXPCDecoder : NSObject {
    struct NSXPCDeserializer _deserializer;
    struct NSXPCObject *_collection;
}
- (void)_startReadingFromXPCObject:(xpc_object_t)o;
- (id)_decodeObjectOfClasses:(id)c atObject:(void *)o;
- (void)__decodeXPCObject:(xpc_object_t)o allowingSimpleMessageSend:(BOOL)s outInvocation:(NSInvocation **)i outArguments:(NSArray **)a outArgumentsMaxCount:(NSUInteger)n outMethodSignature:(NSMethodSignature **)m outSelector:(SEL *)sel isReply:(BOOL)r replySelector:(SEL)rs interface:(NSXPCInterface *)f;
@end
@implementation NSXPCDecoder
- (void)_startReadingFromXPCObject:(xpc_object_t)o {}
- (id)_decodeObjectOfClasses:(id)c atObject:(void *)o { return decodedObject; }
#include "decoder.inc"
@end

static void decodeObjectArgument(NSXPCDecoder *decoder, NSInvocation *invocation, id *addr) {
    id classes = nil;
    void *object = NULL;
    switch ('@') {
#define _C_ID '@'
#include "decode-id.inc"
#undef _C_ID
    }
}

struct Transport { dispatch_queue_t queue; void (^handler)(xpc_object_t); };
typedef struct Transport *xpc_connection_t;
typedef void *xpc_type_t;
#define XPC_TYPE_DICTIONARY ((void *)1)
#define XPC_TYPE_ERROR ((void *)2)
#define XPC_ERROR_CONNECTION_INTERRUPTED ((void *)3)
#define XPC_ERROR_CONNECTION_INVALID ((void *)4)
static xpc_type_t xpc_get_type(xpc_object_t o) { return o == XPC_TYPE_DICTIONARY ? XPC_TYPE_DICTIONARY : XPC_TYPE_ERROR; }
static NSUInteger xpc_dictionary_get_uint64(xpc_object_t o, const char *key) { return 0; }
static void xpc_connection_set_target_queue(xpc_connection_t c, dispatch_queue_t q) { c->queue = q; }
static void xpc_connection_set_event_handler(xpc_connection_t c, void (^h)(xpc_object_t)) { c->handler = Block_copy(h); }
static void *queueKey = &queueKey;
static unsigned messages, invalidations;
@interface NSXPCConnection : NSObject {
    @public xpc_connection_t _xpcConnection;
    dispatch_queue_t _queue;
    NSUInteger _generationCount;
    id _serviceName;
    void (^_invalidationHandler)(void), (^_interruptionHandler)(void);
    id _exportedObject;
}
@property(copy) void (^invalidationHandler)(void);
@property(copy) void (^interruptionHandler)(void);
@property(retain) id exportedObject;
- (void)_setupConnection;
- (void)invalidate;
- (void)_decodeAndInvokeMessageWithEvent:(void *)e flags:(NSUInteger)f;
- (void)receivedReleaseForProxyNumber:(NSUInteger)n userQueue:(dispatch_queue_t)q;
- (void)_decodeProgressMessageWithData:(void *)e flags:(NSUInteger)f;
@end
@implementation NSXPCConnection
@synthesize exportedObject = _exportedObject;
- (void (^)(void))invalidationHandler { return _invalidationHandler; }
- (void)setInvalidationHandler:(void (^)(void))h { Block_release(_invalidationHandler); _invalidationHandler = h ? Block_copy(h) : NULL; }
- (void (^)(void))interruptionHandler { return _interruptionHandler; }
- (void)setInterruptionHandler:(void (^)(void))h { Block_release(_interruptionHandler); _interruptionHandler = h ? Block_copy(h) : NULL; }
- (void)invalidate {}
- (void)_decodeAndInvokeMessageWithEvent:(void *)e flags:(NSUInteger)f {
    ++messages; CHECK(dispatch_get_specific(queueKey) == _queue, "incoming invocation uses reply queue");
}
- (void)receivedReleaseForProxyNumber:(NSUInteger)n userQueue:(dispatch_queue_t)q {}
- (void)_decodeProgressMessageWithData:(void *)e flags:(NSUInteger)f {}
#include "connection.inc"
@end

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    if (!strcmp(argv[1], "classes")) {
        NSXPCInterface *interface = [NSXPCInterface new];
        interface->requestClasses = [NSArray new]; interface->replyClasses = [NSArray new];
        NSXPCDecoder *decoder = [NSXPCDecoder new];
        for (unsigned reply = 0; reply < 2; ++reply) {
            expectedClasses = reply ? interface->replyClasses : interface->requestClasses;
            NSInvocation *invocation = nil;
            [decoder __decodeXPCObject:NULL allowingSimpleMessageSend:NO outInvocation:&invocation outArguments:NULL outArgumentsMaxCount:0 outMethodSignature:NULL outSelector:NULL isReply:reply replySelector:reply ? @selector(request:) : NULL interface:interface];
            CHECK(invocation != nil, "invocation produced for both directions");
        }
        CHECK(decodeCalls == 2, "request and reply decoded");
    } else if (!strcmp(argv[1], "queue")) {
        NSXPCConnection *connection = [NSXPCConnection new];
        struct Transport transport = {0}; connection->_xpcConnection = &transport;
        connection->_queue = dispatch_queue_create("fixture.reply", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(connection->_queue, queueKey, connection->_queue, NULL);
        [connection _setupConnection];
        CHECK(transport.queue == connection->_queue, "endpoint and peer transport target serial reply queue");
        connection->_invalidationHandler = ^{
            ++invalidations; CHECK(dispatch_get_specific(queueKey) == connection->_queue, "invalidation uses reply queue");
            CHECK(messages == 1, "invalidation follows earlier invocation");
        };
        dispatch_sync(transport.queue ?: dispatch_get_global_queue(0, 0), ^{ transport.handler(XPC_TYPE_DICTIONARY); transport.handler(XPC_ERROR_CONNECTION_INVALID); });
        CHECK(messages == 1 && invalidations == 1, "invocation and invalidation delivered once");
        Block_release(transport.handler); dispatch_release(connection->_queue);
    } else if (!strcmp(argv[1], "nil")) {
        NSXPCDecoder *decoder = [NSXPCDecoder new];
        NSInvocation *invocation = [NSInvocation new];
        id value = (id)1;
        decodeObjectArgument(decoder, invocation, &value);
        CHECK(value == nil && attachments == 0, "nil reply block placeholder survives decoding");
        decodedObject = [NSObject new];
        decodeObjectArgument(decoder, invocation, &value);
        CHECK(value == decodedObject && attachments == 1 && attached == value, "nonnull argument attached for invocation lifetime");
        decodeObjectArgument(decoder, nil, &value);
        CHECK(value == decodedObject && retains == 1, "argument without invocation retained for caller");
        decodedObject = nil;
        decodeObjectArgument(decoder, nil, &value);
        CHECK(value == nil && retains == 1, "nil argument without invocation remains nil");
    } else return 2;
    printf("nsxpc-%s: %d failures\n", argv[1], failures);
    return failures ? 1 : 0;
}
