/* Typed coder/storage doubles for the production methods inserted by the driver.
 * Wire parsing, allocation/cache and ownership are verified by the guest check. */
#include <objc/runtime.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
typedef unsigned long NSUInteger; typedef long NSInteger; typedef void NSZone;
typedef struct { NSUInteger location,length; } NSRange;
typedef struct { double x,y; } CGPoint;
typedef struct { double width,height; } CGSize;
typedef struct { CGPoint origin; CGSize size; } CGRect;
typedef struct { double a,b,c,d,tx,ty; } CGAffineTransform;
typedef struct { double top,left,bottom,right; } NSEdgeInsets;
typedef enum {NSNotSpecialType=0,NSPointType=1,NSSizeType=2,NSRectType=3,NSRangeType=4,NSAffineTransformType=9,NSEdgeInsetsType=10,NSEdgeType=11,NSCGRectType=0x2603} NSConcreteValueSpecialType;
#define NS_RETURNS_INNER_POINTER
#define MAX_STACK 1024
static unsigned checks;
#define CHECK(x) do {checks++;if(!(x)){fprintf(stderr,"FAIL %u: %s\n",__LINE__,#x);exit(1);}}while(0)
__attribute__((objc_root_class)) @interface NSObject { Class isa; }
+ (id)alloc; + (Class)class; - (id)retain; - (void)release; - (BOOL)isKindOfClass:(Class)c;
@end
@implementation NSObject
+ (id)alloc{return class_createInstance(self,0);} + (Class)class{return self;}
- (id)retain{return self;} - (void)release{}
- (BOOL)isKindOfClass:(Class)c{for(Class k=object_getClass(self);k;k=class_getSuperclass(k))if(k==c)return YES;return NO;}
@end
@interface NSString:NSObject { @public const char *text;unsigned size; }
+ (id)stringWithUTF8String:(const char *)s; - (const char *)UTF8String; - (BOOL)isEqual:(id)x;
@end
@implementation NSString
+ (id)stringWithUTF8String:(const char *)s{NSString *x=[self alloc];x->text=strdup(s);return x;}
- (const char *)UTF8String{return text;}
- (BOOL)isEqual:(id)x{return [x isKindOfClass:[NSString class]]&&!strcmp(text,((NSString *)x)->text);}
@end
@interface NSNumber:NSObject { @public NSUInteger n; }
+ (id)numberWithUnsignedInteger:(NSUInteger)v; - (NSUInteger)unsignedIntegerValue;
@end
@implementation NSNumber
+ (id)numberWithUnsignedInteger:(NSUInteger)v{NSNumber *x=[self alloc];x->n=v;return x;}
- (NSUInteger)unsignedIntegerValue{return n;}
@end
static id NSInvalidArgumentException=@"argument",NSInvalidUnarchiveOperationException=@"unarchive",NSInternalInconsistencyException=@"internal";
@interface NSException:NSObject
+ (void)raise:(id)n format:(id)f,...;
@end
@implementation NSException
+ (void)raise:(id)n format:(id)f,...{@throw [self alloc];}
@end
static const char *NSGetSizeAndAlignment(const char *t,NSUInteger *size,NSUInteger *alignment){
 NSUInteger n=!strcmp(t,@encode(int))?sizeof(int):!strcmp(t,@encode(NSRange))?sizeof(NSRange):!strcmp(t,@encode(CGPoint))?sizeof(CGPoint):!strcmp(t,@encode(CGSize))?sizeof(CGSize):!strcmp(t,@encode(CGRect))?sizeof(CGRect):!strcmp(t,@encode(short))?sizeof(short):0;
 if(size)*size=n;if(alignment)*alignment=1;return t+strlen(t);
}
static id NS_special=@"NS.special",NS_rangeval_location=@"NS.rangeval.location",NS_rangeval_length=@"NS.rangeval.length",NS_pointval=@"NS.pointval",NS_sizeval=@"NS.sizeval",NS_rectval=@"NS.rectval";
static id NS_atval_a,NS_atval_b,NS_atval_c,NS_atval_d,NS_atval_tx,NS_atval_ty,NS_edgeval_top,NS_edgeval_left,NS_edgeval_bottom,NS_edgeval_right;
@interface NSCoder:NSObject { @public id keys[16],objects[16];NSInteger integers[16];unsigned count;unsigned char bytes[256];NSUInteger length;BOOL keyed; }
- (void)decodeValueOfObjCType:(const char *)t at:(void *)p;
- (void)encodeValueOfObjCType:(const char *)t at:(const void *)p;
- (BOOL)allowsKeyedCoding; - (BOOL)containsValueForKey:(id)key;
- (void)encodeInteger:(NSInteger)n forKey:(id)k; - (NSInteger)decodeIntegerForKey:(id)k;
- (void)encodeObject:(id)x forKey:(id)k; - (id)decodeObjectForKey:(id)k; - (id)decodeObjectOfClass:(Class)c forKey:(id)k;
- (void)encodeBytes:(const uint8_t *)b length:(NSUInteger)n forKey:(id)k;
- (const uint8_t *)decodeBytesForKey:(id)k returnedLength:(NSUInteger *)n;
- (CGPoint)decodePointForKey:(id)k; - (CGSize)decodeSizeForKey:(id)k; - (CGRect)decodeRectForKey:(id)k;
- (void)encodePoint:(CGPoint)p forKey:(id)k; - (void)encodeSize:(CGSize)s forKey:(id)k;
- (double)decodeDoubleForKey:(id)k;
@end
static NSString *NSStringFromPoint(CGPoint p){char b[96];snprintf(b,sizeof b,"%.17g,%.17g",p.x,p.y);return [NSString stringWithUTF8String:b];}
static NSString *NSStringFromSize(CGSize s){return NSStringFromPoint((CGPoint){s.width,s.height});}
static CGPoint NSPointFromString(NSString *s){CGPoint p={0};sscanf([s UTF8String],"%lf,%lf",&p.x,&p.y);return p;}
static CGSize NSSizeFromString(NSString *s){CGPoint p=NSPointFromString(s);return (CGSize){p.x,p.y};}
#define NSPointFromCGPoint(x) (x)
#define NSSizeFromCGSize(x) (x)
#define NSPointToCGPoint(x) (x)
#define NSSizeToCGSize(x) (x)
@implementation NSCoder
- (void)encodeValueOfObjCType:(const char *)t at:(const void *)p {
 if(!strcmp(t,@encode(char *))) [self encodeObject:[NSString stringWithUTF8String:*(const char **)p] forKey:@"type"];
 else {NSGetSizeAndAlignment(t,&length,NULL);assert(length<=sizeof bytes);memcpy(bytes,p,length);}
}
- (void)decodeValueOfObjCType:(const char *)t at:(void *)p {
 if(!strcmp(t,@encode(char *))) *(const char **)p=[[self decodeObjectOfClass:[NSString class] forKey:@"type"] UTF8String];
 else {NSUInteger n=0;NSGetSizeAndAlignment(t,&n,NULL);assert(n==length);memcpy(p,bytes,n);}
}
- (BOOL)allowsKeyedCoding{return keyed;}
- (unsigned)slot:(id)key{for(unsigned i=0;i<count;i++)if([keys[i] isEqual:key])return i;assert(count<16);keys[count]=key;return count++;}
- (BOOL)containsValueForKey:(id)k{for(unsigned i=0;i<count;i++)if([keys[i] isEqual:k])return YES;return NO;}
- (void)encodeInteger:(NSInteger)n forKey:(id)k{integers[[self slot:k]]=n;}
- (NSInteger)decodeIntegerForKey:(id)k{unsigned i=[self slot:k];if(objects[i])@throw [NSException alloc];return integers[i];}
- (void)encodeObject:(id)x forKey:(id)k{objects[[self slot:k]]=x;}
- (id)decodeObjectForKey:(id)k{return objects[[self slot:k]];}
- (id)decodeObjectOfClass:(Class)c forKey:(id)k{id x=[self decodeObjectForKey:k];CHECK(!x||[x isKindOfClass:c]);return x;}
- (void)encodeBytes:(const uint8_t *)b length:(NSUInteger)n forKey:(id)k{assert(n<=sizeof bytes);memcpy(bytes,b,n);length=n;}
- (const uint8_t *)decodeBytesForKey:(id)k returnedLength:(NSUInteger *)n{*n=length;return bytes;}
- (double)decodeDoubleForKey:(id)k{return 0;}
- (CGRect)decodeRectForKey:(id)k{return (CGRect){0};}
GEOMETRY_METHODS
@end
@interface NSValue:NSObject
- (CGPoint)pointValue; - (CGSize)sizeValue; - (CGRect)rectValue;
- (const char *)objCType; - (void)getValue:(void *)p; - (void)getValue:(void *)p size:(NSUInteger)n;
- (id)initWithCoder:(NSCoder *)c; - (void)encodeWithCoder:(NSCoder *)c; - (id)copyWithZone:(NSZone *)z;
- (BOOL)isEqualToValue:(NSValue *)v; - (BOOL)isEqual:(id)v; - (NSRange)rangeValue;
@end
typedef struct {int size;const char *name;} NSValueTypeInfo;
@interface NSConcreteValue:NSValue { @public NSConcreteValueSpecialType _specialFlags;NSValueTypeInfo *typeInfo;unsigned char storage[256]; }
- (const void *)_value;
@end
static void *object_getIndexedIvarsFixture(id x){return ((NSConcreteValue *)x)->storage;}
#define object_getIndexedIvars object_getIndexedIvarsFixture
static NSValue *createValue(void *b,const char *t,NSUInteger n,NSConcreteValueSpecialType f){
 NSConcreteValue *x=[NSConcreteValue alloc];x->_specialFlags=f;x->typeInfo=calloc(1,sizeof(NSValueTypeInfo));x->typeInfo->name=strdup(t);x->typeInfo->size=n;assert(n<=sizeof x->storage);memcpy(x->storage,b,n);return x;
}
static NSValue *_NSNewValue(void *b,const char *t){NSUInteger n=0;NSGetSizeAndAlignment(t,&n,NULL);return createValue(b,t,n,!strcmp(t,@encode(NSRange))?NSRangeType:NSNotSpecialType);}
DECODE_FUNCTION
@implementation NSValue
BASE_METHODS
VALUE_METHODS
@end
@implementation NSConcreteValue
CONCRETE_METHODS
@end
int main(void){
 int n=42;NSValue *x=_NSNewValue(&n,@encode(int));
 if(EQUALITY_ONLY) CHECK(![x isEqualToValue:nil]);CHECK([x isEqualToValue:x]);CHECK(![x isEqual:nil]);
 NSValue *same=_NSNewValue(&n,@encode(int));CHECK([x isEqualToValue:same]);n=-1;CHECK(![x isEqualToValue:_NSNewValue(&n,@encode(int))]);
 short sh=42;CHECK(![x isEqualToValue:_NSNewValue(&sh,@encode(short))]);CHECK([[x copyWithZone:NULL] isEqual:x]);
 if(EQUALITY_ONLY){printf("PASS concrete equality: %u checks\n",checks);return 0;}
 NSRange ranges[]={{0,0},{0,1},{7,13},{LONG_MAX,0},{LONG_MAX,1},{ULONG_MAX-1,1},{123456789,987654321}};
 for(unsigned i=0;i<7;i++)for(unsigned secure=0;secure<2;secure++){
  (void)secure;NSValue *original=_NSNewValue(&ranges[i],@encode(NSRange));NSCoder *c=[NSCoder alloc];c->keyed=YES;
  [original encodeWithCoder:c];NSValue *decoded=[[NSValue alloc]initWithCoder:c];CHECK(decoded!=nil);
  NSRange got=[decoded rangeValue];CHECK(got.location==ranges[i].location&&got.length==ranges[i].length);CHECK([original isEqualToValue:decoded]);CHECK([[decoded copyWithZone:NULL]isEqual:decoded]);
 }
 int values[]={0,-1,42,INT_MAX};
 for(unsigned i=0;i<4;i++){
  x=_NSNewValue(&values[i],@encode(int));NSCoder *c=[NSCoder alloc];c->keyed=YES;[x encodeWithCoder:c];
  NSValue *decoded=[[NSValue alloc]initWithCoder:c];CHECK(decoded!=nil);int got=0;[decoded getValue:&got size:sizeof got];CHECK(got==values[i]&&[x isEqualToValue:decoded]);
  for(NSUInteger size=0;size<=8;size++) {
   unsigned char buffer[16];memset(buffer,0xa5,sizeof buffer);BOOL threw=NO;
   @try{[decoded getValue:buffer size:size];}@catch(id e){threw=YES;}
   CHECK(threw==(size!=sizeof(int)));CHECK(buffer[sizeof(int)]==0xa5);
  }
 }
 for(unsigned i=0;i<4;i++){
  NSCoder *c=[NSCoder alloc];c->keyed=YES;[c encodePoint:(CGPoint){i,-(double)i} forKey:@"point"];[c encodeSize:(CGSize){i+1,i+2} forKey:@"size"];
  CGPoint p=[c decodePointForKey:@"point"];CGSize s=[c decodeSizeForKey:@"size"];CHECK(p.x==i&&p.y==-(double)i&&s.width==i+1&&s.height==i+2);
 }
 printf("PASS production value coding/equality: %u checks (typed in-memory coder; no wire parser)\n",checks);
}
