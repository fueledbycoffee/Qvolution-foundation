/* Production NSIndexSet source and ABI, with native object allocation and a CFArray
 * test double. malloc/free (including the array shim) are counted; no Apple code.
 * Foundation string/pool doubles only let the unchanged original check print. */
#include <objc/runtime.h>
#include <objc/message.h>
#include <assert.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <pthread.h>
#include "utlist.h"
typedef unsigned long NSUInteger;
typedef long NSInteger, CFIndex;
typedef void NSZone;
typedef struct { NSUInteger location, length; } NSRange;
typedef NSRange *NSRangePointer;
#define NSUIntegerMax ULONG_MAX
#define NSNotFound LONG_MAX
#define MAX(a,b) ((a) > (b) ? (a) : (b))
#define MIN(a,b) ((a) < (b) ? (a) : (b))
#define NSCAssert(c,...) assert(c)
#define NS_BLOCKS_AVAILABLE 1
typedef NSUInteger NSEnumerationOptions;
enum { NSEnumerationConcurrent = 1, NSEnumerationReverse = 2 };
static NSRange NSMakeRange(NSUInteger l, NSUInteger n) { return (NSRange){l,n}; }
static NSUInteger NSMaxRange(NSRange r) { return r.location + r.length; }
static BOOL NSLocationInRange(NSUInteger i, NSRange r) { return i >= r.location && i < NSMaxRange(r); }
static NSRange NSIntersectionRange(NSRange a, NSRange b) {
    NSUInteger l = MAX(a.location,b.location), e = MIN(NSMaxRange(a),NSMaxRange(b));
    return NSMakeRange(l, e > l ? e-l : 0);
}
static void *dispatch_get_global_queue(int a, int b) { return NULL; }
#define DISPATCH_QUEUE_PRIORITY_DEFAULT 0
static void dispatch_apply(size_t n, void *q, void (^block)(size_t)) { abort(); }
@protocol NSCopying @end
@protocol NSMutableCopying @end
@protocol NSCoding @end
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
+ (id)allocWithZone:(NSZone *)zone;
+ (id)new;
- (id)init;
- (id)autorelease;
- (id)mutableCopy;
- (void)release;
- (void)dealloc;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self,0); }
+ (id)allocWithZone:(NSZone *)zone { return [self alloc]; }
+ (id)new { return [[self alloc] init]; }
- (id)init { return self; }
- (id)autorelease { return self; }
- (id)mutableCopy { return [self mutableCopyWithZone:NULL]; }
- (void)release { [self dealloc]; }
- (void)dealloc { object_dispose(self); }
@end
@interface NSAutoreleasePool : NSObject
- (void)drain;
@end
@implementation NSAutoreleasePool
- (void)drain { [self release]; }
@end
@interface NativeConstantString : NSObject { @public const char *bytes; unsigned int length; }
@end
@implementation NativeConstantString @end
@interface NSMutableString : NSObject { char text[256]; }
+ (id)string;
- (void)appendFormat:(NativeConstantString *)format, ...;
- (const char *)UTF8String;
@end
@implementation NSMutableString
+ (id)string { return [self new]; }
- (void)appendFormat:(NativeConstantString *)format, ... {
    va_list args; va_start(args,format);
    size_t n = strlen(text); vsnprintf(text+n,sizeof(text)-n,format->bytes,args); va_end(args);
}
- (const char *)UTF8String { return text; }
@end
@interface NSException : NSObject
+ (void)raise:(id)name format:(id)format;
@end
@implementation NSException
+ (void)raise:(id)name format:(id)format { abort(); }
@end
static id NSInvalidArgumentException, NSRangeException;
#include "indexset-header.inc"

static size_t allocations, outstanding, arrays, live_arrays, array_reads;
static long fail_after = -1;
/* Counters are atomic: the threads case calls the production code from several threads.
 * fail_after is only armed by the single-threaded failure case. */
