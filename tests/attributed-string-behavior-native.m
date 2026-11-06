// Linux libobjc fixture. Production methods are inserted unchanged by the runner.
// CF allocation/string/dictionary operations are controlled doubles; the run
// accessor, Objective-C boundary checks, and enumeration loops are production.
#include <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <limits.h>
#include <stdbool.h>
#include <assert.h>
// Blocks are invoked on the stack only; no copy or disposal is exercised.
void *_NSConcreteStackBlock[32];
void *_NSConcreteGlobalBlock[32];
void _Block_object_assign(void *dst,const void *src,int flags) { abort(); }
void _Block_object_dispose(const void *src,int flags) { abort(); }
typedef unsigned long NSUInteger;
typedef unsigned short unichar;
typedef long CFIndex;
typedef void NSZone;
typedef struct { NSUInteger location, length; } NSRange;
typedef NSRange *NSRangePointer;
typedef NSRange CFRange;
typedef NSUInteger NSAttributedStringEnumerationOptions;
typedef NSUInteger NSStringCompareOptions;
#define NSAttributedStringEnumerationReverse 2
#define NSAttributedStringEnumerationLongestEffectiveRangeNotRequired (1UL<<20)
#define NSRegularExpressionSearch (1UL<<10)
#define NSNotFound LONG_MAX
#define MIN(a,b) ((a)<(b)?(a):(b))
#define MAX(a,b) ((a)>(b)?(a):(b))
#define kCFAllocatorDefault NULL
#define kCFAllocatorSystemDefault NULL
static NSRange NSMakeRange(NSUInteger a,NSUInteger b) { return (NSRange){a,b}; }
#define CFRangeMake NSMakeRange
static NSRange NSIntersectionRange(NSRange a,NSRange b) { NSUInteger lo=MAX(a.location,b.location),hi=MIN(a.location+a.length,b.location+b.length);return NSMakeRange(lo,hi>lo?hi-lo:0); }
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc; + (Class)class;
- (id)init; - (id)retain; - (id)autorelease; - (void)release;
- (BOOL)isKindOfClass:(Class)cls;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self,0); } + (Class)class { return self; }
- (id)init { return self; } - (id)retain { return self; } - (id)autorelease { return self; } - (void)release {}
- (BOOL)isKindOfClass:(Class)cls { for(Class c=object_getClass(self);c;c=class_getSuperclass(c))if(c==cls)return YES;return NO; }
@end
@interface NSString:NSObject
+ (id)stringWithFormat:(id)format,...;
- (NSUInteger)length; - (const char *)UTF8String;
- (id)substringWithRange:(NSRange)r; - (id)substringFromIndex:(NSUInteger)i;
- (id)initWithCharactersNoCopy:(unichar *)b length:(NSUInteger)n freeWhenDone:(BOOL)f;
- (void)getCharacters:(unichar *)b range:(NSRange)r;
- (NSRange)rangeOfString:(NSString *)s options:(NSUInteger)o range:(NSRange)r locale:(id)l;
@end
typedef NSString *NSAttributedStringKey;
@interface FixtureString:NSString { @public const char *bytes; unsigned int size; } @end
@implementation FixtureString
- (NSUInteger)length { return size; } - (const char *)UTF8String { return bytes; }
@end
static id makeString(const char *s) { FixtureString *r=[FixtureString alloc];r->bytes=s;r->size=strlen(s);return r; }
static id NSInvalidArgumentException=@"invalid",NSRangeException=@"range";
@interface NSException:NSObject { @public id name; }
+ (id)exceptionWithName:(id)n reason:(id)r userInfo:(id)u;
+ (void)raise:(id)n format:(id)f,...;
@end
@implementation NSException
+ (id)exceptionWithName:(id)n reason:(id)r userInfo:(id)u { NSException *e=[self alloc];e->name=n;return e; }
+ (void)raise:(id)n format:(id)f,... { @throw [self exceptionWithName:n reason:nil userInfo:nil]; }
@end
static BOOL NSRangeCheckException(NSRange r,NSUInteger n) { if(r.location>n||r.length>n-r.location)[NSException raise:NSRangeException format:nil];return YES; }
@interface NSDictionary<Key,Value>:NSObject { @public id value; }
+ (id)dictionary;
@end
@implementation NSDictionary
+ (id)dictionary { static id empty;return empty?: (empty=[self alloc]); }
@end
@class NSError,NSLocale;
@interface NSRegularExpression:NSObject
+ (id)regularExpressionWithPattern:(id)p options:(NSUInteger)o error:(NSError **)e;
- (NSRange)rangeOfFirstMatchInString:(id)s options:(NSUInteger)o range:(NSRange)r;
@end
@implementation NSRegularExpression
+ (id)regularExpressionWithPattern:(id)p options:(NSUInteger)o error:(NSError **)e { abort(); }
- (NSRange)rangeOfFirstMatchInString:(id)s options:(NSUInteger)o range:(NSRange)r { abort(); }
@end
typedef id CFStringRef;typedef id CFDictionaryRef;typedef id CFLocaleRef;typedef id CFAttributedStringRef;typedef id CFMutableAttributedStringRef;typedef NSUInteger CFStringCompareFlags;
static BOOL CFStringFindWithOptionsAndLocale(id s,id t,NSRange r,NSUInteger o,id l,NSRange *out) { return NO; }
static id CFStringCreateWithSubstring(void *a,id s,NSRange r) { assert(r.location<=[s length]&&r.length<=[s length]-r.location);return makeString(""); }
static unichar CFStringGetCharacterAtIndex(id s,NSUInteger i) { return [(FixtureString *)s UTF8String][i]; }
@implementation NSString
+ (id)stringWithFormat:(id)f,... { return f; }
- (NSUInteger)length { return 0; }
- (id)initWithCharactersNoCopy:(unichar *)b length:(NSUInteger)n freeWhenDone:(BOOL)f { if(f)free(b);return makeString(""); }
- (void)getCharacters:(unichar *)b range:(NSRange)r { assert(r.location<=[self length]&&r.length<=[self length]-r.location); }
STRING_METHODS
@end
@interface __NSCFString:FixtureString @end
@implementation __NSCFString
CF_STRING_METHODS
@end
typedef struct { NSRange _range; id _dictionary; } __CFRunArrayItem;
@interface NSAttributedString:NSObject
- (NSUInteger)length;
- (id)attributesAtIndex:(NSUInteger)i effectiveRange:(NSRange *)r;
- (id)attributesAtIndex:(NSUInteger)i longestEffectiveRange:(NSRange *)r inRange:(NSRange)limit;
- (id)attribute:(id)key atIndex:(NSUInteger)i effectiveRange:(NSRange *)r;
- (id)attribute:(id)key atIndex:(NSUInteger)i longestEffectiveRange:(NSRange *)r inRange:(NSRange)limit;
@end
@interface NSMutableAttributedString:NSAttributedString @end
@implementation NSMutableAttributedString @end
@interface __NSCFAttributedString:NSMutableAttributedString { @public NSUInteger count; __CFRunArrayItem **_attributes; CFIndex _runArrayCount; BOOL mutableFlag; }
@end
typedef __NSCFAttributedString __CFAttributedString;
RUN_ACCESSOR
static id CFAttributedStringGetAttributes(id s,NSUInteger i,NSRange *r) { return _CFRunArrayObjectAtIndex(s,i,r); }
static id CFAttributedStringGetAttribute(id s,NSUInteger i,id key,NSRange *r) { return ((NSDictionary *)CFAttributedStringGetAttributes(s,i,r))->value; }
static BOOL _CFAttributedStringIsMutable(id s) { return ((__NSCFAttributedString *)s)->mutableFlag; }
static id lastAttributes;
static void CFAttributedStringSetAttributes(id s,NSRange r,id d,BOOL clear) { assert(d);lastAttributes=d; }
RANGE_HELPERS
@implementation NSAttributedString
ENUM_METHODS
@end
@implementation __NSCFAttributedString
- (NSUInteger)length { return count; }
CF_ATTR_METHODS
- (id)attributesAtIndex:(NSUInteger)i longestEffectiveRange:(NSRange *)r inRange:(NSRange)limit { id d=[self attributesAtIndex:i effectiveRange:r];if(r)*r=NSIntersectionRange(*r,limit);return d; }
- (id)attribute:(id)key atIndex:(NSUInteger)i longestEffectiveRange:(NSRange *)r inRange:(NSRange)limit { id d=[self attribute:key atIndex:i effectiveRange:r];if(r)*r=NSIntersectionRange(*r,limit);return d; }
@end
static __NSCFAttributedString *runs(NSUInteger n) {
 __NSCFAttributedString *s=[__NSCFAttributedString alloc];s->count=s->_runArrayCount=n;
 if(n) { s->_attributes=calloc(n,sizeof(void *));__CFRunArrayItem *r=calloc(1,sizeof(*r));r->_range=NSMakeRange(0,n);r->_dictionary=[NSDictionary dictionary];for(NSUInteger i=0;i<n;i++)s->_attributes[i]=r; }
 return s;
}
@interface __NSPlaceholderAttributedString:NSAttributedString @end
static id mutablePlaceholder;
static id CFAttributedStringCreate(void *a,id s,id attrs) { return runs([s length]); }
static void _CFAttributedStringSetMutable(id s,BOOL flag) { ((__NSCFAttributedString *)s)->mutableFlag=flag; }
@implementation __NSPlaceholderAttributedString
PLACEHOLDER_INIT
@end
static unsigned failures;
#define CHECK(x) do { if(!(x)){printf("FAIL line %d: %s\n",__LINE__,#x);failures++;} } while(0)
#define THROWS(expr,n) do { BOOL caught=NO;@try { (void)(expr); } @catch(NSException *e){caught=e->name==(n);}CHECK(caught); } while(0)
int main(int argc,char **argv) {
 setvbuf(stdout,NULL,_IONBF,0);
 if(argc==1||!strcmp(argv[1],"empty")) {
  id placeholder=[__NSPlaceholderAttributedString alloc];
  THROWS([placeholder initWithString:nil attributes:nil],NSInvalidArgumentException);
  id empty=runs(0);THROWS([empty attributesAtIndex:0 effectiveRange:NULL],NSRangeException);
  THROWS([empty attribute:@"k" atIndex:0 effectiveRange:NULL],NSRangeException);
  id one=runs(1);THROWS([one attributesAtIndex:1 effectiveRange:NULL],NSRangeException);
  puts("empty/end boundary exercised");
 }
 if(argc==1||!strcmp(argv[1],"types")) {
  __NSCFAttributedString *s=runs(6);CHECK([s isKindOfClass:[NSAttributedString class]]);CHECK(![s isKindOfClass:[NSMutableAttributedString class]]);
  s->mutableFlag=YES;CHECK([s isKindOfClass:[NSMutableAttributedString class]]);
  [s setAttributes:nil range:NSMakeRange(1,2)];CHECK(lastAttributes==[NSDictionary dictionary]);
  THROWS([s setAttributes:nil range:NSMakeRange(ULONG_MAX,2)],NSRangeException);
 }
 if(argc==1||!strcmp(argv[1],"strings")) {
  __NSCFString *s=[__NSCFString alloc];s->bytes="";s->size=0;
  THROWS([s characterAtIndex:0],NSInvalidArgumentException);
  THROWS([s substringFromIndex:1],NSRangeException);
  THROWS([s substringWithRange:NSMakeRange(NSNotFound,0)],NSInvalidArgumentException);
  THROWS([s rangeOfString:nil options:0 range:NSMakeRange(0,0) locale:nil],NSInvalidArgumentException);
  CHECK([[s substringFromIndex:0] length]==0);
  THROWS([s substringWithRange:NSMakeRange(ULONG_MAX,2)],NSRangeException);
  s->bytes="abc";s->size=3;
  THROWS([s characterAtIndex:3],NSRangeException);CHECK([s characterAtIndex:2]=='c');
  id generic=makeString("");THROWS([generic substringWithRange:NSMakeRange(NSNotFound,0)],NSInvalidArgumentException);
 }
 if(argc==1||!strcmp(argv[1],"enumerate")) {
  __NSCFAttributedString *s=runs(6);((NSDictionary *)s->_attributes[0]->_dictionary)->value=@"value";
  unsigned callsStorage=0;unsigned *calls=&callsStorage;
  [s enumerateAttribute:@"k" inRange:NSMakeRange(1,3) options:NSAttributedStringEnumerationReverse|NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(id v,NSRange r,BOOL *stop){(*calls)++;CHECK(v==((NSDictionary *)s->_attributes[0]->_dictionary)->value);CHECK(r.location==1&&r.length==3);}];CHECK(*calls==1);
  *calls=0;[s enumerateAttributesInRange:NSMakeRange(1,3) options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(id v,NSRange r,BOOL *stop){(*calls)++;CHECK(r.location==1&&r.length==3);*stop=YES;}];CHECK(*calls==1);
  *calls=0;[s enumerateAttribute:@"k" inRange:NSMakeRange(6,0) options:0 usingBlock:^(id v,NSRange r,BOOL *stop){(*calls)++;}];CHECK(*calls==0);
  // Three runs: deletion of the current run must revisit its old location.
  s=runs(3);for(NSUInteger i=0;i<3;i++){__CFRunArrayItem *r=calloc(1,sizeof(*r));r->_range=NSMakeRange(i,1);r->_dictionary=[NSDictionary dictionary];s->_attributes[i]=r;}
  *calls=0;[s enumerateAttributesInRange:NSMakeRange(0,3) options:0 usingBlock:^(id v,NSRange r,BOOL *stop){CHECK(r.location==0&&r.length==1);(*calls)++;s->count--;s->_runArrayCount--;for(NSUInteger i=0;i<s->count;i++){s->_attributes[i]=s->_attributes[i+1];s->_attributes[i]->_range.location--;}}];CHECK(*calls==3&&s->count==0);
 }
 printf("behavior-native: %u failures\n",failures);return failures?1:0;
}
