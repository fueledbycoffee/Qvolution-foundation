/* Minimal native test doubles. Production parser, decimal math and selected
 * methods are included verbatim by run-native.py; no Foundation runtime is
 * substituted in the shipped libraries. Lifetime/CF class identity require qv-diff. */
#include <objc/runtime.h>
#include <objc/message.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdbool.h>
#include <limits.h>
#include <float.h>
#include <math.h>
#include <errno.h>
#include <ctype.h>
#include <assert.h>
#include <unicode/uregex.h>
#undef YES
#undef NO
#define YES __objc_yes
#define NO __objc_no
@protocol NSDecimalNumberBehaviors @end
typedef unsigned long NSUInteger;
typedef long NSInteger;
typedef unsigned short unichar;
typedef long NSComparisonResult;
typedef struct { NSUInteger location, length; } NSRange;
#define NSOrderedAscending (-1)
#define NSOrderedSame 0
#define NSOrderedDescending 1
#define NSNotFound ULONG_MAX
#define NSUTF8StringEncoding 4
#define NSJSONReadingMutableContainers 1
#define NSJSONReadingMutableLeaves 2
#define NSJSONReadingAllowFragments 4
#define NSPropertyListReadCorruptError 3840
#define NSFormattingError 2048
#define NSAssert(c,...) assert(c)
#define NSDataBase64DecodingIgnoreUnknownCharacters 1
typedef NSUInteger NSDataBase64DecodingOptions;
#define FALSE 0
#define TRUE 1
#define DEBUG_LOG(...) ((void)0)
typedef unsigned long dispatch_once_t;
static void dispatch_once(dispatch_once_t *v, void (^b)(void)) { if(!*v){*v=1;b();} }
// Stack blocks never escape synchronous ICU callbacks in this fixture.
void *_NSConcreteStackBlock[32], *_NSConcreteGlobalBlock[32];
void _Block_object_dispose(const void *p,int flags) {}
void _Block_object_assign(void *p,const void *v,int flags) { *(const void **)p=v; }

