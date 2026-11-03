/* Linux libobjc test doubles. Production formatter/components compile unchanged
 * after imports are omitted. ICU performs Unicode operations; allocation and
 * Foundation collection/string/attribute primitives are doubles, not under test. */
#include <objc/runtime.h>
#include <objc/message.h>
#include <unicode/ustring.h>
#include <unicode/uchar.h>
#include <unicode/ubrk.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
typedef unsigned long NSUInteger;
typedef long NSInteger;
typedef unsigned short unichar;
typedef void NSZone;
typedef struct { NSUInteger location, length; } NSRange;
typedef struct { unsigned long state; id *itemsPtr; unsigned long *mutationsPtr; unsigned long extra[5]; } NSFastEnumerationState;
#define NSMakeRange(a,b) ((NSRange){a,b})
#define NSNotFound ((NSUInteger)-1)
#define NS_ENUM(t,n) t n; enum
#define NS_OPTIONS(t,n) t n; enum
#define FOUNDATION_EXPORT extern
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
@protocol NSCopying @end
@protocol NSSecureCoding @end
@class NSString, NSArray, NSDictionary, NSCoder;
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc; + (id)allocWithZone:(NSZone *)zone; + (id)new; + (Class)class;
- (Class)class; - (id)init; - (id)retain; - (id)autorelease; - (void)release; - (void)dealloc;
- (id)copy; - (id)copyWithZone:(NSZone *)zone; - (BOOL)isKindOfClass:(Class)c; - (BOOL)isEqual:(id)o;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self,0); }
+ (id)allocWithZone:(NSZone *)z { return [self alloc]; }
+ (id)new { return [[self alloc] init]; }
+ (Class)class { return self; }
- (Class)class { return object_getClass(self); }
- (id)init { return self; } - (id)retain { return self; } - (id)autorelease { return self; }
- (void)release {} - (void)dealloc {}
- (id)copy { return [self copyWithZone:NULL]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isKindOfClass:(Class)c { for(Class k=[self class]; k; k=class_getSuperclass(k)) if(k==c)return YES;return NO; }
- (BOOL)isEqual:(id)o { return self==o; }
@end
@interface NSCharacterSet : NSObject
+ (id)whitespaceAndNewlineCharacterSet;
@end
@implementation NSCharacterSet
+ (id)whitespaceAndNewlineCharacterSet { return [self new]; }
@end
@interface NSString : NSObject
- (NSUInteger)length; - (unichar)characterAtIndex:(NSUInteger)i; - (const char *)UTF8String;
- (NSString *)substringWithRange:(NSRange)r; - (NSString *)substringToIndex:(NSUInteger)i;
- (NSString *)stringByTrimmingCharactersInSet:(id)set; - (NSString *)lowercaseString;
- (NSRange)rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)i;
- (NSArray *)componentsSeparatedByCharactersInSet:(id)set;
- (BOOL)hasSuffix:(NSString *)s; - (NSUInteger)hash;
@end
@interface FixtureString : NSString { @public UChar *text; NSUInteger size; }
+ (id)fromUnits:(const UChar *)s length:(NSUInteger)n;
@end
@interface FixtureConstantString : NSString { const char *bytes; unsigned int byteCount; }
@end
@interface NSMutableString : FixtureString
+ (id)string; - (void)appendString:(NSString *)s;
@end
static UChar *units(NSString *s) { NSUInteger n=[s length]; UChar *r=calloc(n+1,2);for(NSUInteger i=0;i<n;i++)r[i]=[s characterAtIndex:i];return r; }
@implementation NSString
- (NSString *)substringWithRange:(NSRange)r { assert(r.location+r.length<=[self length]);UChar *s=units(self);id v=[FixtureString fromUnits:s+r.location length:r.length];free(s);return v; }
- (NSString *)substringToIndex:(NSUInteger)i { return [self substringWithRange:NSMakeRange(0,i)]; }
- (const char *)UTF8String { UChar *s=units(self);char *b=calloc(4*[self length]+1,1);UErrorCode e=U_ZERO_ERROR;u_strToUTF8(b,4*[self length]+1,NULL,s,[self length],&e);assert(U_SUCCESS(e));free(s);return b; }
- (NSString *)stringByTrimmingCharactersInSet:(id)set {NSUInteger a=0,b=[self length];while(a<b&&u_isUWhiteSpace([self characterAtIndex:a]))a++;while(b>a&&u_isUWhiteSpace([self characterAtIndex:b-1]))b--;return [self substringWithRange:NSMakeRange(a,b-a)];}
- (NSString *)lowercaseString {UChar *s=units(self);for(NSUInteger i=0;i<[self length];i++)s[i]=u_tolower(s[i]);id r=[FixtureString fromUnits:s length:[self length]];free(s);return r;}
- (BOOL)isEqual:(id)o {if(![o isKindOfClass:[NSString class]]||[self length]!=[o length])return NO;for(NSUInteger i=0;i<[self length];i++)if([self characterAtIndex:i]!=[o characterAtIndex:i])return NO;return YES;}
- (NSUInteger)hash {NSUInteger h=0;for(NSUInteger i=0;i<[self length];i++)h=h*31+[self characterAtIndex:i];return h;}
- (BOOL)hasSuffix:(NSString *)s {NSUInteger a=[self length],b=[s length];return a>=b&&[[self substringWithRange:NSMakeRange(a-b,b)]isEqual:s];}
- (NSRange)rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)i {UChar *s=units(self);UErrorCode e=U_ZERO_ERROR;UBreakIterator *b=ubrk_open(UBRK_CHARACTER,"en_US",s,[self length],&e);assert(U_SUCCESS(e));int end=ubrk_following(b,i);ubrk_close(b);free(s);return NSMakeRange(i,end-i);}
@end
@implementation FixtureString
+ (id)fromUnits:(const UChar *)s length:(NSUInteger)n {FixtureString *r=[self new];r->size=n;r->text=calloc(n+1,2);memcpy(r->text,s,n*2);return r;}
- (NSUInteger)length {return size;}
- (unichar)characterAtIndex:(NSUInteger)i {assert(i<size);return text[i];}
@end
@implementation FixtureConstantString
- (NSUInteger)length {UErrorCode e=U_ZERO_ERROR;int n=0;u_strFromUTF8(NULL,0,&n,bytes,byteCount,&e);return n;}
- (unichar)characterAtIndex:(NSUInteger)i {UChar *s=calloc(2*[self length]+2,1);UErrorCode e=U_ZERO_ERROR;u_strFromUTF8(s,[self length]+1,NULL,bytes,byteCount,&e);assert(U_SUCCESS(e)&&i<[self length]);unichar c=s[i];free(s);return c;}
@end
@implementation NSMutableString
+ (id)string {return [self new];}
- (void)appendString:(NSString *)s {NSUInteger old=size;size+=[s length];text=realloc(text,(size+1)*2);for(NSUInteger i=old;i<size;i++)text[i]=[s characterAtIndex:i-old];text[size]=0;}
@end
@interface NSArray : NSObject { @public id elements[128]; NSUInteger count; unsigned long mutations; }
+ (id)array; + (id)arrayWithObjects:(const id *)objects count:(NSUInteger)n;
- (NSUInteger)count; - (id)objectAtIndex:(NSUInteger)i; - (id)lastObject;
- (BOOL)containsObject:(id)o; - (id)subarrayWithRange:(NSRange)r; - (id)componentsJoinedByString:(NSString *)s;
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)s objects:(id *)b count:(NSUInteger)n;
@end
@interface NSMutableArray : NSArray
- (void)addObject:(id)o; - (void)removeObjectAtIndex:(NSUInteger)i; - (void)removeLastObject; - (void)removeObjectsInRange:(NSRange)r;
@end
@implementation NSArray
+ (id)array {return [self new];}
+ (id)arrayWithObjects:(const id *)objects count:(NSUInteger)n {assert(n<=128);NSArray *a=[self new];memcpy(a->elements,objects,n*sizeof(id));a->count=n;return a;}
- (NSUInteger)count {return count;}
- (id)objectAtIndex:(NSUInteger)i {assert(i<count);return elements[i];}
- (id)lastObject {return count?elements[count-1]:nil;}
- (BOOL)containsObject:(id)o {for(NSUInteger i=0;i<count;i++)if([elements[i]isEqual:o])return YES;return NO;}
- (id)subarrayWithRange:(NSRange)r {assert(r.location+r.length<=count);return [NSArray arrayWithObjects:elements+r.location count:r.length];}
- (id)componentsJoinedByString:(NSString *)s {NSMutableString *r=[NSMutableString string];for(NSUInteger i=0;i<count;i++){if(i)[r appendString:s];[r appendString:elements[i]];}return r;}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)s objects:(id *)b count:(NSUInteger)n {if(s->state)return 0;s->state=1;s->itemsPtr=elements;s->mutationsPtr=&mutations;return count;}
@end
@implementation NSMutableArray
- (void)addObject:(id)o {assert(count<128&&o);elements[count++]=o;}
- (void)removeObjectAtIndex:(NSUInteger)i {[self removeObjectsInRange:NSMakeRange(i,1)];}
- (void)removeLastObject {assert(count);count--;}
- (void)removeObjectsInRange:(NSRange)r {assert(r.location+r.length<=count);memmove(elements+r.location,elements+r.location+r.length,(count-r.location-r.length)*sizeof(id));count-=r.length;}
@end
@implementation NSString (Split)
- (NSArray *)componentsSeparatedByCharactersInSet:(id)set {NSMutableArray *a=[NSMutableArray array];NSUInteger start=0,n=[self length];for(NSUInteger i=0;i<=n;i++)if(i==n||u_isUWhiteSpace([self characterAtIndex:i])){[a addObject:[self substringWithRange:NSMakeRange(start,i-start)]];start=i+1;}return a;}
@end
@interface NSDictionary : NSObject { id keys[16], values[16]; NSUInteger count; }
+ (id)dictionaryWithObjects:(const id *)v forKeys:(const id *)k count:(NSUInteger)n;
- (id)objectForKey:(id)k;
@end
@implementation NSDictionary
+ (id)dictionaryWithObjects:(const id *)v forKeys:(const id *)k count:(NSUInteger)n {assert(n<=16);NSDictionary *d=[self new];memcpy(d->keys,k,n*sizeof(id));memcpy(d->values,v,n*sizeof(id));d->count=n;return d;}
- (id)objectForKey:(id)k {for(NSUInteger i=0;i<count;i++)if([keys[i]isEqual:k])return values[i];return nil;}
@end
@interface NSAttributedString : NSObject { @public NSMutableString *text; id attributes[1024]; }
- (id)initWithString:(NSString *)s; - (id)initWithString:(NSString *)s attributes:(id)a;
- (NSString *)string; - (NSUInteger)length; - (id)attribute:(id)k atIndex:(NSUInteger)i effectiveRange:(NSRange *)r;
@end
@interface NSMutableAttributedString : NSAttributedString
- (void)appendAttributedString:(NSAttributedString *)s;
@end
@implementation NSAttributedString
- (id)initWithString:(NSString *)s {return [self initWithString:s attributes:nil];}
- (id)initWithString:(NSString *)s attributes:(id)a {text=[NSMutableString string];[text appendString:s];assert([s length]<1024);for(NSUInteger i=0;i<[s length];i++)attributes[i]=a;return self;}
- (NSString *)string {return text;}
- (NSUInteger)length {return [text length];}
- (id)attribute:(id)k atIndex:(NSUInteger)i effectiveRange:(NSRange *)r {assert(i<[text length]);return [attributes[i]objectForKey:k];}
@end
@implementation NSMutableAttributedString
- (void)appendAttributedString:(NSAttributedString *)s {NSUInteger n=[text length];assert(n+[s length]<1024);memcpy(attributes+n,s->attributes,[s length]*sizeof(id));[text appendString:[s string]];}
- (id)copyWithZone:(NSZone *)z {NSAttributedString *r=[[NSAttributedString alloc]initWithString:text];memcpy(r->attributes,attributes,[text length]*sizeof(id));return r;}
@end
@interface NSLocale : NSObject
+ (id)autoupdatingCurrentLocale;
@end
@implementation NSLocale
+ (id)autoupdatingCurrentLocale {static id locale;if(!locale)locale=[self new];return locale;}
@end
@interface NSException : NSObject
+ (void)raise:(id)name format:(id)format,...;
@end
static NSString *NSInvalidArgumentException=@"NSInvalidArgumentException";
@implementation NSException
+ (void)raise:(id)name format:(id)format,... { @throw [self new]; }
@end
@interface NSCoder : NSObject { @public BOOL keyed; NSUInteger cursor, count; id keys[16], objects[16]; long values[16]; }
- (BOOL)allowsKeyedCoding; - (void)encodeInteger:(NSInteger)v forKey:(id)k; - (void)encodeBool:(BOOL)v forKey:(id)k;
- (void)encodeObject:(id)o forKey:(id)k; - (id)decodeObjectOfClass:(Class)c forKey:(id)k;
- (NSInteger)decodeIntegerForKey:(id)k; - (BOOL)decodeBoolForKey:(id)k;
- (void)encodeValueOfObjCType:(const char *)t at:(const void *)v; - (void)decodeValueOfObjCType:(const char *)t at:(void *)v;
- (void)encodeObject:(id)o; - (id)decodeObject;
@end
@implementation NSCoder
- (BOOL)allowsKeyedCoding {return keyed;}
- (void)encodeInteger:(NSInteger)v forKey:(id)k {assert(count<16);keys[count]=k;values[count++]=v;}
- (void)encodeBool:(BOOL)v forKey:(id)k {[self encodeInteger:v forKey:k];}
- (void)encodeObject:(id)o forKey:(id)k {assert(count<16);keys[count]=k;objects[count++]=o;}
- (NSInteger)decodeIntegerForKey:(id)k {for(NSUInteger i=0;i<count;i++)if([keys[i]isEqual:k])return values[i];return 0;}
- (BOOL)decodeBoolForKey:(id)k {return [self decodeIntegerForKey:k];}
- (id)decodeObjectOfClass:(Class)c forKey:(id)k {for(NSUInteger i=0;i<count;i++)if([keys[i]isEqual:k])return objects[i];return nil;}
- (void)encodeValueOfObjCType:(const char *)t at:(const void *)v {assert(count<16);memcpy(values+count++,v,!strcmp(t,@encode(BOOL))?sizeof(BOOL):sizeof(NSInteger));}
- (void)decodeValueOfObjCType:(const char *)t at:(void *)v {assert(cursor<count);memcpy(v,values+cursor++,!strcmp(t,@encode(BOOL))?sizeof(BOOL):sizeof(NSInteger));}
- (void)encodeObject:(id)o {assert(count<16);objects[count++]=o;}
- (id)decodeObject {assert(cursor<count);return objects[cursor++];}
@end
@interface NSFormatter : NSObject
- (id)initWithCoder:(NSCoder *)c; - (void)encodeWithCoder:(NSCoder *)c;
@end
@implementation NSFormatter
- (id)initWithCoder:(NSCoder *)c {return self;} - (void)encodeWithCoder:(NSCoder *)c {}
@end
