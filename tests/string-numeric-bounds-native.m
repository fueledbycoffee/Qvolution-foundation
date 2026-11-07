// Only storage, character-set membership and bounds exceptions are doubles.
// The parser and six numeric conversion methods come unchanged from NSString.m.
#include <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <stdint.h>
#include <limits.h>
#include <math.h>
typedef unsigned long NSUInteger;
typedef long NSInteger;
typedef uint16_t unichar;
typedef int32_t SInt32;
typedef struct { NSUInteger location, length; } NSRange;
#define NSNotFound LONG_MAX
#define NSCaseInsensitiveSearch 1
#define NSOrderedSame 0
static NSRange NSMakeRange(NSUInteger a, NSUInteger b) { return (NSRange){a,b}; }
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
- (id)retain;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self,0); }
- (id)retain { return self; }
@end
@interface NSException:NSObject @end
@implementation NSException @end
@interface NSCharacterSet:NSObject { @public BOOL includesNewlines; }
+ (id)whitespaceCharacterSet;
+ (id)whitespaceAndNewlineCharacterSet;
- (id)invertedSet;
@end
@implementation NSCharacterSet
+ (id)whitespaceCharacterSet { return [self alloc]; }
+ (id)whitespaceAndNewlineCharacterSet { NSCharacterSet *set=[self alloc];set->includesNewlines=YES;return set; }
- (id)invertedSet { return self; }
@end
@interface NSString:NSObject { @public const char *bytes; NSUInteger size; }
- (NSUInteger)length;
- (unichar)characterAtIndex:(NSUInteger)i;
- (NSRange)rangeOfCharacterFromSet:(id)set;
- (id)substringFromIndex:(NSUInteger)i;
- (long)compare:(id)s options:(NSUInteger)o range:(NSRange)r;
- (double)doubleValue;
- (float)floatValue;
- (int)intValue;
- (NSInteger)integerValue;
- (long long)longLongValue;
- (BOOL)boolValue;
@end
@interface FixtureString:NSString @end
@implementation FixtureString @end
static NSString *string(const char *text) {
    NSString *s=[NSString alloc];s->bytes=text;s->size=strlen(text);return s;
}
@implementation NSString
- (NSUInteger)length { return size; }
- (unichar)characterAtIndex:(NSUInteger)i {
    if(i>=size) @throw [NSException alloc];
    return (unsigned char)bytes[i];
}
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)set {
    for(NSUInteger i=0;i<size;i++)
        if(!strchr(set->includesNewlines?" \t\n\r\v\f":" \t", bytes[i]))return NSMakeRange(i,1);
    return NSMakeRange(NSNotFound,0);
}
- (id)substringFromIndex:(NSUInteger)i {
    if(i>size) @throw [NSException alloc];
    return string(bytes+i);
}
- (long)compare:(NSString *)s options:(NSUInteger)o range:(NSRange)r {
    if(r.location>size || r.length>size-r.location) @throw [NSException alloc];
    return strncasecmp(bytes+r.location,s->bytes,r.length);
}
PRODUCTION_NUMERIC_METHODS
@end
static unsigned failures, assertions;
#define CHECK(expr) do { assertions++; if(!(expr)) { failures++;printf("FAIL line %d: %s\n",__LINE__,#expr); } } while(0)
#define VALUE(expr,want) do { @try { CHECK((expr)==(want)); } @catch(NSException *e) { failures++;printf("FAIL line %d: %s raised bounds exception\n",__LINE__,#expr); } } while(0)
int main(void) {
    setvbuf(stdout,NULL,_IONBF,0);
    struct { const char *text; long long integer; double real; BOOL boolean; } cases[]={
        {"-42",-42,-42,YES}, {"  +17x",17,17,YES}, {"YES",0,0,YES},
        {"true",0,0,YES}, {"0",0,0,NO}, {"1e20",1,1e20,YES}, {"junk",0,0,NO},
        {"9223372036854775807",LLONG_MAX,9.2233720368547758e18,YES},
        {"-9223372036854775808",LLONG_MIN,-9.2233720368547758e18,YES},
        {"9223372036854775808",LLONG_MAX,9.2233720368547758e18,YES},
        {"",0,0,NO}, {" \t",0,0,NO}, {"+",0,0,NO}, {"-",0,0,NO},
        {"1",1,1,YES}, {"12.5",12,12.5,YES}, {"-2.5e-3",-2,-0.0025,YES},
        {"12tail",12,12,YES}, {" \n\t42",42,42,YES},
    };
    for(NSUInteger i=0;i<sizeof(cases)/sizeof(*cases);i++) {
        NSString *s=string(cases[i].text);
        VALUE([s longLongValue],cases[i].integer);
        VALUE([s doubleValue],cases[i].real);
        VALUE([s boolValue],cases[i].boolean);
    }
    const char *yes[]={"Y","y","T","t","Yanything","tuesday","+0001","-0001","0009","-000T"};
    const char *no[]={"N","n","F","f","0","000","-000","+000","000.1","x"};
    for(NSUInteger i=0;i<sizeof(yes)/sizeof(*yes);i++)VALUE([string(yes[i]) boolValue],YES);
    for(NSUInteger i=0;i<sizeof(no)/sizeof(*no);i++)VALUE([string(no[i]) boolValue],NO);
    VALUE([string("17") intValue],17);
    VALUE([string("-42") integerValue],-42);
    VALUE([string("2.5") floatValue],2.5f);
    char huge[601];memset(huge,'9',600);huge[600]=0;
    VALUE([string(huge) longLongValue],LLONG_MAX);
    VALUE([string(huge) doubleValue],INFINITY);
    VALUE([string(huge) boolValue],YES);
    for(unsigned n=254;n<=257;n++) {
        char zeros[258];memset(zeros,'0',n);zeros[n]=0;
        VALUE([string(zeros) longLongValue],0);
        VALUE([string(zeros) doubleValue],0);
        VALUE([string(zeros) boolValue],NO);
    }
    printf("numeric conversion regression: %u assertions, %u failures\n",assertions,failures);
    return failures?1:0;
}