#define NSDecimalMaxSize 8
#define NSDecimalNoScale SHRT_MAX
#define MIN(a,b) ((a)<(b)?(a):(b))
#define MAX(a,b) ((a)>(b)?(a):(b))
typedef NSUInteger NSJSONReadingOptions;
typedef enum { NSRoundPlain, NSRoundDown, NSRoundUp, NSRoundBankers } NSRoundingMode;
typedef enum { NSCalculationNoError, NSCalculationLossOfPrecision, NSCalculationUnderflow, NSCalculationOverflow, NSCalculationDivideByZero } NSCalculationError;
typedef struct { signed int _exponent:8; unsigned int _length:4, _isNegative:1, _isCompact:1, _reserved:18; unsigned short _mantissa[8]; } NSDecimal;
static BOOL NSDecimalIsNotANumber(const NSDecimal *v) { return !v->_length && v->_isNegative; }
static NSUInteger NSMaxRange(NSRange r) { return r.location+r.length; }
static NSRange NSMakeRange(NSUInteger a, NSUInteger b) { return (NSRange){a,b}; }
typedef struct { unsigned long state; id *itemsPtr; unsigned long *mutationsPtr; unsigned long extra[5]; } NSFastEnumerationState;
@protocol NSFastEnumeration
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)s objects:(id *)b count:(NSUInteger)n;
@end
@class NSString, NSArray, NSDictionary, NSNumber, NSDecimalNumber, NSData, NSEnumerator, NSSet, NSMutableSet, NSCharacterSet;
__attribute__((objc_root_class)) @interface NSObject { Class isa; }
+ (id)alloc; + (id)new; + (Class)class;
- (id)init; + (id)allocWithZone:(void *)zone; - (id)retain; - (id)autorelease; - (void)release;
- (BOOL)isEqual:(id)o; - (BOOL)isKindOfClass:(Class)c;
- (BOOL)isNSString__; - (BOOL)isNSNumber__; - (BOOL)isNSArray__; - (BOOL)isNSDictionary__;
- (NSUInteger)hash; - (id)copy;
- (id)valueForKey:(id)key; - (id)valueForKeyPath:(id)key; - (void)setValue:(id)v forKey:(id)k;
@end
@interface NSString : NSObject { @public unichar *chars; NSUInteger count; }
+ (id)stringWithUTF8String:(const char *)s;
+ (id)stringWithString:(NSString *)s;
- (id)initWithData:(id)d encoding:(int)e;
- (id)initWithCharacters:(const unichar *)s length:(NSUInteger)n;
- (id)initWithCharactersNoCopy:(unichar *)s length:(NSUInteger)n freeWhenDone:(BOOL)b;
- (NSUInteger)length; - (void)getCharacters:(unichar *)b range:(NSRange)r;
- (const char *)UTF8String;
- (void)appendString:(NSString *)s; - (void)appendFormat:(NSString *)s,...;
- (id)objectForKey:(id)k;
- (id)stringByTrimmingCharactersInSet:(id)s;
- (unichar)characterAtIndex:(NSUInteger)i;
- (id)substringWithRange:(NSRange)r;
- (id)mutableCopy;
- (void)insertString:(id)s atIndex:(NSUInteger)i;
- (void)replaceCharactersInRange:(NSRange)r withString:(id)s;
- (void)setString:(id)s;
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)s;
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)s options:(NSUInteger)o range:(NSRange)r;
@end
@interface NSConstantString : NSString @end
@interface NSMutableString : NSString @end
@interface NSArray : NSObject <NSFastEnumeration> { @public id items[512]; NSUInteger count; }
+ (id)arrayWithObject:(id)o; - (id)initWithObjects:(const id *)o count:(NSUInteger)n;
+ (id)array; + (id)arrayWithArray:(NSArray *)a; + (id)arrayWithCapacity:(NSUInteger)n;
- (id)objectEnumerator;
+ (id)arrayWithObjects:(const id *)o count:(NSUInteger)n;
- (NSUInteger)count; - (id)objectAtIndex:(NSUInteger)i;
@end
@interface NSMutableArray : NSArray
- (void)addObject:(id)o; - (void)addObjectsFromArray:(NSArray *)a;
@end
@interface NSDictionary : NSObject <NSFastEnumeration> { @public id keys[512], values[512]; NSUInteger count; }
+ (id)dictionaryWithObjects:(const id *)o forKeys:(const id *)k count:(NSUInteger)n;
- (id)objectForKey:(id)k; - (id)objectForKeyedSubscript:(id)k; - (NSUInteger)count;
@end
@interface NSMutableDictionary : NSDictionary @end
@interface NSEnumerator : NSObject { @public NSArray *array; NSUInteger index; }
- (id)nextObject;
@end
@interface NSSet : NSArray
+ (id)setWithArray:(NSArray *)a; + (id)set;
- (id)allObjects;
@end
@interface NSMutableSet : NSSet
- (void)addObject:(id)o; - (void)unionSet:(NSSet *)s;
@end
@interface NSNumberFormatter : NSObject { @public BOOL decimal; NSDictionary *_attributes; void *_formatter; }
- (id)numberFromString:(NSString *)s;
- (BOOL)getObjectValue:(id *)o forString:(NSString *)s range:(NSRange *)r error:(id *)e;
@end
@interface NSData : NSObject { @public uint8_t *bytes; NSUInteger length; }
- (NSUInteger)length;
- (void)enumerateByteRangesUsingBlock:(void (^)(const void *, NSRange, BOOL *))block;
- (id)initWithBytesNoCopy:(void *)b length:(NSUInteger)n freeWhenDone:(BOOL)f;
- (id)initWithBase64EncodedData:(NSData *)d options:(NSUInteger)o;
@end
@interface NSExpression : NSObject { @public id constant; }
+ (id)expressionForConstantValue:(id)v;
@end
@interface NSVariableExpression : NSExpression { id _variable; }
- (id)variable; - (id)_expressionWithSubstitutionVariables:(NSDictionary *)v;
@end
@interface NSCharacterSet : NSObject { @public BOOL members[256]; }
+ (id)whitespaceAndNewlineCharacterSet;
+ (id)characterSetWithCharactersInString:(NSString *)s;
@end
@interface NSNull : NSObject + (id)null; @end
@interface NSNumber : NSObject { @public double value; int cfType; long long signedStorage; }
+ (id)numberWithBool:(BOOL)v; + (id)numberWithInt:(int)v;
- (id)initWithDouble:(double)v; - (id)initWithLongLong:(long long)v; - (id)initWithUnsignedLongLong:(unsigned long long)v;
- (BOOL)boolValue; - (NSComparisonResult)compare:(id)o; - (double)doubleValue; - (id)stringValue;
@end
@interface NSDecimalNumber : NSNumber { @public NSDecimal dec; }
- (id)initWithMantissa:(unsigned long long)m exponent:(short)e isNegative:(BOOL)n;
+ (id)notANumber;
+ (id)decimalNumberWithDecimal:(NSDecimal)d;
- (id)initWithDecimal:(NSDecimal)d;
- (id)initWithString:(NSString *)s; - (id)initWithString:(NSString *)s locale:(id)l;
- (NSDecimal)decimalValue; - (NSString *)description; - (NSString *)stringValue;
- (id)decimalNumberByAdding:(id)o withBehavior:(id)b;
@end
@interface NSValue : NSObject { @public int stored; }
- (const char *)objCType; - (void)getValue:(void *)v; - (void)getValue:(void *)v size:(NSUInteger)s;
@end
static void NSGetSizeAndAlignment(const char *t, NSUInteger *s, void *a) { assert(!strcmp(t,"i"));*s=sizeof(int); }
@interface NSScanner : NSObject { NSString *input; }
- (id)initWithString:(NSString *)s; - (void)setLocale:(id)l; - (BOOL)scanDecimal:(NSDecimal *)d;
@end
@interface NSLocale : NSObject @end
@interface NSError : NSObject { @public NSInteger _code; NSString *_domain; NSDictionary *_userInfo; }
+ (id)errorWithDomain:(id)d code:(NSInteger)c userInfo:(id)u;
- (id)domain; - (NSInteger)code; - (id)userInfo; + (id)_outOfMemoryError;
@end
@interface NSException : NSObject
+ (void)raise:(id)n format:(id)f,...;
+ (id)exceptionWithName:(id)n reason:(id)r userInfo:(id)u;
@end
@interface _NSJSONReader : NSObject { id input; NSJSONReadingOptions kind; NSError *error; }
+ (BOOL)validForJSON:(id)o depth:(NSUInteger)d allowFragments:(BOOL)f;
- (id)parseUTF8JSONData:(id)d skipBytes:(NSUInteger)n options:(NSUInteger)o;
- (void)setError:(NSError *)e; - (NSError *)error;
@end
static id NSLocaleDecimalSeparator, NSCocoaErrorDomain, NSLocalizedDescriptionKey, NSInvalidArgumentException, NSRangeException, NSMallocException;
@implementation NSObject
+ (id)alloc { return class_createInstance(self,0); }
+ (id)allocWithZone:(void *)zone { return [self alloc]; }
+ (id)new { return [[self alloc] init]; }
+ (Class)class { return self; }
- (id)init { return self; } - (id)retain { return self; } - (id)autorelease { return self; } - (void)release {}
- (id)copy { return self; }
- (id)valueForKey:(id)k { return [k isEqual:@"self"] ? self : nil; }
- (id)valueForKeyPath:(id)k { return [self valueForKey:k]; }
- (void)setValue:(id)v forKey:(id)k { @throw [NSException new]; }
- (BOOL)isEqual:(id)o { return self==o; }
- (NSUInteger)hash { return (NSUInteger)self; }
- (BOOL)isKindOfClass:(Class)c { for(Class k=object_getClass(self); k; k=class_getSuperclass(k)) if(k==c) return YES; return NO; }
- (BOOL)isNSString__ { return [self isKindOfClass:[NSString class]]; }
- (BOOL)isNSNumber__ { return [self isKindOfClass:[NSNumber class]]; }
- (BOOL)isNSArray__ { return [self isKindOfClass:[NSArray class]]; }
- (BOOL)isNSDictionary__ { return [self isKindOfClass:[NSDictionary class]]; }
@end
@implementation NSString
- (id)stringByTrimmingCharactersInSet:(id)s { NSUInteger start=0,end=[self length];while(start<end && isspace([self characterAtIndex:start]))start++;while(end>start && isspace([self characterAtIndex:end-1]))end--;return [self substringWithRange:NSMakeRange(start,end-start)]; }
- (unichar)characterAtIndex:(NSUInteger)i { unichar c;[self getCharacters:&c range:NSMakeRange(i,1)];return c; }
- (id)substringWithRange:(NSRange)r { unichar c[r.length];[self getCharacters:c range:r];return [[[NSString alloc] initWithCharacters:c length:r.length] autorelease]; }
- (id)mutableCopy { return [NSMutableString stringWithString:self]; }
- (void)insertString:(id)s atIndex:(NSUInteger)i { [self replaceCharactersInRange:NSMakeRange(i,0) withString:s]; }
- (void)replaceCharactersInRange:(NSRange)r withString:(NSString *)s { NSUInteger n=[s length];assert(NSMaxRange(r)<=count);chars=realloc(chars,(count+n+1)*2);memmove(chars+r.location+n,chars+NSMaxRange(r),(count-NSMaxRange(r))*2);[s getCharacters:chars+r.location range:NSMakeRange(0,n)];count=count-r.length+n;chars[count]=0; }
- (void)setString:(id)s { [self replaceCharactersInRange:NSMakeRange(0,count) withString:s]; }
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)s { return [self rangeOfCharacterFromSet:s options:0 range:NSMakeRange(0,[self length])]; }
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)s options:(NSUInteger)o range:(NSRange)r { for(NSUInteger i=r.location;i<MIN(NSMaxRange(r),[self length]);i++) { unichar c=[self characterAtIndex:i];if(c<256 && s->members[c])return NSMakeRange(i,1); } return NSMakeRange(NSNotFound,0); }
+ (id)stringWithUTF8String:(const char *)s { NSUInteger n=strlen(s); unichar b[n]; for(NSUInteger i=0;i<n;i++)b[i]=(unsigned char)s[i]; return [[[self alloc] initWithCharacters:b length:n] autorelease]; }
+ (id)stringWithString:(NSString *)s { NSUInteger n=[s length]; unichar b[n]; [s getCharacters:b range:NSMakeRange(0,n)]; return [[[self alloc] initWithCharacters:b length:n] autorelease]; }
- (id)initWithData:(id)d encoding:(int)e { return [NSString stringWithString:d]; }
- (id)initWithCharacters:(const unichar *)s length:(NSUInteger)n { chars=malloc((n+1)*2); memcpy(chars,s,n*2); chars[n]=0; count=n; return self; }
- (id)initWithCharactersNoCopy:(unichar *)s length:(NSUInteger)n freeWhenDone:(BOOL)b { return [self initWithCharacters:s length:n]; }
- (NSUInteger)length { return count; }
- (void)getCharacters:(unichar *)b range:(NSRange)r { assert(r.location+r.length<=count); memcpy(b,chars+r.location,r.length*2); }
- (const char *)UTF8String { NSUInteger n=[self length]; unichar b[n]; [self getCharacters:b range:NSMakeRange(0,n)]; char *out=calloc(n+1,1); for(NSUInteger i=0;i<n;i++) out[i]=(char)b[i]; return out; }
- (BOOL)isEqual:(id)o { if (![o isNSString__] || [self length]!=[o length]) return NO; NSUInteger n=[self length]; unichar a[n],b[n]; [self getCharacters:a range:NSMakeRange(0,n)]; [o getCharacters:b range:NSMakeRange(0,n)]; return !memcmp(a,b,n*2); }
- (NSUInteger)hash { const char *s=[self UTF8String]; NSUInteger h=0; while(*s)h=h*31+*s++; return h; }
- (void)appendString:(NSString *)s { NSUInteger n=[s length]; chars=realloc(chars,(count+n+1)*2); [s getCharacters:chars+count range:NSMakeRange(0,n)]; count+=n; chars[count]=0; }
- (void)appendFormat:(NSString *)s,... { va_list a;va_start(a,s);char out[256];vsnprintf(out,sizeof(out),[s UTF8String],a);va_end(a);[self appendString:[NSString stringWithUTF8String:out]]; }
- (id)objectForKey:(id)k { return nil; }
@end
@implementation NSConstantString
- (NSUInteger)length { return count; }
- (void)getCharacters:(unichar *)b range:(NSRange)r { assert(r.location+r.length<=count);for(NSUInteger i=0;i<r.length;i++) b[i]=((const char *)chars)[r.location+i]; }
@end
@implementation NSMutableString
+ (id)string { return [self stringWithUTF8String:""]; }
@end
@implementation NSCharacterSet
+ (id)whitespaceAndNewlineCharacterSet { return [self characterSetWithCharactersInString:@" \t\n\r"]; }
+ (id)characterSetWithCharactersInString:(NSString *)s { NSCharacterSet *c=[self new];for(NSUInteger i=0;i<[s length];i++){ unichar v=[s characterAtIndex:i];if(v<256)c->members[v]=YES; }return c; }
@end
@implementation NSArray
- (id)initWithObjects:(const id *)o count:(NSUInteger)n { count=n;memcpy(items,o,n*sizeof(id));return self; }
#include "array-constructor.inc"
+ (id)array { return [self new]; }
+ (id)arrayWithArray:(NSArray *)a { return [self arrayWithObjects:a->items count:a->count]; }
+ (id)arrayWithCapacity:(NSUInteger)n { return [self new]; }
- (id)objectEnumerator { NSEnumerator *e=[NSEnumerator new];e->array=self;return e; }
+ (id)arrayWithObjects:(const id *)o count:(NSUInteger)n { NSArray *a=[self new];a->count=n;memcpy(a->items,o,n*sizeof(id));return a; }
- (id)lastObject { return count?items[count-1]:nil; }
- (NSUInteger)count { return count; }
- (id)objectAtIndex:(NSUInteger)i { assert(i<count); return items[i]; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)s objects:(id *)b count:(NSUInteger)n { if(s->state)return 0;s->state=1;s->itemsPtr=items;s->mutationsPtr=&count;return count; }
@end
@implementation NSMutableArray
- (void)addObjectsFromArray:(NSArray *)a { for(id o in a)[self addObject:o]; }
- (void)addObject:(id)o { assert(count<512);items[count++]=o; }
@end
@implementation NSDictionary
- (id)objectForKeyedSubscript:(id)k { return [self objectForKey:k]; }
+ (id)dictionaryWithObjects:(const id *)o forKeys:(const id *)k count:(NSUInteger)n { NSDictionary *d=[self new]; d->count=n;memcpy(d->keys,k,n*sizeof(id));memcpy(d->values,o,n*sizeof(id));return d; }
- (id)objectForKey:(id)k { for(NSUInteger i=0;i<count;i++)if([keys[i] isEqual:k])return values[i];return nil; }
- (NSUInteger)count { return count; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)s objects:(id *)b count:(NSUInteger)n { if(s->state)return 0;s->state=1;s->itemsPtr=keys;s->mutationsPtr=&count;return count; }
- (BOOL)isEqual:(id)o { if(![o isNSDictionary__]||count!=[o count])return NO;for(NSUInteger i=0;i<count;i++)if(![values[i] isEqual:[o objectForKey:keys[i]]])return NO;return YES; }
@end
@implementation NSMutableDictionary @end
@implementation NSEnumerator
- (id)nextObject { return index<array->count?array->items[index++]:nil; }
@end
@implementation NSSet
+ (id)set { return [self new]; }
+ (id)setWithArray:(NSArray *)a { NSMutableSet *s=[NSMutableSet new];for(id o in a)[s addObject:o];return s; }
- (id)allObjects { return [NSArray arrayWithArray:self]; }
@end
@implementation NSMutableSet
- (void)addObject:(id)o { for(NSUInteger i=0;i<count;i++)if([items[i] isEqual:o])return;items[count++]=o; }
- (void)unionSet:(NSSet *)s { for(id o in s)[self addObject:o]; }
@end
@implementation NSNull + (id)null { static id o; if(!o)o=[self new];return o; } @end
@implementation NSNumber
- (BOOL)boolValue { return value!=0; }
+ (id)numberWithInt:(int)v { return [[[self alloc] initWithDouble:v] autorelease]; }
+ (id)numberWithBool:(BOOL)v { return [[[self alloc] initWithDouble:v] autorelease]; }
- (id)initWithDouble:(double)v { value=v;return self; }
- (id)initWithLongLong:(long long)v { value=v;return self; }
- (id)initWithUnsignedLongLong:(unsigned long long)v { value=v;return self; }
- (double)doubleValue { return value; }
- (id)stringValue { char b[64];snprintf(b,sizeof(b),"%.17g",value);return [NSString stringWithUTF8String:b]; }
@end
@implementation NSValue
- (const char *)objCType { return "i"; }
- (void)getValue:(void *)v { memcpy(v,&stored,sizeof(stored)); }
#include "value.inc"
@end
@implementation NSScanner
- (id)initWithString:(NSString *)s { input=s;return self; }
- (void)setLocale:(id)l {}
- (BOOL)scanDecimal:(NSDecimal *)d { return NO; } // Failed-scan path under test.
@end
@implementation NSLocale @end
@implementation NSError
+ (id)_outOfMemoryError { return [self new]; }
+ (id)errorWithDomain:(id)d code:(NSInteger)c userInfo:(id)u { NSError *e=[self new];e->_domain=d;e->_code=c;e->_userInfo=u;return e; }
- (id)domain { return _domain; } - (NSInteger)code { return _code; } - (id)userInfo { return _userInfo; }
@end
@implementation NSException
+ (id)exceptionWithName:(id)n reason:(id)r userInfo:(id)u { return [self new]; }
+ (void)raise:(id)n format:(id)f,... { @throw [self new]; }
@end
// Only collection storage is doubled; recursive parser code is unchanged.
typedef id CFArrayRef, CFMutableArrayRef, CFDictionaryRef, CFMutableDictionaryRef;
typedef long CFIndex;
static void *kCFAllocatorDefault, *kCFTypeArrayCallBacks, *kCFTypeDictionaryKeyCallBacks, *kCFTypeDictionaryValueCallBacks;
static id CFArrayCreate(void *a,const void **v,NSUInteger n,void *c) { return [NSArray arrayWithObjects:(const id *)v count:n]; }
static id CFArrayCreateMutable(void *a,NSUInteger n,void *c) { return [NSMutableArray new]; }
static void CFArrayInsertValueAtIndex(id a,NSUInteger n,const void *v) { [a addObject:(id)v]; }
static id CFDictionaryCreate(void *a,const void **k,const void **v,NSUInteger n,void *c,void *d) { return [NSDictionary dictionaryWithObjects:(const id *)v forKeys:(const id *)k count:n]; }
static id CFDictionaryCreateMutable(void *a,NSUInteger n,void *c,void *d) { return [NSMutableDictionary new]; }
static void CFDictionarySetValue(NSMutableDictionary *a,id k,id v) { a->keys[a->count]=k;a->values[a->count++]=v; }
static void CFRelease(id o) {}
// NSString subclasses and ownership differences are explicitly outside this fixture.
@interface NSObject (Selectors) - (BOOL)respondsToSelector:(SEL)s; @end
@implementation NSObject (Selectors) - (BOOL)respondsToSelector:(SEL)s { return YES; } @end
@interface NSObject (Behavior)
- (NSRoundingMode)roundingMode;
- (id)exceptionDuringOperation:(SEL)s error:(NSCalculationError)e leftOperand:(id)l rightOperand:(id)r;
@end
#include "decimal.inc"
@implementation NSDecimalNumber
- (id)initWithMantissa:(unsigned long long)m exponent:(short)e isNegative:(BOOL)n { NSDecimal d={0};d._exponent=e;d._isNegative=n;memcpy(d._mantissa,&m,8);for(int i=0;i<4;i++)if(d._mantissa[i])d._length=i+1;return [self initWithDecimal:d]; }
+ (id)notANumber { NSDecimal d={0};d._isNegative=1;return [self decimalNumberWithDecimal:d]; }
+ (id)decimalNumberWithDecimal:(NSDecimal)d { return [[[self alloc] initWithDecimal:d] autorelease]; }
- (id)initWithDecimal:(NSDecimal)d { dec=d; return self; }
- (NSDecimal)decimalValue { return dec; }
- (id)initWithString:(NSString *)s { return [self initWithString:s locale:nil]; }
- (double)doubleValue { if(NSDecimalIsNotANumber(&dec))return NAN;return strtod([NSDecimalString(&dec,nil) UTF8String],NULL); }
#include "decimal-number.inc"
@end
@implementation NSError (Production)
#include "error.inc"
@end
#include "reader.inc"
@interface NSArray (ProductionKVC)
- (id)_unionOfArraysForKeyPath:(id)p;
- (id)_unionOfObjectsForKeyPath:(id)p;
- (id)_distinctUnionOfArraysForKeyPath:(id)p;
- (id)_distinctUnionOfSetsForKeyPath:(id)p;
- (id)_distinctUnionOfObjectsForKeyPath:(id)p;
@end
@implementation NSArray (ProductionKVC)
#include "array-kvc.inc"
@end
@implementation NSSet (ProductionKVC)
#include "set-kvc.inc"
@end
@interface Record : NSObject { @public id child, score, items, members; } @end
@implementation Record
- (id)valueForKey:(id)k { if([k isEqual:@"child"])return child;if([k isEqual:@"score"])return score;if([k isEqual:@"items"])return items;if([k isEqual:@"members"])return members;return [super valueForKey:k]; }
- (void)setValue:(id)v forKey:(id)k { if([k isEqual:@"score"])score=v;else [super setValue:v forKey:k]; }
@end

