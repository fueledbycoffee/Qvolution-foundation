/* Native controls for verbatim production methods. Full CF/ObjC integration is
 * covered by the unchanged macOS/Darling differential checks, not these doubles. */
#include <objc/runtime.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdbool.h>
#include <pthread.h>
typedef unsigned long NSUInteger;
typedef long NSInteger, CFIndex;
typedef double NSTimeInterval;
typedef uint16_t unichar, UniChar, UTF16Char;
typedef uint8_t UInt8;
typedef void *CFDictionaryRef;
typedef uint32_t UTF32Char;
typedef unsigned long NSStringEncoding, CFStringEncoding;
typedef struct { NSUInteger location, length; } NSRange;
static NSRange NSMakeRange(NSUInteger a, NSUInteger b) { return (NSRange){a,b}; }
typedef struct { unsigned long state; id *itemsPtr; unsigned long *mutationsPtr; unsigned long extra[5]; } NSFastEnumerationState;
#define NSOrderedSame 0
#define NSASCIIStringEncoding 1
#define NSUTF8StringEncoding 4
#define PATH_SEP '/'
#define PATH_MAX 4096
#define MIN(a,b) ((a)<(b)?(a):(b))
#define NSAssert(c,...) assert(c)
#define kCFAllocatorDefault NULL
#define CFSTR(s) @s
#define NSInvalidArgumentException @"invalid"
#define NSInternalInconsistencyException @"inconsistent"
@class NSString, NSArray, NSMutableArray, NSData;
__attribute__((objc_root_class)) @interface NSObject { @public Class isa; NSUInteger retains; }
+ (id)alloc; + (id)class; - (id)init; - (id)retain; - (id)autorelease; - (void)release;
- (BOOL)isNSString__; - (BOOL)isNSNumber__;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self,0); }
+ (id)class { return self; }
- (id)init { return self; }
- (id)retain { ++retains;return self; }
- (id)autorelease { return self; }
- (void)release { --retains; }
- (BOOL)isNSString__ { return NO; }
- (BOOL)isNSNumber__ { return NO; }
@end
/* A constant string uses the compiler's legacy constant-string layout. */
@interface NSString : NSObject { @public unichar *units; NSUInteger size; }
+ (id)stringWithCharacters:(const unichar *)c length:(NSUInteger)n;
- (id)initWithCharacters:(const unichar *)c length:(NSUInteger)n;
- (NSUInteger)length; - (unichar)characterAtIndex:(NSUInteger)i;
- (void)getCharacters:(unichar *)out range:(NSRange)r;
- (NSString *)substringWithRange:(NSRange)r; - (NSString *)substringToIndex:(NSUInteger)n;
- (BOOL)isEqualToString:(NSString *)s; - (NSInteger)caseInsensitiveCompare:(NSString *)s;
- (NSArray *)pathComponents; - (BOOL)hasPrefix:(NSString *)s; - (BOOL)hasSuffix:(NSString *)s;
- (NSArray *)componentsSeparatedByString:(NSString *)s;
- (NSString *)lastPathComponent; - (NSString *)stringByAppendingPathComponent:(NSString *)s;
- (NSData *)dataUsingEncoding:(NSStringEncoding)e allowLossyConversion:(BOOL)lossy;
@end
@interface NativeConstantString { Class isa; const char *text; unsigned int byteCount; }
- (NSUInteger)length; - (unichar)characterAtIndex:(NSUInteger)i;
@end
static NSUInteger decode(const char *s, NSUInteger n, unichar *u) {
 NSUInteger j=0;for(NSUInteger i=0;i<n;) { unsigned c=(unsigned char)s[i++];
 if(c>=0xc0&&c<0xe0)c=((c&31)<<6)|((unsigned char)s[i++]&63);
 else if(c>=0xe0&&c<0xf0) {c=((c&15)<<12)|(((unsigned char)s[i]&63)<<6)|((unsigned char)s[i+1]&63);i+=2;}
 if(u)u[j]=(unichar)c;++j; }return j;
}
@implementation NativeConstantString
- (NSUInteger)length { return decode(text,byteCount,NULL); }
- (unichar)characterAtIndex:(NSUInteger)i { unichar out[1024];assert(byteCount<1024);decode(text,byteCount,out);return out[i]; }
@end
@interface NSArray : NSObject { @public id items[128]; NSUInteger count; }
+ (id)arrayWithObjects:(const id *)a count:(NSUInteger)n; - (id)initWithArray:(NSArray *)a;
- (NSUInteger)count; - (id)objectAtIndex:(NSUInteger)i; - (id)lastObject;
- (void)addObject:(id)x; - (void)removeObjectAtIndex:(NSUInteger)i; - (void)removeObject:(id)x;
- (void)addObjectsFromArray:(NSArray *)a;
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)s objects:(id *)b count:(NSUInteger)n;
- (id)indexesOfObjectsPassingTest:(BOOL (^)(id,NSUInteger,BOOL *))p;
- (void)removeObjectsAtIndexes:(NSArray *)indexes;
@end
@implementation NSArray
+ (id)arrayWithObjects:(const id *)a count:(NSUInteger)n { NSArray *o=[self alloc];for(NSUInteger i=0;i<n;i++)[o addObject:a[i]];return o; }
- (id)initWithArray:(NSArray *)a { for(NSUInteger i=0;i<[a count];i++)[self addObject:[a objectAtIndex:i]];return self; }
- (NSUInteger)count { return count; }
- (id)objectAtIndex:(NSUInteger)i { assert(i<count);return items[i]; }
- (id)lastObject { return count?items[count-1]:nil; }
- (void)addObject:(id)x { assert(x&&count<128);items[count++]=x; }
- (void)removeObjectAtIndex:(NSUInteger)i { assert(i<count);memmove(items+i,items+i+1,(--count-i)*sizeof(id)); }
- (void)removeObject:(id)x { for(NSUInteger i=count;i>0;i--)if(items[i-1]==x)[self removeObjectAtIndex:i-1]; }
- (void)addObjectsFromArray:(NSArray *)a { for(NSUInteger i=0;i<a->count;i++)[self addObject:a->items[i]]; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)s objects:(id *)b count:(NSUInteger)n {
 if(s->state)return 0;s->state=1;s->itemsPtr=items;s->mutationsPtr=&s->extra[0];return count;
}
- (id)indexesOfObjectsPassingTest:(BOOL (^)(id,NSUInteger,BOOL *))p {
 NSArray *a=[NSArray alloc];BOOL stop=NO;for(NSUInteger i=0;i<count;i++)if(p(items[i],i,&stop))[a addObject:(id)(uintptr_t)(i+1)];return a;
}
- (void)removeObjectsAtIndexes:(NSArray *)a { for(NSUInteger i=a->count;i>0;i--)[self removeObjectAtIndex:(uintptr_t)a->items[i-1]-1]; }
@end
#define NSIndexSet NSArray
@interface NSMutableArray : NSArray @end
@implementation NSMutableArray @end
@implementation NSString
+ (id)initialize {
 if(self==[NSString class]) {
  Class c=objc_getClass("NativeConstantString");
  Class parents[]={objc_getClass("NSObject"),self};
  for(int i=0;i<2;i++){unsigned count=0;Method *methods=class_copyMethodList(parents[i],&count);
   for(unsigned j=0;j<count;j++)class_addMethod(c,method_getName(methods[j]),method_getImplementation(methods[j]),method_getTypeEncoding(methods[j]));free(methods);}
 }return self;
}
+ (id)stringWithCharacters:(const unichar *)c length:(NSUInteger)n { return [[self alloc] initWithCharacters:c length:n]; }
- (id)initWithCharacters:(const unichar *)c length:(NSUInteger)n { units=malloc((n+1)*2);memcpy(units,c,n*2);size=n;return self; }
- (BOOL)isNSString__ { return YES; }
- (BOOL)boolValue { if(![self length])return NO;unichar c=[self characterAtIndex:0];return c=='y'||c=='Y'||c=='t'||c=='T'||(c>='1'&&c<='9'); }
- (NSUInteger)length { return size; }
- (unichar)characterAtIndex:(NSUInteger)i { assert(i<size);return units[i]; }
- (void)getCharacters:(unichar *)out range:(NSRange)r { for(NSUInteger i=0;i<r.length;i++)out[i]=[self characterAtIndex:r.location+i]; }
- (NSString *)substringWithRange:(NSRange)r { unichar out[PATH_MAX];assert(r.location+r.length<=[self length]);[self getCharacters:out range:r];return [NSString stringWithCharacters:out length:r.length]; }
- (NSString *)substringToIndex:(NSUInteger)n { return [self substringWithRange:NSMakeRange(0,n)]; }
- (BOOL)isEqualToString:(NSString *)s { if(!s||[self length]!=[s length])return NO;for(NSUInteger i=0;i<[self length];i++)if([self characterAtIndex:i]!=[s characterAtIndex:i])return NO;return YES; }
- (NSInteger)caseInsensitiveCompare:(NSString *)s { if([self length]!=[s length])return 1;for(NSUInteger i=0;i<[self length];i++){unsigned a=[self characterAtIndex:i],b=[s characterAtIndex:i];if(a>='A'&&a<='Z')a+=32;if(b>='A'&&b<='Z')b+=32;if(a!=b)return 1;}return 0; }
- (BOOL)hasPrefix:(NSString *)s { return [self length]>=[s length]&&[[self substringToIndex:[s length]] isEqualToString:s]; }
- (BOOL)hasSuffix:(NSString *)s { return [self length]>=[s length]&&[[self substringWithRange:NSMakeRange([self length]-[s length],[s length])] isEqualToString:s]; }
- (NSArray *)componentsSeparatedByString:(NSString *)s { assert([s length]==1);NSArray *a=[NSArray alloc];NSUInteger start=0;for(NSUInteger i=0;i<=[self length];i++)if(i==[self length]||[self characterAtIndex:i]==[s characterAtIndex:0]){[a addObject:[self substringWithRange:NSMakeRange(start,i-start)]];start=i+1;}return a; }
@end
@interface NSException : NSObject
+ (void)raise:(NSString *)name format:(NSString *)format,...;
@end
@implementation NSException
+ (void)raise:(NSString *)name format:(NSString *)format,... { abort(); }
@end
#define NSPathSep @"/"
@interface NSPathStore2 : NSString { @public NSArray *_components; NSUInteger _lengthAndRefCount; unichar _characters[1]; }
+ (id)pathWithComponents:(NSArray *)a;
@end
static void *NSDefaultMallocZone(void) { return NULL; }
static id NSAllocateObject(Class c, NSUInteger n, void *zone) { return class_createInstance(c,n); }
@implementation NSPathStore2
#include "pathstore.inc"
- (NSUInteger)length { return _lengthAndRefCount>>20; }
- (unichar)characterAtIndex:(NSUInteger)i { assert(i<[self length]);return _characters[i]; }
@end
@implementation NSString (Paths)
#include "paths.inc"
@end
@interface NSNumber : NSObject { @public double number; }
- (BOOL)boolValue;
@end
@implementation NSNumber
- (BOOL)isNSNumber__ { return YES; }
- (BOOL)boolValue { return number!=0; }
@end
@interface NSUserDefaults : NSObject { @public id value; }
- (id)objectForKey:(NSString *)key; - (BOOL)boolForKey:(NSString *)key;
@end
@implementation NSUserDefaults
- (id)objectForKey:(NSString *)key { return value; }
#include "defaults.inc"
@end
@interface NSOperation : NSObject
- (BOOL)isConcurrent; - (BOOL)isAsynchronous;
@end
@implementation NSOperation
#include "operation.inc"
@end
@interface AsyncOperation : NSOperation @end
@implementation AsyncOperation
- (BOOL)isAsynchronous { return YES; }
@end
@interface NSInvocation : NSObject { @public id recipient; }
- (id)target;
@end
@implementation NSInvocation
- (id)target { return recipient; }
@end
@interface NSUndoGroup : NSObject { @public NSUndoGroup *_parentGroup; NSMutableArray *_invocations; }
- (NSArray *)invocations; - (NSUndoGroup *)parentGroup; - (void)removeInvocationsWithTarget:(id)x;
@end
@implementation NSUndoGroup
- (NSArray *)invocations { return _invocations; }
- (NSUndoGroup *)parentGroup { return _parentGroup; }
#include "undogroup.inc"
@end
@interface NSUndoManager : NSObject { @public NSMutableArray *_undoStack,*_redoStack; NSUndoGroup *_currentGroup; }
- (void)removeAllActionsWithTarget:(id)x;
@end
@implementation NSUndoManager
#include "undo.inc"
@end
typedef union { void *ptr; id obj; } GSIMapKey;
typedef struct { GSIMapKey key; } Node;
typedef Node *GSIMapNode;
@interface NSConcreteHashTable : NSObject { @public Node node; unsigned long version; }
- (void)addObject:(id)x;
@end
typedef NSConcreteHashTable *GSIMapTable;
static Node *GSIMapNodeForKey(GSIMapTable t, GSIMapKey k) { return t->node.key.obj&&[t->node.key.obj isEqualToString:k.obj]?&t->node:NULL; }
static void GSIMapAddKey(GSIMapTable t,GSIMapKey k) { t->node.key=k;[k.obj retain]; }
#define GSI_MAP_RELEASE_KEY(t,k) [k.obj release]
#define GSI_MAP_RETAIN_KEY(t,k) [k.obj retain]
@implementation NSConcreteHashTable
#include "hash.inc"
@end
@interface NSData : NSObject { @public uint8_t *bytes; NSUInteger length; }
@end
@implementation NSData @end
@interface NSMutableData : NSData
- (id)initWithLength:(NSUInteger)n; - (void *)mutableBytes;
@end
@implementation NSMutableData
- (id)initWithLength:(NSUInteger)n { length=n;bytes=calloc(n+1,1);return self; }
- (void *)mutableBytes { return bytes; }
@end
typedef NSString *CFStringRef;
#define kCFUniCharWhitespaceCharacterSet 1
#define kCFUniCharWhitespaceAndNewlineCharacterSet 2
#define kCFUniCharDecomposableCharacterSet 3
#define MAX_DECOMPOSED_LENGTH 32
static BOOL CFUniCharIsMemberOf(unsigned c,unsigned set) { return (set==1||set==2)&&c==' '; }
static int CFUniCharDecomposeCharacter(unsigned c,unsigned *out,int n) { out[0]=c;return 1; }
#define CF_INLINE static inline
#include "fallback.inc"
static CFStringEncoding CFStringConvertNSStringEncodingToEncoding(NSStringEncoding e) { return e; }
/* Control for the CF byte-stream layer: execute its production ASCII fallback
 * when Foundation selects 0xff; exact replacement is otherwise per UTF-16 unit. */