#define INC(x) __atomic_add_fetch(&(x), 1, __ATOMIC_SEQ_CST)
#define DEC(x) __atomic_sub_fetch(&(x), 1, __ATOMIC_SEQ_CST)
static void *counted_malloc(size_t n) {
    if (fail_after == 0) { fail_after = -1; return NULL; }
    if (fail_after > 0) --fail_after;
    void *p = malloc(n); assert(p); memset(p,0xa5,n); INC(allocations); INC(outstanding); return p;
}
static void counted_free(void *p) { if (p) { size_t left = DEC(outstanding); assert(left != (size_t)-1); free(p); } }
static void *counted_reallocf(void *p, size_t n) {
    if (fail_after == 0) { fail_after=-1; counted_free(p); return NULL; }
    if (fail_after > 0) --fail_after;
    void *q = realloc(p,n);
    if (!q) { counted_free(p); return NULL; }
    INC(allocations); if (!p) INC(outstanding); return q;
}
typedef struct { CFIndex n; const void *values[]; } *CFArrayRef;
typedef struct { void *retain, *release; } CFArrayCallBacks;
#define kCFAllocatorDefault NULL
typedef int CFComparisonResult;
enum { kCFCompareLessThan = -1, kCFCompareEqualTo = 0, kCFCompareGreaterThan = 1 };
static CFArrayRef CFArrayCreate(void *a, const void **v, CFIndex n, const CFArrayCallBacks *cb) {
    CFArrayRef r = counted_malloc(sizeof(*r)+n*sizeof(*v));
    if (r) { r->n=n; memcpy(r->values,v,n*sizeof(*v)); INC(arrays); INC(live_arrays); }
    return r;
}
static const void *CFArrayGetValueAtIndex(CFArrayRef a, CFIndex i) {
    assert(a && i >= 0 && i < a->n); INC(array_reads); return a->values[i];
}
static void CFRelease(CFArrayRef a) { assert(a); size_t left = DEC(live_arrays); assert(left != (size_t)-1); counted_free(a); }
#define malloc counted_malloc
#define free counted_free
#define reallocf counted_reallocf
#include "production.inc"
#undef malloc
#undef free
#undef reallocf
#include "original.inc"