// Public option declarations come from the checked-in headers in run-native.py.
#include "regex-declarations.inc"
typedef id CFStringRef;
static const UChar *CFStringGetCharactersPtr(id s) { return NULL; }
@interface NSTextCheckingResult : NSObject { NSRange *ranges; NSUInteger count; }
+ (id)regularExpressionCheckingResultWithRanges:(NSRange *)r count:(NSUInteger)c regularExpression:(id)e;
- (NSRange)range; - (NSRange)rangeAtIndex:(NSUInteger)i; - (NSUInteger)numberOfRanges;
@end
@implementation NSTextCheckingResult
+ (id)regularExpressionCheckingResultWithRanges:(NSRange *)r count:(NSUInteger)c regularExpression:(id)e { NSTextCheckingResult *v=[self new];v->ranges=malloc(c*sizeof(NSRange));memcpy(v->ranges,r,c*sizeof(NSRange));v->count=c;return v; }
- (NSRange)range { return ranges[0]; }
- (NSRange)rangeAtIndex:(NSUInteger)i { assert(i<count);return ranges[i]; }
- (NSUInteger)numberOfRanges { return count; }
@end
#include "regex.inc"

static NSUInteger kCFNumberFormatterParseIntegersOnly;
static id CFNumberFormatterCreateNumberFromString(void *a,void *f,id s,void *r,NSUInteger o) { char *end;const char *text=[s UTF8String];double v=strtod(text,&end);return end==text?nil:[[NSNumber alloc] initWithDouble:v]; }
@implementation NSNumberFormatter
- (void)_regenerateFormatter {}
// A range-aware parser double isolates numberFromString's whole-input contract
// and forwarding of generatesDecimalNumbers to the existing getObjectValue path.
- (BOOL)getObjectValue:(id *)o forString:(NSString *)s range:(NSRange *)r error:(id *)e { const char *text=[s UTF8String];char *end;double v=strtod(text,&end);if(end==text)return NO;r->length=end-text;if(decimal){NSDecimal d={0};d._mantissa[0]=(unsigned short)v;d._length=v!=0;*o=[NSDecimalNumber decimalNumberWithDecimal:d];}else *o=[[NSNumber alloc] initWithDouble:v];return YES; }
#include "formatter.inc"
@end
@implementation NSData
- (NSUInteger)length { return length; }
- (void)enumerateByteRangesUsingBlock:(void (^)(const void *, NSRange, BOOL *))block { BOOL stop=NO;block(bytes,NSMakeRange(0,length),&stop); }
- (id)initWithBytesNoCopy:(void *)b length:(NSUInteger)n freeWhenDone:(BOOL)f { bytes=b;length=n;return self; }
#include "data.inc"
@end
@implementation NSExpression
+ (id)expressionForConstantValue:(id)v { NSExpression *e=[self new];e->constant=v;return e; }
@end
static BOOL _NSPredicateSubstitutionCheck(id v) { return YES; }
@implementation NSVariableExpression
- (id)variable { return @"v"; }
#include "variable.inc"
@end

