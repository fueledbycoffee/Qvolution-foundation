/* Linux collection doubles: production difference methods are compiled verbatim.
 * These doubles do not verify the CF class cluster or retain/autorelease behavior. */
#include <objc/runtime.h>
#include <objc/message.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define NS_ENUM(t,n) t n; enum
#define NS_OPTIONS(t,n) t n; enum
#define nullable
#define NSUIntegerMax ULONG_MAX
#include <limits.h>
typedef unsigned long NSUInteger;
typedef long NSInteger;
typedef NSInteger NSComparisonResult;
enum { NSOrderedAscending=-1, NSOrderedSame=0, NSOrderedDescending=1 };
#define NSNotFound LONG_MAX
typedef NSComparisonResult (^NSComparator)(id,id);
typedef struct { unsigned long state; id *itemsPtr; unsigned long *mutationsPtr; unsigned long extra[5]; } NSFastEnumerationState;
@protocol NSFastEnumeration
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)objects count:(NSUInteger)count;
@end
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
+ (id)new;
+ (Class)class;
+ (BOOL)instancesRespondToSelector:(SEL)selector;
- (Class)class;
- (id)init;
- (id)retain;
- (id)autorelease;
- (void)release;
- (void)dealloc;
- (BOOL)isKindOfClass:(Class)c;
- (BOOL)isEqual:(id)object;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self,0); }
+ (id)new { return [[self alloc] init]; }
+ (Class)class { return self; }
+ (BOOL)instancesRespondToSelector:(SEL)s { return class_getInstanceMethod(self,s)!=NULL; }
- (Class)class { return object_getClass(self); }
- (id)init { return self; }
- (id)retain { return self; }
- (id)autorelease { return self; }
- (void)release {}
- (void)dealloc {}
- (BOOL)isKindOfClass:(Class)c { for(Class x=object_getClass(self);x;x=class_getSuperclass(x)) if(x==c)return YES;return NO; }
- (BOOL)isEqual:(id)o { return self==o; }
@end
@interface FixtureString : NSObject { @public const char *text; unsigned int length; }
@end
@implementation FixtureString
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[FixtureString class]] && !strcmp(text,((FixtureString *)o)->text); }
@end
@interface NSException : NSObject
+ (void)raise:(id)name format:(id)format;
@end
@implementation NSException
+ (void)raise:(id)name format:(id)format { @throw [self new]; }
@end
#define NSInvalidArgumentException @"invalid"
#define NSMallocException @"malloc"
@interface NSArray<__covariant ObjectType> : NSObject <NSFastEnumeration> { @public id *storage; NSUInteger size; }
+ (id)array;
+ (id)arrayWithArray:(NSArray *)a;
+ (id)arrayWithObjects:(const id[])objects count:(NSUInteger)count;
- (NSUInteger)count;
- (id)objectAtIndex:(NSUInteger)index;
- (id)copy;
- (id)mutableCopy;
- (id)sortedArrayUsingComparator:(NSComparator)comparator;
- (id)reverseObjectEnumerator;
@end
@interface NSMutableArray<ObjectType> : NSArray<ObjectType>
- (void)addObject:(id)object;
- (void)addObjectsFromArray:(NSArray *)array;
- (void)removeObjectAtIndex:(NSUInteger)index;
- (void)insertObject:(id)object atIndex:(NSUInteger)index;
@end
@implementation NSArray
+ (id)array { return [self new]; }
+ (id)arrayWithArray:(NSArray *)a { return [self arrayWithObjects:a->storage count:a->size]; }
+ (id)arrayWithObjects:(const id[])a count:(NSUInteger)n { NSArray *r=[self new];r->size=n;r->storage=calloc(n+1,sizeof(id));if(n)memcpy(r->storage,a,n*sizeof(id));return r; }
- (NSUInteger)count { return size; }
- (id)objectAtIndex:(NSUInteger)i { assert(i<size);return storage[i]; }
- (id)copy { return [NSArray arrayWithArray:self]; }
- (id)mutableCopy { return [NSMutableArray arrayWithArray:self]; }
- (id)sortedArrayUsingComparator:(NSComparator)c { NSArray *r=[self copy];for(NSUInteger i=1;i<size;i++)for(NSUInteger j=i;j>0&&c(r->storage[j-1],r->storage[j])>0;j--){id t=r->storage[j];r->storage[j]=r->storage[j-1];r->storage[j-1]=t;}return r; }
- (id)reverseObjectEnumerator { NSMutableArray *r=[NSMutableArray array];for(NSUInteger i=size;i;i--)[r addObject:storage[i-1]];return r; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)s objects:(id *)buffer count:(NSUInteger)n { if(s->state>=size)return 0;NSUInteger left=size-s->state;n=n<left?n:left;s->itemsPtr=storage+s->state;s->mutationsPtr=&s->extra[0];s->state+=n;return n; }
@end
@implementation NSMutableArray
- (void)addObject:(id)o { assert(o);storage=realloc(storage,(size+1)*sizeof(id));storage[size++]=o; }
- (void)addObjectsFromArray:(NSArray *)a { for(id o in a)[self addObject:o]; }
- (void)removeObjectAtIndex:(NSUInteger)i { assert(i<size);memmove(storage+i,storage+i+1,(size-i-1)*sizeof(id));size--; }
- (void)insertObject:(id)o atIndex:(NSUInteger)i { assert(o&&i<=size);storage=realloc(storage,(size+1)*sizeof(id));memmove(storage+i+1,storage+i,(size-i)*sizeof(id));storage[i]=o;size++; }
@end
@interface NSIndexSet : NSObject { @public NSUInteger *indexes,n; }
+ (id)indexSetWithIndex:(NSUInteger)i;
- (NSUInteger)count;
- (NSUInteger)firstIndex;
- (NSUInteger)indexGreaterThanIndex:(NSUInteger)i;
@end
@implementation NSIndexSet
+ (id)indexSetWithIndex:(NSUInteger)i { NSIndexSet *s=[self new];s->indexes=malloc(sizeof(NSUInteger));s->indexes[0]=i;s->n=1;return s; }
- (NSUInteger)count { return n; }
- (NSUInteger)firstIndex { return n?indexes[0]:NSNotFound; }
- (NSUInteger)indexGreaterThanIndex:(NSUInteger)i { for(NSUInteger j=0;j<n;j++)if(indexes[j]>i)return indexes[j];return NSNotFound; }
@end
@class NSOrderedCollectionDifference;
@interface NSOrderedSet : NSObject { NSArray *values; }
+ (id)orderedSetWithArray:(NSArray *)a;
- (NSArray *)array;
- (NSUInteger)count;
- (id)objectAtIndex:(NSUInteger)i;
- (NSUInteger)indexOfObject:(id)o;
@end
@implementation NSOrderedSet
+ (id)orderedSetWithArray:(NSArray *)a { NSOrderedSet *s=[self new];NSMutableArray *v=[NSMutableArray array];s->values=v;for(id o in a)if([s indexOfObject:o]==NSNotFound)[v addObject:o];return s; }
- (NSArray *)array { return values; }
- (NSUInteger)count { return [values count]; }
- (id)objectAtIndex:(NSUInteger)i { return [values objectAtIndex:i]; }
- (NSUInteger)indexOfObject:(id)o { for(NSUInteger i=0;i<[values count];i++)if([[values objectAtIndex:i]isEqual:o])return i;return NSNotFound; }
@end
void *_NSConcreteGlobalBlock[32];
void *_NSConcreteStackBlock[32];
