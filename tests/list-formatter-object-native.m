/* Linux/libobjc fixture: production NSListFormatter implementation and ICU,
 * with minimal object/array/string/locale/coder doubles. Not a Foundation runtime test. */
#include <objc/runtime.h>
#include <objc/message.h>
#include <unicode/ustring.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
typedef unsigned long NSUInteger;
typedef void NSZone;
typedef struct { NSUInteger location, length; } NSRange;
static NSRange NSMakeRange(NSUInteger a, NSUInteger b) { return (NSRange){a,b}; }
@protocol NSCopying @end
@protocol NSCoding @end
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
+ (id)allocWithZone:(NSZone *)zone;
+ (id)new;
+ (Class)class;
- (Class)class;
- (id)init;
- (id)retain;
- (id)autorelease;
- (void)release;
- (void)dealloc;
- (id)copy;
- (id)copyWithZone:(NSZone *)zone;
- (BOOL)isKindOfClass:(Class)cls;
- (BOOL)respondsToSelector:(SEL)selector;
- (id)description;
@end
@interface NSObject (LocaleDescription)
- (id)descriptionWithLocale:(id)locale;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self,0); }
+ (id)allocWithZone:(NSZone *)zone { return [self alloc]; }
+ (id)new { return [[self alloc] init]; }
+ (Class)class { return self; }
- (Class)class { return object_getClass(self); }
- (id)init { return self; }
- (id)retain { return self; }
- (id)autorelease { return self; }
- (void)release {}
- (void)dealloc {}
- (id)copy { return [self copyWithZone:NULL]; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (BOOL)isKindOfClass:(Class)cls { for(Class c=[self class];c;c=class_getSuperclass(c))if(c==cls)return YES;return NO; }
- (BOOL)respondsToSelector:(SEL)selector { return class_getInstanceMethod([self class],selector)!=NULL; }
- (id)description { return @"object"; }
@end
@interface NSString : NSObject { @public const char *bytes; unsigned int size; }
+ (id)stringWithUTF8String:(const char *)text;
+ (id)stringWithCharacters:(const UChar *)text length:(NSUInteger)length;
- (const char *)UTF8String;
- (NSUInteger)length;
- (void)getCharacters:(UChar *)text range:(NSRange)range;
- (BOOL)isEqualToString:(NSString *)other;
@end
@interface FixtureConstantString : NSString @end
@implementation FixtureConstantString @end
@implementation NSString
+ (id)stringWithUTF8String:(const char *)text { NSString *s=[self new];s->bytes=strdup(text);s->size=strlen(text);return s; }
+ (id)stringWithCharacters:(const UChar *)text length:(NSUInteger)length {
    UErrorCode status=U_ZERO_ERROR;int32_t n;
    u_strToUTF8(NULL,0,&n,text,length,&status);status=U_ZERO_ERROR;
    NSString *s=[self new];char *b=calloc(n+1,1);u_strToUTF8(b,n+1,NULL,text,length,&status);
    assert(U_SUCCESS(status));s->bytes=b;s->size=n;return s;
}
- (const char *)UTF8String { return bytes; }
- (NSUInteger)length { UErrorCode s=U_ZERO_ERROR;int32_t n;u_strFromUTF8(NULL,0,&n,bytes,size,&s);return n; }
- (void)getCharacters:(UChar *)text range:(NSRange)range {
    UErrorCode s=U_ZERO_ERROR;int32_t n=[self length];UChar *b=calloc(n+1,sizeof(UChar));
    u_strFromUTF8(b,n+1,NULL,bytes,size,&s);assert(U_SUCCESS(s));memcpy(text,b+range.location,range.length*sizeof(UChar));free(b);
}
- (BOOL)isEqualToString:(NSString *)other { return other && size==other->size && !memcmp(bytes,other->bytes,size); }
- (id)description { return self; }
@end
@interface NSArray<__covariant ObjectType> : NSObject { id *values; NSUInteger size; }
+ (id)arrayWithObjects:(const id [])objects count:(NSUInteger)count;
- (NSUInteger)count;
- (id)objectAtIndex:(NSUInteger)index;
@end
@implementation NSArray
+ (id)arrayWithObjects:(const id [])objects count:(NSUInteger)count { NSArray *a=[self new];a->size=count;a->values=calloc(count?count:1,sizeof(id));memcpy(a->values,objects,count*sizeof(id));return a; }
- (NSUInteger)count { return size; }
- (id)objectAtIndex:(NSUInteger)index { assert(index<size);return values[index]; }
@end
@interface NSLocale : NSObject { NSString *identifier; }
+ (id)autoupdatingCurrentLocale;
- (id)initWithLocaleIdentifier:(NSString *)value;
- (NSString *)localeIdentifier;
@end
@implementation NSLocale
+ (id)autoupdatingCurrentLocale { static id locale;if(!locale)locale=[[self alloc]initWithLocaleIdentifier:@"en_US_POSIX"];return locale; }
- (id)initWithLocaleIdentifier:(NSString *)value { identifier=value;return self; }
- (NSString *)localeIdentifier { return identifier; }
@end
@interface NSCoder : NSObject { @public BOOL keyed; id values[2]; int position; }
- (BOOL)allowsKeyedCoding;
- (void)encodeObject:(id)object forKey:(NSString *)key;
- (id)decodeObjectForKey:(NSString *)key;
- (void)encodeObject:(id)object;
- (id)decodeObject;
@end
@implementation NSCoder
- (BOOL)allowsKeyedCoding { return keyed; }
- (void)encodeObject:(id)object forKey:(NSString *)key { values[[key isEqualToString:@"locale"]?0:1]=object; }
- (id)decodeObjectForKey:(NSString *)key { return values[[key isEqualToString:@"locale"]?0:1]; }
- (void)encodeObject:(id)object { values[position++]=object; }
- (id)decodeObject { return values[position++]; }
@end
@interface NSFormatter : NSObject
- (NSString *)stringForObjectValue:(id)object;
@end
@implementation NSFormatter
- (NSString *)stringForObjectValue:(id)object { return nil; }
@end

PRODUCTION_HEADER
PRODUCTION_IMPLEMENTATION
static void FixtureCheckCoding(void)
{
    for (int keyed = 0; keyed < 2; ++keyed) {
        NSListFormatter *f = [NSListFormatter new];
        f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"fr_FR"];
        f.itemFormatter = [NSFormatter new];
        NSCoder *coder = [NSCoder new]; coder->keyed = keyed;
        [f encodeWithCoder:coder]; coder->position = 0;
        NSListFormatter *decoded = [[NSListFormatter alloc] initWithCoder:coder];
        assert([[decoded.locale localeIdentifier] isEqualToString:@"fr_FR"]);
        assert(decoded.itemFormatter == f.itemFormatter);
        assert(([[decoded stringFromItems:@[@"a", @"b"]] isEqualToString:@"a et b"]));
    }
}
PUBLIC_REGRESSION