@interface NativeCFNumber : NSNumber @end
static NSComparisonResult CFNumberCompare(id a,id b,void *c) { double x=[a doubleValue],y=[b doubleValue];if(x==0 && y==0 && signbit(x)!=signbit(y))return signbit(x)?-1:1;return x<y?-1:x>y?1:0; }
enum { kCFNumberFloat32Type=5,kCFNumberFloat64Type=6,kCFNumberDoubleType=13,kCFNumberSInt128Type=17 };
static int _CFNumberGetType2(NSNumber *a) { return a->cfType ?: kCFNumberFloat64Type; }
static BOOL CFNumberIsFloatType(id a) { return _CFNumberGetType2(a)!=kCFNumberSInt128Type; }
static BOOL CFNumberGetValue(NSNumber *a,int type,void *p) { *(double *)p=a->value;return YES; }
static id CFStringCreateWithFormat(void *a,void *b,id format,...);
#define CFSTR(s) @s
static id __CFNumberCreateFormattingDescription(void *a,id v,void *f) { double x=[v doubleValue];if(isinf(x))return x>0?@"+infinity":@"-infinity";if(x==0)return @"0.0";return @"finite"; }
typedef id CFNumberRef,CFTypeRef;
@implementation NativeCFNumber
- (long long)longLongValue { return signedStorage; }
#include "cf-number.inc"
@end
@interface NativeCFArray : NSMutableArray { @public BOOL mutable; } @end
@interface NativeCFDictionary : NSMutableDictionary { @public BOOL mutable; } @end
@interface NativeCFString : NSMutableString { @public BOOL mutable; } @end
static BOOL _CFArrayIsMutable(NativeCFArray *o) { return o->mutable; }
static BOOL _CFDictionaryIsMutable(NativeCFDictionary *o) { return o->mutable; }
static BOOL _CFStringIsMutable(NativeCFString *o) { return o->mutable; }
@implementation NativeCFArray
#include "cf-array-kind.inc"
@end
@implementation NativeCFDictionary
#include "cf-dictionary-kind.inc"
@end
@implementation NativeCFString
#include "cf-string-kind.inc"
@end

