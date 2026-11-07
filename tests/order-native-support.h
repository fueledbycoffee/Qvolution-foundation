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
#include <limits.h>
#include <objc/message.h>
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
+ (id)alloc; + (id)class; - (id)init; - (id)retain; - (id)autorelease; - (void)release; - (void)dealloc; - (id)copy; - (id)description; - (BOOL)isEqual:(id)o; - (BOOL)isKindOfClass:(Class)c;
- (BOOL)isNSString__; - (BOOL)isNSNumber__;
@end
@implementation NSObject
+ (id)alloc { NSObject *o=class_createInstance(self,0);o->retains=1;return o; }
+ (id)class { return self; }
- (id)init { return self; }
- (id)retain { ++retains;return self; }
- (id)autorelease { return self; }
- (void)release { if(--retains==0){[self dealloc];object_dispose(self);} }
- (void)dealloc {}
- (id)copy { return [self retain]; }
- (id)description { return self; }
- (BOOL)isKindOfClass:(Class)c { for(Class k=object_getClass(self);k;k=class_getSuperclass(k))if(k==c)return YES;return NO; }
- (BOOL)isEqual:(id)o { return self==o; }
- (void)performSelector:(SEL)s withObject:(id)o { ((void(*)(id,SEL,id))objc_msg_lookup(self,s))(self,s,o); }
- (BOOL)isNSString__ { return NO; }
- (BOOL)isNSArray__ { return NO; }
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
- (BOOL)isKindOfClass:(Class)c { return c==objc_getClass("NSString")||c==objc_getClass("NSObject")||c==object_getClass(self); }
- (id)retain { return self; }
- (void)release {}
- (id)autorelease { return self; }
- (NSUInteger)length { return decode(text,byteCount,NULL); }
- (unichar)characterAtIndex:(NSUInteger)i { unichar out[1024];assert(byteCount<1024);decode(text,byteCount,out);return out[i]; }
@end
@interface NSArray : NSObject { @public id items[128]; NSUInteger count; }
+ (id)arrayWithObjects:(const id *)a count:(NSUInteger)n; - (id)initWithArray:(NSArray *)a;
- (NSUInteger)count; - (id)objectAtIndex:(NSUInteger)i; - (id)lastObject;
- (void)addObject:(id)x; - (void)removeObjectAtIndex:(NSUInteger)i; - (void)removeObject:(id)x;
- (void)addObjectsFromArray:(NSArray *)a;
- (BOOL)containsObject:(id)o; - (id)firstObject; - (id)copy;
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)s objects:(id *)b count:(NSUInteger)n;
- (id)indexesOfObjectsPassingTest:(BOOL (^)(id,NSUInteger,BOOL *))p;
- (void)removeObjectsAtIndexes:(NSArray *)indexes;
@end
@interface NativeIndex : NSObject { @public NSUInteger index; } @end
@implementation NativeIndex @end
@implementation NSArray
+ (id)arrayWithObjects:(const id *)a count:(NSUInteger)n { NSArray *o=[self alloc];for(NSUInteger i=0;i<n;i++)[o addObject:a[i]];return o; }
- (id)initWithArray:(NSArray *)a { for(NSUInteger i=0;i<[a count];i++)[self addObject:[a objectAtIndex:i]];return self; }
- (BOOL)isNSArray__ { return YES; }
- (id)copy { return [[NSArray alloc] initWithArray:self]; }
- (id)firstObject { return count?items[0]:nil; }
- (BOOL)containsObject:(id)o { for(NSUInteger i=0;i<count;i++)if([items[i] isEqual:o])return YES;return NO; }
- (void)dealloc { while(count)[self removeObjectAtIndex:count-1];[super dealloc]; }
- (NSUInteger)count { return count; }
- (id)objectAtIndex:(NSUInteger)i { assert(i<count);return items[i]; }
- (id)lastObject { return count?items[count-1]:nil; }
- (void)addObject:(id)x { assert(x&&count<128);items[count++]=[x retain]; }
- (void)removeObjectAtIndex:(NSUInteger)i { assert(i<count);id x=items[i];memmove(items+i,items+i+1,(--count-i)*sizeof(id));[x release]; }
- (void)removeObject:(id)x { for(NSUInteger i=count;i>0;i--)if(items[i-1]==x)[self removeObjectAtIndex:i-1]; }
- (void)addObjectsFromArray:(NSArray *)a { for(NSUInteger i=0;i<a->count;i++)[self addObject:a->items[i]]; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)s objects:(id *)b count:(NSUInteger)n {
 if(s->state)return 0;s->state=1;s->itemsPtr=items;s->mutationsPtr=&s->extra[0];return count;
}
- (id)indexesOfObjectsPassingTest:(BOOL (^)(id,NSUInteger,BOOL *))p {
 NSArray *a=[NSArray alloc];BOOL stop=NO;for(NSUInteger i=0;i<count;i++)if(p(items[i],i,&stop)){NativeIndex *v=[NativeIndex alloc];v->index=i;[a addObject:v];[v release];}return a;
}
- (void)removeObjectsAtIndexes:(NSArray *)a { for(NSUInteger i=a->count;i>0;i--)[self removeObjectAtIndex:((NativeIndex *)a->items[i-1])->index]; }
@end
#define NSIndexSet NSArray
@interface NSMutableArray : NSArray @end
@implementation NSMutableArray @end
@interface NSMutableIndexSet : NSArray
+ (id)indexSet;
- (void)addIndex:(NSUInteger)i;
@end
@implementation NSMutableIndexSet
+ (id)indexSet { return [self alloc]; }
- (void)addIndex:(NSUInteger)i { NativeIndex *v=[NativeIndex alloc];v->index=i;[self addObject:v];[v release]; }
@end
@implementation NSString
+ (id)initialize {
 if(self==[NSString class]) {
  Class c=objc_getClass("NativeConstantString");
  Class parents[]={self,objc_getClass("NSObject")};
  for(int i=0;i<2;i++){unsigned count=0;Method *methods=class_copyMethodList(parents[i],&count);
   for(unsigned j=0;j<count;j++)class_addMethod(c,method_getName(methods[j]),method_getImplementation(methods[j]),method_getTypeEncoding(methods[j]));free(methods);}
 }return self;
}
+ (id)stringWithCharacters:(const unichar *)c length:(NSUInteger)n { return [[self alloc] initWithCharacters:c length:n]; }
- (id)initWithCharacters:(const unichar *)c length:(NSUInteger)n { units=malloc((n+1)*2);memcpy(units,c,n*2);size=n;return self; }
- (BOOL)isNSString__ { return YES; }
- (BOOL)isEqual:(id)o { return [self isEqualToString:o]; }
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
