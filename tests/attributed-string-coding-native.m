// Controlled native objects/coder/CF doubles. Production methods are inserted
// by attributed-string-coding-native.py; no Apple archive data is used.
#include <objc/objc.h>
#include <objc/runtime.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>
#include <limits.h>
typedef unsigned long NSUInteger;
#define NSUIntegerMax ULONG_MAX
typedef struct { NSUInteger location,length; } NSRange;
static NSRange NSMakeRange(NSUInteger a,NSUInteger b) { return (NSRange){a,b}; }
static NSUInteger NSMaxRange(NSRange r) { return r.location+r.length; }
typedef void NSZone;
@class NSString, NSCoder, NSAttributedString, NSMutableAttributedString;
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc; + (id)new; + (id)allocWithZone:(void *)z; + (Class)class; + (id)self;
- (id)init; - (id)retain; - (void)release; - (Class)class; - (BOOL)isKindOfClass:(Class)c;
@end
@implementation NSObject
+ (id)alloc { return [self allocWithZone:NULL]; }
+ (id)new { return [[self alloc] init]; }
+ (id)allocWithZone:(void *)z { return class_createInstance(self,0); }
+ (Class)class { return self; } + (id)self { return self; }
- (id)init { return self; } - (id)retain { return self; } - (void)release {}
- (Class)class { return object_getClass(self); }
- (BOOL)isKindOfClass:(Class)c { for(Class k=object_getClass(self);k;k=class_getSuperclass(k)) if(k==c)return YES;return NO; }
@end
@interface NSString : NSObject
- (NSUInteger)length; - (const char *)UTF8String;
@end
@implementation NSString
- (NSUInteger)length { return strlen([self UTF8String]); }
- (const char *)UTF8String { return ""; }
@end
@interface FixtureString : NSString { @public const char *bytes; unsigned int size; } @end
@implementation FixtureString
- (NSUInteger)length { return size; } - (const char *)UTF8String { return bytes; }
@end
@interface NSDictionary : NSObject { @public int token; }
@end
@implementation NSDictionary @end
@interface NSArray : NSObject { @public id objects[512]; NSUInteger count; }
- (NSUInteger)count; - (id)objectAtIndex:(NSUInteger)i;
@end
@implementation NSArray
- (NSUInteger)count { return count; } - (id)objectAtIndex:(NSUInteger)i { assert(i<count);return objects[i]; }
@end
@interface NSMutableArray : NSArray
+ (id)array; - (void)addObject:(id)obj;
@end
@implementation NSMutableArray
+ (id)array { return [self new]; } - (void)addObject:(id)obj { assert(obj&&count<512);objects[count++]=obj; }
@end
@interface NSData : NSObject { @public uint8_t storage[8192]; NSUInteger size; }
- (const void *)bytes; - (NSUInteger)length;
@end
@implementation NSData
- (const void *)bytes { return storage; } - (NSUInteger)length { return size; }
@end
@interface NSMutableData : NSData
+ (id)data; - (void)appendBytes:(const void *)p length:(NSUInteger)n;
@end
@implementation NSMutableData
+ (id)data { return [self new]; }
- (void)appendBytes:(const void *)p length:(NSUInteger)n { assert(size+n<=sizeof(storage));memcpy(storage+size,p,n);size+=n; }
@end
@interface NSException : NSObject
+ (void)raise:(id)name format:(id)format,...;
@end
static id NSInvalidUnarchiveOperationException=@"invalid archive",NSInvalidArgumentException=@"invalid argument";
@implementation NSException
+ (void)raise:(id)n format:(id)f,... { @throw [self new]; }
@end
@interface NSCoder : NSObject { @public BOOL keyed; NSString *keys[4]; id values[4]; NSUInteger count,next; }
- (BOOL)allowsKeyedCoding; - (id)decodeObjectForKey:(NSString *)k; - (void)encodeObject:(id)o forKey:(NSString *)k;
- (id)decodeObject; - (void)encodeObject:(id)o;
@end
@implementation NSCoder
- (BOOL)allowsKeyedCoding { return keyed; }
- (id)decodeObjectForKey:(NSString *)k { for(NSUInteger i=0;i<count;i++)if(!strcmp([keys[i] UTF8String],[k UTF8String]))return values[i];return nil; }
- (void)encodeObject:(id)o forKey:(NSString *)k { assert(count<4);keys[count]=k;values[count++]=o; }
- (id)decodeObject { assert(next<count);return values[next++]; }
- (void)encodeObject:(id)o { assert(count<4);values[count++]=o; }
@end
@interface NSAttributedString : NSObject
+ (id)allocWithZone:(void *)zone;
- (id)initWithString:(NSString *)s; - (id)initWithString:(NSString *)s attributes:(NSDictionary *)a;
- (id)initWithAttributedString:(NSAttributedString *)s;
- (NSString *)string; - (NSUInteger)length; - (NSDictionary *)attributesAtIndex:(NSUInteger)i effectiveRange:(NSRange *)r;
- (id)initWithCoder:(NSCoder *)c; - (void)encodeWithCoder:(NSCoder *)c; - (Class)classForCoder;
@end
@interface NSMutableAttributedString : NSAttributedString
- (void)setAttributes:(NSDictionary *)d range:(NSRange)r;
@end
@interface __NSPlaceholderAttributedString : NSAttributedString
+ (id)mutablePlaceholder; + (id)immutablePlaceholder;
@end
// Deliberately independent inheritance, as in the production CF cluster.
@interface __NSCFType : NSObject @end
@implementation __NSCFType @end
@interface __NSCFAttributedString : __NSCFType { @public NSString *text; NSDictionary *attrs[1024]; BOOL mutableFlag; }
- (id)initWithCoder:(NSCoder *)c; - (void)encodeWithCoder:(NSCoder *)c; - (Class)classForCoder;
- (NSString *)string; - (NSUInteger)length; - (NSDictionary *)attributesAtIndex:(NSUInteger)i effectiveRange:(NSRange *)r;
- (void)setAttributes:(NSDictionary *)d range:(NSRange)r;
@end
typedef id CFAttributedStringRef; typedef id CFMutableAttributedStringRef;
typedef id CFStringRef; typedef id CFDictionaryRef;
#define kCFAllocatorDefault NULL
static __NSPlaceholderAttributedString *immutablePlaceholder,*mutablePlaceholder;
static NSDictionary *empty;
static BOOL throwTemporary;
static int temporaryReleases;
static id CFAttributedStringCreate(void *a,id s,id d) {
 if(throwTemporary) @throw [NSException new];
 __NSCFAttributedString *r=class_createInstance([__NSCFAttributedString class],0);r->text=s;
 assert([s length]<1024);for(NSUInteger i=0;i<[s length];i++)r->attrs[i]=d?:empty;return r;
}
static void _CFAttributedStringSetMutable(id r,BOOL b) { ((__NSCFAttributedString *)r)->mutableFlag=b; }
static BOOL _CFAttributedStringIsMutable(id r) { return ((__NSCFAttributedString *)r)->mutableFlag; }
static id CFAttributedStringCreateCopy(void *a,id value) {
 __NSCFAttributedString *v=value,*r=CFAttributedStringCreate(a,v->text,nil);
 memcpy(r->attrs,v->attrs,sizeof(r->attrs));return r;
}
static id CFAttributedStringCreateMutableCopy(void *a,int n,id v) { id r=CFAttributedStringCreateCopy(a,v);_CFAttributedStringSetMutable(r,YES);return r; }
@implementation NSAttributedString
+ (id)alloc { return [self allocWithZone:NULL]; }
ALLOC_METHOD
- (id)initWithString:(NSString *)s { return [self initWithString:s attributes:nil]; }
- (Class)classForCoder { return [NSAttributedString class]; }
CODING_METHODS
@end
@implementation NSMutableAttributedString
MUTABLE_CLASS_METHOD
@end
static int placeholderReleases;
@implementation __NSPlaceholderAttributedString
- (void)release { placeholderReleases++; }
+ (id)immutablePlaceholder { return immutablePlaceholder; }
+ (id)mutablePlaceholder { return mutablePlaceholder; }
PLACEHOLDER_INIT_METHODS
@end
@implementation __NSCFAttributedString
- (void)release { temporaryReleases++;object_dispose(self); }
CF_CODING_METHODS
- (NSString *)string { return text; } - (NSUInteger)length { return [text length]; }
- (NSDictionary *)attributesAtIndex:(NSUInteger)i effectiveRange:(NSRange *)r {
 assert(i<[text length]);NSUInteger start=i,end=i+1;
 while(start&&attrs[start-1]==attrs[i])start--;
 while(end<[text length]&&attrs[end]==attrs[i])end++;
 if(r)*r=NSMakeRange(start,end-start);return attrs[i];
}
- (void)setAttributes:(NSDictionary *)d range:(NSRange)r { assert(mutableFlag&&NSMaxRange(r)<1024);for(NSUInteger i=r.location;i<NSMaxRange(r);i++)attrs[i]=d; }
@end
static void same(id a,id b) {
 assert(!strcmp([[a string] UTF8String],[[b string] UTF8String]));
 for(NSUInteger i=0;i<[a length];i++)assert([a attributesAtIndex:i effectiveRange:NULL]==[b attributesAtIndex:i effectiveRange:NULL]);
}
// Owned subclass: unlike the cluster placeholders, failure must dispose it.
static int ownedReleases;
@interface OwnedAttributedString:NSAttributedString @end
@implementation OwnedAttributedString
- (void)release { ownedReleases++;object_dispose(self); }
- (id)initWithAttributedString:(NSAttributedString *)s {
 [self release]; // The delegated initializer owns receiver failure cleanup.
 @throw [NSException new];
}
@end
@interface ThrowingCoder:NSCoder { @public NSUInteger failAt,decodedFields; }
@end
@implementation ThrowingCoder
- (id)decodeObjectForKey:(NSString *)k {
 if(decodedFields++==failAt) @throw [NSException new];
 return [super decodeObjectForKey:k];
}
- (id)decodeObject {
 if(decodedFields++==failAt) @throw [NSException new];
 return [super decodeObject];
}
@end
static int throwingCoderTests(BOOL keyed) {
 for(NSUInteger field=0;field<3;field++) {
  ThrowingCoder *coder=[ThrowingCoder new];coder->keyed=keyed;coder->failAt=field;
  if(keyed)[coder encodeObject:@"abc" forKey:@"NSString"];
  else{[coder encodeObject:@"abc"];[coder encodeObject:nil];[coder encodeObject:nil];}
  int before=ownedReleases;BOOL caught=NO;
  @try{[[[OwnedAttributedString class]alloc]initWithCoder:coder];}@catch(id e){caught=YES;}
  assert(caught);
  if(ownedReleases!=before+1){printf("FAIL: %s throwing coder field %lu released receiver %d times\n",keyed?"keyed":"unkeyed",field,ownedReleases-before);return 1;}
 }
 printf("PASS: %s throwing coder at each field releases owned receiver once\n",keyed?"keyed":"unkeyed");return 0;
}
static int throwingInitTests(BOOL temporary) {
 NSCoder *coder=[NSCoder new];coder->keyed=YES;[coder encodeObject:@"abc" forKey:@"NSString"];
 int ownedBefore=ownedReleases,tempBefore=temporaryReleases;BOOL caught=NO;
 throwTemporary=temporary;
 @try{[[[OwnedAttributedString class]alloc]initWithCoder:coder];}@catch(id e){caught=YES;}
 throwTemporary=NO;assert(caught);
 if(ownedReleases!=ownedBefore+1){printf("FAIL: throwing %s initializer released receiver %d times\n",temporary?"temporary":"final",ownedReleases-ownedBefore);return 1;}
 if(temporaryReleases!=tempBefore+(temporary?0:1)){puts("FAIL: temporary leaked by throwing final initializer");return 1;}
 printf("PASS: throwing %s initializer cleanup without double receiver release\n",temporary?"temporary":"final");return 0;
}
int main(void) {
 empty=[NSDictionary new];
 immutablePlaceholder=class_createInstance([__NSPlaceholderAttributedString class],0);
 mutablePlaceholder=class_createInstance([__NSPlaceholderAttributedString class],0);
 if(!class_getInstanceMethod([NSAttributedString class],@selector(initWithCoder:))) {
  puts("FAIL missing NSAttributedString initWithCoder:");return 1;
 }
 for(int keyed=0;keyed<2;keyed++)for(int mut=0;mut<2;mut++)for(int kind=0;kind<3;kind++) {
  Class cls=mut?[NSMutableAttributedString class]:[NSAttributedString class];
  id input=[[cls alloc]initWithString:kind==0?@"":@"abcdef" attributes:empty];
  if(kind==2) { NSDictionary *d=[NSDictionary new];((__NSCFAttributedString *)input)->attrs[2]=d;((__NSCFAttributedString *)input)->attrs[3]=d; }
  NSCoder *c=[NSCoder new];c->keyed=keyed;[input encodeWithCoder:c];
  assert([input classForCoder]==cls);
  id result=[[[input classForCoder]alloc]initWithCoder:c];same(input,result);
  assert([result classForCoder]==cls);
  assert(((__NSCFAttributedString *)result)->mutableFlag==mut);
 }
 NSCoder *plain=[NSCoder new];plain->keyed=YES;
 [plain encodeObject:@"plain" forKey:@"NSString"];
 id noOptional=[[[NSMutableAttributedString class]alloc]initWithCoder:plain];
 assert(!strcmp([[noOptional string]UTF8String],"plain"));
 assert([noOptional attributesAtIndex:0 effectiveRange:NULL]==empty);
 // Exercise the concrete-class initializer as well as placeholder inheritance.
 plain->next=0;
 id allocated=[__NSCFAttributedString alloc];assert(allocated==mutablePlaceholder);
 id direct=[allocated initWithCoder:plain];
 assert(!strcmp([[direct string]UTF8String],"plain"));
 // Own externally generated archive field cases are inserted here.
 OBSERVED_CASES
 if(FIXTURE_CASE==0||FIXTURE_CASE==1)if(throwingCoderTests(YES))return 1;
 if(FIXTURE_CASE==0||FIXTURE_CASE==2)if(throwingCoderTests(NO))return 1;
 if(FIXTURE_CASE==0||FIXTURE_CASE==3)if(throwingInitTests(NO))return 1;
 if(FIXTURE_CASE==0||FIXTURE_CASE==4)if(throwingInitTests(YES))return 1;
 // Invalid required fields must raise instead of silently losing content.
 for(int kind=0;kind<11;kind++) {
  NSCoder *bad=[NSCoder new];bad->keyed=YES;
  if(kind!=0)[bad encodeObject:kind==1?(id)empty:(id)@"abc" forKey:@"NSString"];
  if(kind>=2){
   NSMutableArray *a=[NSMutableArray array];[a addObject:empty];
   NSMutableData *data=[NSMutableData data];uint8_t bytes[16]={kind==2?0:kind==3?4:3,kind==4?1:0};
   NSUInteger size=2;
   if(kind==5)size=1; // truncated length/index pair
   if(kind==6){memset(bytes,0xff,sizeof(bytes));size=sizeof(bytes);} // overflow
   if(kind==7){bytes[2]=0;size=3;} // trailing run data
   if(kind==8)a->objects[0]=@"wrong attribute type";
   if(kind==9)size=0; // empty run stream for a nonempty string
   [data appendBytes:bytes length:size];
   [bad encodeObject:a forKey:@"NSAttributes"];
   if(kind!=10)[bad encodeObject:data forKey:@"NSAttributeInfo"];
  }
  int releases=placeholderReleases;
  BOOL caught=NO;@try{[[[NSAttributedString class]alloc]initWithCoder:bad];}@catch(id e){caught=YES;}
  assert(caught);
  // A rejected archive releases the receiver exactly once.
  if(placeholderReleases!=releases+1){printf("FAIL: invalid case %d released the receiver %d times\n",kind,placeholderReleases-releases);return 1;}
 }
 puts("PASS production coding methods: keyed/unkeyed roundtrips, cluster identity, optional keys, observed runs, invalid fields released once");
 return 0;
}