typedef id CFMutableStringRef;
static id CFStringCreateMutable(void *a,NSUInteger n) { return [NSMutableString string]; }
static void CFStringAppend(id s,id t) { [s appendString:t]; }
static id CFStringCreateCopy(void *a,id s) { return [NSString stringWithString:s]; }
static id CFStringCreateWithFormat(void *a,void *b,id format,...) { va_list args;va_start(args,format);char buffer[128];vsnprintf(buffer,sizeof(buffer),[format UTF8String],args);va_end(args);return [NSString stringWithUTF8String:buffer]; }
@implementation NSString (Description)
- (id)description { return self; }
@end
@interface NSArray (Joining) - (id)componentsJoinedByString:(id)s; @end
@implementation NSArray (Joining)
#include "array-join.inc"
@end
#include "index-declarations.inc"
static NSRange NSIntersectionRange(NSRange a,NSRange b) { NSUInteger start=MAX(a.location,b.location),end=MIN(NSMaxRange(a),NSMaxRange(b));return NSMakeRange(start,end>start?end-start:0); }
static BOOL NSLocationInRange(NSUInteger i,NSRange r) { return i>=r.location && i-r.location<r.length; }
static void NSIndexSetPurgeCache(NSIndexSetCache *c) {}
#include "utlist.h"
static void indexBits(NSIndexSet *s, BOOL bits[128]) { memset(bits,0,128);if(IS_EMPTY(s))return;if(HAS_SINGLE_RANGE(s)){for(NSUInteger i=SINGLE_RANGE(s).location;i<MIN(NSMaxRange(SINGLE_RANGE(s)),128);i++)bits[i]=YES;}else for(RangeList *r=MULTIPLE_RANGE_DATA(s);r;r=r->next)for(NSUInteger i=r->range.location;i<MIN(NSMaxRange(r->range),128);i++)bits[i]=YES; }
static void setIndexBits(NSIndexSet *s,BOOL bits[128]) { SET_EMPTY(s,YES);SET_HAS_SINGLE_RANGE(s,NO);MULTIPLE_RANGE_DATA(s)=NULL;SET_CACHE_VALID(s,NO);for(NSUInteger i=0;i<128;){if(!bits[i]){i++;continue;}NSUInteger start=i;while(i<128 && bits[i])i++;RangeList *r=calloc(1,sizeof(*r));r->range=NSMakeRange(start,i-start);DL_APPEND(MULTIPLE_RANGE_DATA(s),r);SET_EMPTY(s,NO);}RangeList *r=MULTIPLE_RANGE_DATA(s);if(r && !r->next){SET_SINGLE_RANGE(s,r->range);SET_HAS_SINGLE_RANGE(s,YES);} }
#include "index-add.inc"
static NSUInteger individualIndexAdditions, indexRangeSearches;
static NSUInteger shiftAllocations, failShiftAllocation;
static void *shiftMalloc(size_t size) { shiftAllocations++;return failShiftAllocation==shiftAllocations?NULL:malloc(size); }
@implementation NSIndexSet
- (BOOL)_isEmpty { return IS_EMPTY(self); }
- (BOOL)_hasSingleRange { return HAS_SINGLE_RANGE(self); }
- (NSRange)_singleRange { return SINGLE_RANGE(self); }
- (NSUInteger)firstIndex { return IS_EMPTY(self)?NSNotFound:HAS_SINGLE_RANGE(self)?SINGLE_RANGE(self).location:MULTIPLE_RANGE_DATA(self)->range.location; }
- (NSUInteger)indexGreaterThanIndex:(NSUInteger)i { __block NSUInteger result=NSNotFound;[self enumerateRangesUsingBlock:^(NSRange r,BOOL *stop){if(i<r.location){result=r.location;*stop=YES;}else if(i<NSMaxRange(r)-1){result=i+1;*stop=YES;}}];return result; }
#include "index-merge.inc"
- (id)init { SET_EMPTY(self,YES);return self; }
- (void)enumerateRangesUsingBlock:(void (^)(NSRange,BOOL *))block { BOOL stop=NO;if(IS_EMPTY(self))return;if(HAS_SINGLE_RANGE(self))block(SINGLE_RANGE(self),&stop);else for(RangeList *r=MULTIPLE_RANGE_DATA(self);r && !stop;r=r->next)block(r->range,&stop); }
- (RangeList *)_pointerToRangeBeforeOrContainingIndex:(NSUInteger)i { indexRangeSearches++;RangeList *last=NULL;for(RangeList *r=MULTIPLE_RANGE_DATA(self);r && r->range.location<=i;r=r->next)last=r;return last; }
@end
@implementation NSMutableIndexSet
- (void)addIndexesInRange:(NSRange)r { addIndexesInRange(self,r); }
#include "index-remove.inc"
#include "index-clear.inc"
- (void)addIndex:(NSUInteger)i { individualIndexAdditions++;[self addIndexesInRange:NSMakeRange(i,1)]; }
#include "index-add-set.inc"
#define malloc shiftMalloc
#include "index-shift.inc"
#undef malloc
@end
@interface RoundingBehavior : NSObject @end
@implementation RoundingBehavior
- (NSRoundingMode)roundingMode { return NSRoundPlain; }
- (id)exceptionDuringOperation:(SEL)s error:(NSCalculationError)e leftOperand:(id)l rightOperand:(id)r { assert(e==NSCalculationLossOfPrecision); return nil; }
@end
static int failures;
#define CHECK(c) do { if(!(c)) { printf("FAIL %d: %s\n",__LINE__,#c);failures++; } } while(0)
static id readJSON(const char *text, NSUInteger options, NSError **error) { _NSJSONReader *r=[_NSJSONReader new];id v=[r parseUTF8JSONData:[NSString stringWithUTF8String:text] skipBytes:0 options:options];*error=[r error];return v; }
int main(int argc,char **argv) {
 setbuf(stdout,NULL);
 NSLocaleDecimalSeparator=@"decimal"; NSCocoaErrorDomain=@"NSCocoaErrorDomain";NSLocalizedDescriptionKey=@"description";
 const char *section=argc>1?argv[1]:"json";
 if(!strcmp(section,"json")) {
  NSError *e;id v;
  for (NSUInteger options=0;options<4;options++) {
   v=readJSON("{\"b\":2,\"a\":[true,null,\"text\"]}",options,&e);
   CHECK(v && !e && [v count]==2);CHECK([[v objectForKey:@"b"] doubleValue]==2);
   CHECK([[v objectForKey:@"a"] count]==3);
   CHECK([v isKindOfClass:[NSMutableDictionary class]]==((options&1)!=0));
   CHECK([[v objectForKey:@"a"] isKindOfClass:[NSMutableArray class]]==((options&1)!=0));
  }
  const char *bad[]={"42","null","\"x\"","[1] junk","[1e400]","{\"a\":}","", "true junk"};
  for(unsigned i=0;i<sizeof(bad)/sizeof(*bad);i++) {v=readJSON(bad[i],0,&e);CHECK(!v && [e code]==3840);}
  const char *badFragments[]={"true junk","falsee","nulz","1e","1.","01","[1e400]"};
  for(unsigned i=0;i<sizeof(badFragments)/sizeof(*badFragments);i++){v=readJSON(badFragments[i],4,&e);CHECK(!v && [e code]==3840);}
  v=readJSON("[1,-2,1.25,1e20] \n",0,&e);CHECK([v count]==4 && !e);CHECK([[v objectAtIndex:3] doubleValue]==1e20);
  v=readJSON("null",4,&e);CHECK(v==[NSNull null] && !e);
  v=readJSON("42",4,&e);CHECK([v doubleValue]==42 && !e);
  CHECK(![_NSJSONReader validForJSON:[[NSNumber alloc] initWithDouble:42] depth:0 allowFragments:NO]);
  id nan=[[NSNumber alloc] initWithDouble:NAN], inf=[[NSNumber alloc] initWithDouble:INFINITY];
  CHECK(![_NSJSONReader validForJSON:[NSArray arrayWithObjects:&nan count:1] depth:0 allowFragments:NO]);
  CHECK(![_NSJSONReader validForJSON:inf depth:0 allowFragments:YES]);
  id key=nan,val=[NSNull null];CHECK(![_NSJSONReader validForJSON:[NSDictionary dictionaryWithObjects:&val forKeys:&key count:1] depth:0 allowFragments:NO]);
 } else if(!strcmp(section,"error")) {
  NSError *a=[NSError errorWithDomain:@"domain" code:7 userInfo:nil], *b=[NSError errorWithDomain:[NSString stringWithUTF8String:"domain"] code:7 userInfo:nil];
  CHECK([a isEqual:b]);CHECK([a hash]==[b hash]);CHECK([a isEqual:a]);
  CHECK(![a isEqual:[NSError errorWithDomain:@"domain" code:8 userInfo:nil]]);
  CHECK(![a isEqual:[NSError errorWithDomain:@"other" code:7 userInfo:nil]]);CHECK(![a isEqual:nil]);CHECK(![a isEqual:@"domain"]);
  CHECK([a isEqual:[NSError errorWithDomain:@"domain" code:7 userInfo:[NSDictionary new]]]);
  id k=@"k",v=@"v";NSDictionary *u=[NSDictionary dictionaryWithObjects:&v forKeys:&k count:1];
  CHECK(![a isEqual:[NSError errorWithDomain:@"domain" code:7 userInfo:u]]);
 } else if(!strcmp(section,"join")) {
  id same=@"null";id values[]={same,same,same};
  NSArray *a=[NSArray arrayWithObjects:values count:3];
  CHECK([[a componentsJoinedByString:@","] isEqual:@"null,null,null"]);
  CHECK([[[NSArray array] componentsJoinedByString:@","] isEqual:@""]);
  CHECK([[[NSArray arrayWithObject:same] componentsJoinedByString:@","] isEqual:@"null"]);
 } else if(!strcmp(section,"kvc")) {
  Record *a=[Record new],*b=[Record new];id records[]={a,b};NSArray *outer=[NSArray arrayWithObjects:records count:2];
  NSArray *mapped=[outer valueForKey:@"child"];CHECK([mapped count]==2 && [mapped objectAtIndex:0]==[NSNull null]);
  @try {[outer setValue:@"nine" forKey:@"score"];CHECK([a->score isEqual:@"nine"] && [b->score isEqual:@"nine"]);} @catch(id e) {CHECK(0);}
  id x=@"one",y=@"two",z=@"three";id av[]={x,y},bv[]={y,z};a->items=[NSArray arrayWithObjects:av count:2];b->items=[NSArray arrayWithObjects:bv count:2];
  @try { NSArray *r=[outer _unionOfArraysForKeyPath:@"items"];CHECK([r count]==4 && [r objectAtIndex:0]==x && [r objectAtIndex:3]==z); } @catch(id e){CHECK(0);}
  @try { CHECK([[outer _distinctUnionOfArraysForKeyPath:@"items"] count]==3); } @catch(id e){CHECK(0);}
  a->members=[NSSet setWithArray:a->items];b->members=[NSSet setWithArray:b->items];
  @try { CHECK([[outer _distinctUnionOfSetsForKeyPath:@"members"] count]==3); } @catch(id e){CHECK(0);}
  @try { CHECK([[[NSSet setWithArray:outer] _distinctUnionOfSetsForKeyPath:@"members"] count]==3); } @catch(id e){CHECK(0);}
 } else if(!strcmp(section,"regex")) {
  @try {CHECK([[NSRegularExpression escapedPatternForString:@"^x$"] isEqual:@"\\^x\\$"]);CHECK([[NSRegularExpression escapedPatternForString:@"$1\\x"] isEqual:@"\\$1\\\\x"]);} @catch(id e){CHECK(0);}
  CHECK([[NSRegularExpression escapedPatternForString:@"[a]"] isEqual:@"\\[a]"]);
  NSError *unicodeError=nil;
  NSRegularExpression *dot=[[NSRegularExpression alloc] initWithPattern:@"." options:0 error:&unicodeError];
  unichar unicode[]={0xd83d,0xde00,'x'};NSString *unicodeString=[[NSString alloc] initWithCharacters:unicode length:3];
  CHECK([dot numberOfMatchesInString:unicodeString options:NSMatchingAnchored range:NSMakeRange(0,3)]==2);
  NSRegularExpression *letter=[[NSRegularExpression alloc] initWithPattern:@"a" options:0 error:&unicodeError];
  CHECK([letter numberOfMatchesInString:@"aaba" options:NSMatchingAnchored range:NSMakeRange(0,4)]==2);
  BOOL hasTemplate=class_getClassMethod([NSRegularExpression class],@selector(escapedTemplateForString:))!=NULL;CHECK(hasTemplate);
  if(hasTemplate) @try {CHECK([[NSRegularExpression escapedTemplateForString:@"$1\\x"] isEqual:@"\\$1\\\\x"]);} @catch(id e){CHECK(0);}
  NSError *e=nil;id invalid=[[NSRegularExpression alloc] initWithPattern:@"[" options:0 error:&e];CHECK(!invalid && [e code]==2048);
  NSArray *patterns=[NSArray arrayWithObjects:(id[]){@"^|$",@"a*",@"(?=a)"} count:3];
  NSArray *strings=[NSArray arrayWithObjects:(id[]){@"ab",@"bbb",@"aba"} count:3];
  NSArray *replacements=[NSArray arrayWithObjects:(id[]){@"<>ab<>",@"<>b<>b<>b<>",@"<>ab<>a"} count:3];
  for(NSUInteger i=0;i<3;i++) { NSString *str=[strings objectAtIndex:i];NSRegularExpression *r=[[NSRegularExpression alloc] initWithPattern:[patterns objectAtIndex:i] options:0 error:&e];
   CHECK([r numberOfMatchesInString:str options:NSMatchingAnchored range:NSMakeRange(0,[str length])]==1);
   CHECK([[r stringByReplacingMatchesInString:str options:0 range:NSMakeRange(0,[str length]) withTemplate:@"<>"] isEqual:[replacements objectAtIndex:i]]);
  }
  NSRegularExpression *r=[[NSRegularExpression alloc] initWithPattern:@"a+" options:0 error:&e];
  CHECK([r numberOfMatchesInString:@"baaacaa" options:NSMatchingAnchored range:NSMakeRange(0,7)]==0);
  CHECK([r numberOfMatchesInString:@"baaacaa" options:NSMatchingAnchored range:NSMakeRange(1,3)]==1);
  BOOL raised=NO;@try{[r numberOfMatchesInString:@"a" options:0 range:NSMakeRange(2,1)];}@catch(id e){raised=YES;}CHECK(raised);
 } else if(!strcmp(section,"value")) {
  BOOL hasSizedGet=class_getInstanceMethod([NSValue class],@selector(getValue:size:))!=NULL;CHECK(hasSizedGet);
  if(hasSizedGet) { int inputs[]={0,-1,42,INT_MAX};for(unsigned i=0;i<4;i++){NSValue *v=[NSValue new];v->stored=inputs[i];struct {int value;int canary;} output={17,123};[v getValue:&output.value size:sizeof(int)];CHECK(output.value==inputs[i] && output.canary==123);} for(unsigned size=0;size<=8;size++){if(size==4)continue;int buffer[4]={0};BOOL raised=NO;@try{[[NSValue new] getValue:buffer size:size];}@catch(id e){raised=YES;}CHECK(raised);} }
 } else if(!strcmp(section,"formatter")) {
  NSNumberFormatter *f=[NSNumberFormatter new];CHECK(![f numberFromString:@"12x"]);CHECK(![f numberFromString:@"1,234.5"]);CHECK([[f numberFromString:@" 42 "] doubleValue]==42);
  f->decimal=YES;CHECK([[f numberFromString:@"42"] isKindOfClass:[NSDecimalNumber class]]);
 } else if(!strcmp(section,"data")) {
  const char *tokens[]={"YQ","YQ==","YWJj","YQ==YWJj","Y Q=="};BOOL success[]={NO,YES,YES,NO,NO};
  for(unsigned i=0;i<5;i++){NSData *input=[[NSData alloc] initWithBytesNoCopy:(void *)tokens[i] length:strlen(tokens[i]) freeWhenDone:NO];NSData *r=[[NSData alloc] initWithBase64EncodedData:input options:0];CHECK((r!=nil)==success[i]);if(i==1 && r)CHECK(r->length==1 && r->bytes[0]=='a');}
  NSData *input=[[NSData alloc] initWithBytesNoCopy:"YQ" length:2 freeWhenDone:NO];CHECK(![[NSData alloc] initWithBase64EncodedData:input options:1]);
 } else if(!strcmp(section,"predicate")) {
  id k=@"v",value=@"five";NSDictionary *vars=[NSDictionary dictionaryWithObjects:&value forKeys:&k count:1];NSVariableExpression *variable=[NSVariableExpression new];NSExpression *result=[variable _expressionWithSubstitutionVariables:vars];CHECK(result && result->constant==value);
 } else if(!strcmp(section,"number2")) {
  NativeCFNumber *large=[[NativeCFNumber alloc] initWithDouble:9223372036854775808.0];
  CHECK([[large stringValue] isEqual:@"9.223372036854776e+18"]);
  NativeCFNumber *small=[[NativeCFNumber alloc] initWithDouble:(double)(float)1.23456789];small->cfType=5;
  CHECK([[small stringValue] isEqual:@"1.234568"]);
  NativeCFNumber *unsignedMax=[[NativeCFNumber alloc] initWithDouble:18446744073709551616.0];unsignedMax->cfType=17;unsignedMax->signedStorage=-1;
  CHECK([unsignedMax doubleValue]==18446744073709551616.0);
 } else if(!strcmp(section,"number")) {
  id minusZero=[[NativeCFNumber alloc] initWithDouble:-0.0],zero=[[NativeCFNumber alloc] initWithDouble:0.0];CHECK([[minusZero stringValue] isEqual:@"-0"]);CHECK([minusZero compare:zero]==0);
  CHECK([[[[NativeCFNumber alloc] initWithDouble:INFINITY] stringValue] isEqual:@"inf"]);CHECK([[[[NativeCFNumber alloc] initWithDouble:-INFINITY] stringValue] isEqual:@"-inf"]);
 } else if(!strcmp(section,"identity")) {
  NativeCFArray *a=[NativeCFArray new];CHECK(![a isKindOfClass:[NSMutableArray class]]);a->mutable=YES;CHECK([a isKindOfClass:[NSMutableArray class]]);
  NativeCFDictionary *d=[NativeCFDictionary new];CHECK(![d isKindOfClass:[NSMutableDictionary class]]);d->mutable=YES;CHECK([d isKindOfClass:[NSMutableDictionary class]]);
  NativeCFString *s=[NativeCFString new];CHECK(![s isKindOfClass:[NSMutableString class]]);s->mutable=YES;CHECK([s isKindOfClass:[NSMutableString class]]);
  BOOL raised=NO;@try{[NSArray arrayWithObject:nil];}@catch(id e){raised=YES;}CHECK(raised);
 } else if(!strcmp(section,"index")) {
  for(unsigned mask=1;mask<64;mask++)for(unsigned start=0;start<9;start++)for(int delta=-4;delta<=4;delta++) {
   NSMutableIndexSet *set=[NSMutableIndexSet new];BOOL original[128]={0},want[128]={0},actual[128];for(unsigned i=0;i<6;i++)if(mask&(1u<<i))original[i]=YES;setIndexBits(set,original);
   unsigned amount=delta<0?-delta:delta,keep=delta<0?(start>amount?start-amount:0):start;
   for(unsigned i=0;i<6;i++)if(original[i]){if(i<keep)want[i]=YES;else if(i>=start && (int)i+delta>=0)want[i+delta]=YES;}
   [set shiftIndexesStartingAtIndex:start by:delta];indexBits(set,actual);
   __block NSUInteger previousEnd=0;[set enumerateRangesUsingBlock:^(NSRange r,BOOL *stop){CHECK(r.location>=previousEnd);previousEnd=NSMaxRange(r);}];
   if(memcmp(actual,want,128)){CHECK(0);goto indexDone;}
  }
indexDone: ;
  NSMutableIndexSet *split=[NSMutableIndexSet new];
  [split addIndexesInRange:NSMakeRange(1,1)];[split addIndexesInRange:NSMakeRange(3,8)];
  [split removeIndexesInRange:NSMakeRange(5,2)];
  __block NSUInteger end=0,count=0;[split enumerateRangesUsingBlock:^(NSRange r,BOOL *stop){CHECK(r.location>=end);end=NSMaxRange(r);count+=r.length;}];CHECK(count==7);

  // Reviewer reproducer: two compressed ranges must never expand into indexes.
  NSMutableIndexSet *dense=[NSMutableIndexSet new];
  [dense addIndexesInRange:NSMakeRange(0,10000)];[dense addIndexesInRange:NSMakeRange(20000,10000)];
  shiftAllocations=individualIndexAdditions=indexRangeSearches=0;[dense shiftIndexesStartingAtIndex:0 by:1];
  CHECK(individualIndexAdditions==0);CHECK(indexRangeSearches==0);
  CHECK(shiftAllocations<=2);
  CHECK(MULTIPLE_RANGE_DATA(dense)->range.location==1 && MULTIPLE_RANGE_DATA(dense)->range.length==10000);
  CHECK(MULTIPLE_RANGE_DATA(dense)->next->range.location==20001);
  // Direct ordered setup avoids measuring insertion during fixture construction.
  NSMutableIndexSet *fragmented=[NSMutableIndexSet new];SET_EMPTY(fragmented,NO);RESET_CACHE(fragmented);
  for(NSUInteger i=0;i<4096;i++){RangeList *r=calloc(1,sizeof(*r));r->range=NSMakeRange(3*i,1);DL_APPEND(MULTIPLE_RANGE_DATA(fragmented),r);}
  shiftAllocations=individualIndexAdditions=indexRangeSearches=0;[fragmented shiftIndexesStartingAtIndex:0 by:1];
  CHECK(individualIndexAdditions==0);CHECK(indexRangeSearches==0);
  CHECK(shiftAllocations<=4096);
  NSUInteger ordinal=0;for(RangeList *r=MULTIPLE_RANGE_DATA(fragmented);r;r=r->next,ordinal++)CHECK(r->range.location==3*ordinal+1 && r->range.length==1);CHECK(ordinal==4096);
  RangeList *originalRanges=MULTIPLE_RANGE_DATA(dense);
  failShiftAllocation=2;shiftAllocations=0;BOOL raised=NO;
  @try{[dense shiftIndexesStartingAtIndex:0 by:1];}@catch(id e){raised=YES;}
  failShiftAllocation=0;CHECK(raised);CHECK(MULTIPLE_RANGE_DATA(dense)==originalRanges && originalRanges->range.location==1 && originalRanges->next->range.location==20001);
  NSMutableIndexSet *overflow=[NSMutableIndexSet new];[overflow addIndexesInRange:NSMakeRange(1,2)];[overflow addIndexesInRange:NSMakeRange(NSNotFound-2,1)];
  originalRanges=MULTIPLE_RANGE_DATA(overflow);raised=NO;
  @try{[overflow shiftIndexesStartingAtIndex:0 by:3];}@catch(id e){raised=YES;}
  CHECK(raised);CHECK(MULTIPLE_RANGE_DATA(overflow)==originalRanges && originalRanges->range.location==1 && originalRanges->next->range.location==NSNotFound-2);

 } else if(!strcmp(section,"decimal-display")) {
  unsigned long long integer=9223372036854776000ULL;NSDecimal d={0};d._length=4;memcpy(d._mantissa,&integer,sizeof(integer));
  NSDecimalNumber *n=[NSDecimalNumber decimalNumberWithDecimal:d];CHECK([[n description] isEqual:@"9223372036854776000"]);
  d._isNegative=1;n=[NSDecimalNumber decimalNumberWithDecimal:d];CHECK([[n description] isEqual:@"-9223372036854776000"]);
  d=(NSDecimal){0};d._length=1;d._mantissa[0]=1;d._exponent=-20;n=[NSDecimalNumber decimalNumberWithDecimal:d];CHECK([[n description] isEqual:@"0.00000000000000000001"]);
 } else if(!strcmp(section,"decimal")) {
  NSDecimal d={0}; d._length=2;d._mantissa[0]=0x15;d._mantissa[1]=1;d._exponent=20;
  NSDecimalNumber *n=[NSDecimalNumber decimalNumberWithDecimal:d];
  CHECK(!strcmp([[n stringValue] UTF8String],"6555700000000000000000000"));
  CHECK(NSDecimalIsNotANumber(&((NSDecimalNumber *)[[NSDecimalNumber alloc] initWithString:@"junk"])->dec));
  NSDecimal one={0};one._length=1;one._mantissa[0]=1;
  d=one;d._exponent=-128;n=[NSDecimalNumber decimalNumberWithDecimal:d];
  id sum=[n decimalNumberByAdding:[NSDecimalNumber decimalNumberWithDecimal:one] withBehavior:[RoundingBehavior new]];
  CHECK(sum && NSDecimalCompare(&((NSDecimalNumber *)sum)->dec,&one)==0);
 }
 printf("%s: %s (%d failures)\n",section,failures?"FAIL":"PASS",failures);return failures?1:0;
}