static NSMutableIndexSet *fragmented(NSUInteger n) {
    NSMutableIndexSet *s = [NSMutableIndexSet new];
    for (NSUInteger i=0;i<n;i++) [s addIndex:2*i];
    return s;
}
static void check_members(NSIndexSet *s, const unsigned char *members, NSUInteger n) {
    NSUInteger expected[512], actual[512], count=0;
    for (NSUInteger i=0;i<n;i++) if (members[i]) expected[count++]=i;
    assert([s count] == count);
    assert([s getIndexes:actual maxCount:512 inIndexRange:NULL] == count);
    assert(!memcmp(actual,expected,count*sizeof(*actual)));
    NSUInteger runs=0;
    for (NSUInteger j=0;j<count;) {
        NSUInteger k=j+1;
        while (k<count && expected[k]==expected[k-1]+1) k++;
        NSRange r=[s rangeAtIndex:runs++]; // cached range list must match the membership
        assert(r.location==expected[j] && r.length==k-j);
        j=k;
    }
    assert([s rangeAtIndex:runs].location==NSNotFound);
    for (NSUInteger q=0;q<=n;q++) {
        NSUInteger lt=NSNotFound, le=NSNotFound, gt=NSNotFound, ge=NSNotFound;
        for (NSUInteger j=0;j<count;j++) {
            NSUInteger i=expected[j];
            if (i<q) lt=i;
            if (i<=q) le=i;
            if (i>q && gt==NSNotFound) gt=i;
            if (i>=q && ge==NSNotFound) ge=i;
        }
        assert([s indexLessThanIndex:q]==lt && [s indexLessThanOrEqualToIndex:q]==le);
        assert([s indexGreaterThanIndex:q]==gt && [s indexGreaterThanOrEqualToIndex:q]==ge);
    }
}
enum { RACERS = 8, RACE_RANGES = 200 };
static NSIndexSet *race_set;
static pthread_barrier_t race_start;
static NSUInteger race_results[RACERS][4];
static void *racer(void *arg) {
    NSUInteger *out = race_results[(intptr_t)arg];
    pthread_barrier_wait(&race_start);
    // First use from every thread at once: each may build a cache; exactly one may be kept.
    out[0]=[race_set indexGreaterThanIndex:101]; out[1]=[race_set indexLessThanIndex:101];
    out[2]=[race_set indexGreaterThanOrEqualToIndex:398]; out[3]=[race_set count];
    return NULL;
}
static void race_immutable_first_use(void) {
    NSMutableIndexSet *m=fragmented(RACE_RANGES);
    size_t lost=0, rounds=0, held=outstanding;
    pthread_barrier_init(&race_start,NULL,RACERS);
    // At least 2000 rounds, and keep going (bounded) until a lost publication race was seen,
    // so a pass shows the compare-and-swap loser path ran.
    for (; rounds<2000 || (lost==0 && rounds<50000); rounds++) {
        race_set=[[NSIndexSet alloc] initWithIndexSet:m];
        size_t base=arrays, objects=outstanding;
        pthread_t t[RACERS];
        for (intptr_t i=0;i<RACERS;i++) assert(!pthread_create(&t[i],NULL,racer,(void *)i));
        for (int i=0;i<RACERS;i++) assert(!pthread_join(t[i],NULL));
        for (int i=0;i<RACERS;i++) {
            assert(race_results[i][0]==102 && race_results[i][1]==100);
            assert(race_results[i][2]==398 && race_results[i][3]==RACE_RANGES);
        }
        if (live_arrays!=1 || outstanding-objects!=2) {
            printf("round %zu: %zu caches built, %zu still live, %zu new allocations outstanding\n",
                   rounds,arrays-base,live_arrays,outstanding-objects);
            assert(live_arrays==1 && outstanding-objects==2); // one kept cache: struct + array
        }
        lost+=arrays-base-1;
        [race_set release]; assert(!live_arrays && outstanding==held);
    }
    pthread_barrier_destroy(&race_start);
    printf("%zu rounds x %d threads: %zu losing caches built and freed, 1 kept per round\n",
           rounds,RACERS,lost);
    assert(lost>0); // the race was exercised
    [m release];
}
int main(int argc, char **argv) {
    assert(argc==2); setbuf(stdout,NULL);
    if (!strcmp(argv[1],"original")) return original_main();
    if (!strcmp(argv[1],"threads")) race_immutable_first_use(); else
    if (!strcmp(argv[1],"leak")) {
        /* Reviewer reproducer (REVIEW-codex.md fix 6, native-cache-check.c): 1001 complete
         * copies from a two-range set. On 76ca1c5 every lookup built and dropped a cache. */
        NSMutableIndexSet *s=fragmented(2); NSUInteger b[2]; size_t before=arrays, held=outstanding;
        for (unsigned i=0;i<1001;i++) assert([s getIndexes:b maxCount:2 inIndexRange:NULL]==2 && b[0]==0 && b[1]==2);
        printf("1001 copies: arrays allocated=%zu live=%zu new outstanding allocations=%zu\n",
               arrays-before,live_arrays,outstanding-held);
        assert(arrays-before<=1 && outstanding-held<=2); // at most one cache struct + its array
        for (unsigned i=0;i<1001;i++) {
            assert([s indexGreaterThanIndex:0]==2); assert([s indexLessThanIndex:2]==0);
        }
        assert(arrays-before==1 && live_arrays==1 && outstanding-held==2);
        printf("2002 neighbour queries: total arrays allocated=%zu live=%zu\n",arrays-before,live_arrays);
        assert([s count]==2); // cache count is initialised, not malloc garbage
        [s release];
    } else if (!strcmp(argv[1],"fragmented")) {
        NSUInteger sizes[]={33,31,32,64,65,129};
        for (unsigned t=0;t<sizeof(sizes)/sizeof(*sizes);t++) {
            NSMutableIndexSet *s=fragmented(sizes[t]); NSUInteger b[256];
            // Reviewer reproducer: {0,2,...,64} by addIndex, then getIndexes maxCount 1
            // (33 ranges overflowed the 32-entry builder stack array on 76ca1c5).
            assert([s getIndexes:b maxCount:1 inIndexRange:NULL]==1 && b[0]==0);
            unsigned char members[512]={0};
            for (NSUInteger i=0;i<sizes[t];i++) members[2*i]=1;
            check_members(s,members,512);
            NSRange r=NSMakeRange(1,2*sizes[t]); NSUInteger copied=0, n;
            while ((n=[s getIndexes:b maxCount:7 inIndexRange:&r])) {
                for (NSUInteger j=0;j<n;j++) assert(b[j]==2*(++copied));
            }
            assert(copied==sizes[t]-1); [s release]; assert(!outstanding && !live_arrays);
        }
    } else if (!strcmp(argv[1],"mutation")) {
        NSMutableIndexSet *s=fragmented(33); unsigned char m[512]={0};
        for (unsigned i=0;i<33;i++) m[2*i]=1;
        check_members(s,m,512);
        size_t before=arrays;
        [s addIndex:100]; m[100]=1; assert(!live_arrays); check_members(s,m,512); assert(arrays==before+1);
        [s removeIndex:20]; m[20]=0; assert(!live_arrays); check_members(s,m,512);
        [s shiftIndexesStartingAtIndex:0 by:3];
        for (int i=511;i>=0;i--) m[i]=i>=3?m[i-3]:0;
        assert(!live_arrays); check_members(s,m,512);
        [s removeAllIndexes]; assert(!live_arrays); memset(m,0,sizeof(m)); check_members(s,m,512);
        [s addIndexesInRange:NSMakeRange(3,6)]; memset(m+3,1,6); check_members(s,m,512);
        [s removeIndex:5]; m[5]=0; check_members(s,m,512); // split a single range
        [s addIndex:5]; m[5]=1; assert(!live_arrays); check_members(s,m,512); // merge to single
        [s shiftIndexesStartingAtIndex:6 by:10]; // split a single range by shifting
        memset(m,0,sizeof(m)); memset(m+3,1,3); memset(m+16,1,3); check_members(s,m,512);
        [s removeIndex:4]; m[4]=0; assert(!live_arrays); check_members(s,m,512); // split within a multi-range list
        [s release];
    } else if (!strcmp(argv[1],"failure")) {
        for (long fail=0;fail<3;fail++) {
            NSMutableIndexSet *s=fragmented(65); size_t before=outstanding;
            fail_after=fail; assert([s indexGreaterThanIndex:0]==2); fail_after=-1;
            assert(outstanding==before && !live_arrays); // failed cache falls back without leaking
            assert([s count]==65 && live_arrays==1); [s release]; assert(!outstanding);
        }
    } else if (!strcmp(argv[1],"bulk")) {
        NSMutableIndexSet *s=[NSMutableIndexSet new];
        [s addIndexesInRange:NSMakeRange(3,10000)]; [s addIndex:20000];
        NSUInteger b[10001]; size_t before=allocations, reads=array_reads;
        NSRange r=NSMakeRange(0,30000);
        assert([s getIndexes:b maxCount:10001 inIndexRange:&r]==10001);
        assert(b[0]==3 && b[9999]==10002 && b[10000]==20000 && r.location==20001 && r.length==9999);
        assert(allocations==before && array_reads==reads); // no cache or per-index binary search
        NSRange unchanged=NSMakeRange(10003,1); r=unchanged;
        assert(![s getIndexes:b maxCount:5 inIndexRange:&r] && !memcmp(&r,&unchanged,sizeof(r)));
        assert(![s getIndexes:NULL maxCount:0 inIndexRange:NULL]); [s release];
    } else abort();
    printf("%s: outstanding allocations=%zu live arrays=%zu\n",argv[1],outstanding,live_arrays);
    assert(!outstanding && !live_arrays); return 0;
}