static CFIndex __CFStringEncodeByteStream(CFStringRef s,CFIndex at,CFIndex n,BOOL external,CFStringEncoding e,char loss,uint8_t *out,CFIndex cap,CFIndex *used) {
 CFIndex written=0,i=0;for(;i<n;){unichar pair[2]={[s characterAtIndex:at+i],0};if(i+1<n)pair[1]=[s characterAtIndex:at+i+1];CFIndex step=1,bytes=1;uint8_t b[32];
 if(pair[0]<128)b[0]=pair[0];else if(!loss)break;
 else if(e==NSASCIIStringEncoding&&(unsigned char)loss==255)step=__CFDefaultToBytesFallbackProc(pair,n-i,b,32,&bytes);
 else b[0]=loss;
 if(out){assert(written+bytes<=cap);memcpy(out+written,b,bytes);}written+=bytes;i+=step;}
 if(used)*used=written;return i;
}
@implementation NSString (Encoding)
#include "encoding.inc"
@end
@interface Input : NSObject @end
typedef void *CFReadStreamRef;
static BOOL streamConsumed;
static const uint8_t *CFReadStreamGetBuffer(CFReadStreamRef s,CFIndex max,CFIndex *len) { static uint8_t b[1];streamConsumed=YES;*len=0;return b; }
@implementation Input
#include "stream.inc"
@end
@interface NSDate : NSObject { @public double time; }
- (double)timeIntervalSinceReferenceDate;
@end
@implementation NSDate
- (double)timeIntervalSinceReferenceDate { return time; }
@end
typedef void *CFTimeZoneRef;
static NSString *CFTimeZoneCopyAbbreviation(CFTimeZoneRef t,double d) { return d==0?@"CET":@"CEST"; }
static void CFDictionaryGetKeysAndValues(void *d,const void **k,const void **v) { for(int i=0;i<48;i++){k[i]=@"CET";v[i]=@"Europe/Paris";} }
static id CFTimeZoneCreateWithName(void *a,CFStringRef n,BOOL abbrev) { return n; }
static id CFTimeZoneCreateWithTimeIntervalFromGMT(void *a,double offset) { return @"GMT"; }
@interface Zone : NSObject
+ (id)abbreviationDictionary; - (NSString *)name;
@end
#define NSTimeZone Zone
@implementation Zone
+ (id)abbreviationDictionary { return nil; }
- (NSString *)name { return @"Europe/Paris"; }
#include "zone.inc"
@end
#undef NSTimeZone
@interface _NSNotificationObserver : NSObject { @public id _observer,_object; NSString *_name; }
@property id observer,object; @property NSString *name;
@end
@implementation _NSNotificationObserver
@synthesize observer=_observer,object=_object,name=_name;
@end
@interface Center : NSObject { @public pthread_mutex_t _observersLock; NSMutableArray *_observers; }
@end
@implementation Center
#include "notification.inc"
@end
static NSUndoGroup *group(id a,id b) {
 NSUndoGroup *g=[NSUndoGroup alloc];g->_invocations=[NSMutableArray alloc];
 for(int i=0;i<2;i++){NSInvocation *v=[NSInvocation alloc];v->recipient=i?b:a;[g->_invocations addObject:v];}return g;
}
static void test_undo(void) {
 id a=[NSObject alloc],b=[NSObject alloc];NSUndoManager *u=[NSUndoManager alloc];u->_undoStack=[NSMutableArray alloc];u->_redoStack=[NSMutableArray alloc];
 [u->_undoStack addObject:group(a,a)];[u->_undoStack addObject:group(a,a)];[u->_undoStack addObject:group(b,a)];
 [u->_redoStack addObject:group(a,a)];[u->_redoStack addObject:group(a,a)];
 u->_currentGroup=group(a,a);u->_currentGroup->_parentGroup=group(a,b);
 [u removeAllActionsWithTarget:a];assert([u->_undoStack count]==1&&[u->_redoStack count]==0);
 assert([u->_currentGroup->_invocations count]==0&&[u->_currentGroup->_parentGroup->_invocations count]==1);
 NSUndoGroup *g=[u->_undoStack lastObject];assert([g->_invocations count]==1&&[[g->_invocations lastObject] target]==b);
 [u removeAllActionsWithTarget:a];assert([u->_undoStack count]==1);
}
static void test_hash(void) {
 NSString *a=[NSString stringWithCharacters:(unichar[]){'k'} length:1],*b=[NSString stringWithCharacters:(unichar[]){'k'} length:1];
 NSConcreteHashTable *h=[NSConcreteHashTable alloc];[h addObject:a];[h addObject:b];assert(h->node.key.obj==a&&h->version==1&&a->retains==1&&b->retains==0);
}
static void test_paths(void) {
 NSString *src[]={@"",@"/",@"////",@"a/b/",@"a/b///",@"a//b/../c"};
 NSString *last[]={@"",@"/",@"/",@"b",@"b",@"c"};
 NSString *app[]={@"x y",@"/x y",@"/x y",@"a/b/x y",@"a/b/x y",@"a/b/../c/x y"};
 for(int i=0;i<6;i++)assert([[src[i] lastPathComponent] isEqualToString:last[i]]);
 for(int i=0;i<6;i++)assert([[src[i] stringByAppendingPathComponent:@"x y"] isEqualToString:app[i]]);
}
static void test_defaults(void) {
 NSUserDefaults *d=[NSUserDefaults alloc];NSString *s[]={@"YES",@"true",@"TrUe",@"1",@"17",@"0",@"false",@"NO",@"Y",@"trueSuffix",@" YES"};
 for(int i=0;i<11;i++){d->value=s[i];assert([d boolForKey:@"key"]==(i<4));}
 NSNumber *n=[NSNumber alloc];d->value=n;for(int i=0;i<3;i++){n->number=i==0?0:i==1?-42:1.25;assert([d boolForKey:@"key"]==(i!=0));}
 d->value=nil;assert(![d boolForKey:@"key"]);
}
static void test_encoding(void) {
 unichar chars[]={0x65,0x301,0xd83d,0xde00};NSString *s=[NSString stringWithCharacters:chars length:4];NSData *d=[s dataUsingEncoding:1 allowLossyConversion:YES];assert(d->length==3&&!memcmp(d->bytes,"e??",3));
 s=[NSString stringWithCharacters:(unichar[]){0xe9} length:1];d=[s dataUsingEncoding:1 allowLossyConversion:YES];assert(d->length==1&&d->bytes[0]=='e');
 assert([s dataUsingEncoding:1 allowLossyConversion:NO]==nil);
}
static void test_operation(void) {
 assert(class_getInstanceMethod([NSOperation class],@selector(isAsynchronous)));
 assert(![[NSOperation alloc] isAsynchronous]);assert([[AsyncOperation alloc] isAsynchronous]);
}
static void test_stream(void) {
 id s=[Input alloc];uint8_t *bytes=(void *)1;NSUInteger len=99;assert(![s getBuffer:&bytes length:&len]);assert(!streamConsumed&&bytes==NULL&&len==0);
}
static void test_zone(void) {
 id z=[Zone alloc];NSDate *d=[NSDate alloc];d->time=1;assert([[z abbreviationForDate:d] isEqualToString:@"CEST"]);d->time=0;assert([[z abbreviationForDate:d] isEqualToString:@"CET"]);
 assert([[z initWithName:@"UTC"] isEqualToString:@"GMT"]);
}
static void test_notification(void) {
 Center *c=[Center alloc];pthread_mutex_init(&c->_observersLock,NULL);c->_observers=[NSMutableArray alloc];id owner=[NSObject alloc],sender=[NSObject alloc];
 _NSNotificationObserver *a=[_NSNotificationObserver alloc];a.observer=owner;a.name=@"note";a.object=sender;[c->_observers addObject:a];
 [c removeObserver:owner name:nil object:nil];assert([c->_observers count]==0);
 [c->_observers addObject:a];[c removeObserver:a name:@"note" object:nil];assert([c->_observers count]==0);
 [c->_observers addObject:a];[c removeObserver:nil name:nil object:nil];assert([c->_observers count]==1);
}
int main(int argc,char **argv) {
 [NSString class];assert(argc==2);
 if(!strcmp(argv[1],"undo"))test_undo();else if(!strcmp(argv[1],"hash"))test_hash();else if(!strcmp(argv[1],"paths"))test_paths();else if(!strcmp(argv[1],"defaults"))test_defaults();else if(!strcmp(argv[1],"encoding"))test_encoding();else if(!strcmp(argv[1],"operation"))test_operation();else if(!strcmp(argv[1],"stream"))test_stream();else if(!strcmp(argv[1],"zone"))test_zone();else if(!strcmp(argv[1],"notification"))test_notification();else abort();
 printf("PASS native %s\n",argv[1]);return 0;
}
