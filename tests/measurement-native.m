// Linux/libobjc dependency doubles. Production model classes are compiled verbatim.
#include <objc/runtime.h>
#include <objc/message.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
typedef unsigned long NSUInteger;
typedef void NSZone;
@class NSString, NSCoder;
@protocol NSCopying
- (id)copyWithZone:(NSZone *)zone;
@end
@protocol NSSecureCoding
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
@end
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
+ (Class)class;
- (Class)class;
- (id)init;
- (id)retain;
- (id)autorelease;
- (id)copy;
- (void)release;
- (void)dealloc;
- (BOOL)isKindOfClass:(Class)c;
- (BOOL)isMemberOfClass:(Class)c;
- (BOOL)isEqual:(id)other;
- (NSUInteger)hash;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self, 0); }
+ (Class)class { return self; }
- (Class)class { return object_getClass(self); }
- (id)init { return self; }
- (id)retain { return self; }
- (id)autorelease { return self; }
- (id)copy { return [self copyWithZone:NULL]; }
- (void)release {}
- (void)dealloc {}
- (BOOL)isKindOfClass:(Class)c { for(Class k=[self class];k;k=class_getSuperclass(k)) if(k==c)return YES;return NO; }
- (BOOL)isMemberOfClass:(Class)c { return [self class]==c; }
- (BOOL)isEqual:(id)other { return self==other; }
- (NSUInteger)hash { return 0; }
@end
@interface NSString : NSObject
- (const char *)UTF8String;
- (BOOL)isEqualToString:(NSString *)other;
@end
@interface FixtureString : NSString { const char *bytes; unsigned int length; }
@end
@implementation NSString
- (BOOL)isEqual:(id)other { return [other isKindOfClass:[NSString class]] && !strcmp([self UTF8String],[other UTF8String]); }
- (BOOL)isEqualToString:(NSString *)other { return [self isEqual:other]; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end
@implementation FixtureString
- (const char *)UTF8String { return bytes; }
@end
@interface NSNumber : NSObject { double value; }
+ (id)numberWithDouble:(double)v;
@end
@implementation NSNumber
+ (id)numberWithDouble:(double)v { NSNumber *n=[self alloc];n->value=v;return n; }
@end
static NSString *NSInvalidArgumentException=@"NSInvalidArgumentException";
@interface NSException : NSObject
+ (void)raise:(NSString *)name format:(NSString *)format,...;
@end
@implementation NSException
+ (void)raise:(NSString *)name format:(NSString *)format,... { @throw self; }
@end
@interface NSCoder : NSObject { NSString *keys[8]; id objects[8]; double numbers[8]; unsigned count; }
- (BOOL)allowsKeyedCoding;
- (void)encodeObject:(id)obj forKey:(NSString *)key;
- (void)encodeDouble:(double)v forKey:(NSString *)key;
- (id)decodeObjectOfClass:(Class)c forKey:(NSString *)key;
- (double)decodeDoubleForKey:(NSString *)key;
@end
@implementation NSCoder
- (BOOL)allowsKeyedCoding { return YES; }
- (void)encodeObject:(id)obj forKey:(NSString *)key { keys[count]=key;objects[count++]=obj; }
- (void)encodeDouble:(double)v forKey:(NSString *)key { keys[count]=key;numbers[count++]=v; }
- (id)decodeObjectOfClass:(Class)c forKey:(NSString *)key { for(unsigned i=0;i<count;i++)if([keys[i] isEqual:key])return [objects[i] isKindOfClass:c]?objects[i]:nil;return nil; }
- (double)decodeDoubleForKey:(NSString *)key { for(unsigned i=0;i<count;i++)if([keys[i] isEqual:key])return numbers[i];return 0; }
@end
@interface NSMethodSignature : NSObject
+ (id)signatureWithObjCTypes:(const char *)types;
@end
@implementation NSMethodSignature
+ (id)signatureWithObjCTypes:(const char *)types { return [self alloc]; }
@end
@interface NSInvocation : NSObject
- (SEL)selector;
@end
static id NSStringFromSelector(SEL s) { return nil; }
static void NSLog(id format,...) {}

PRODUCTION_HEADERS
PRODUCTION_SOURCE

static NSMeasurement *m(double v, NSUnit *unit) { return [[[NSMeasurement alloc] initWithDoubleValue:v unit:unit] autorelease]; }
static void closeEnough(double actual, double expected) { assert(actual==expected || fabs(actual-expected)<1e-14*fabs(expected)); }
int main(void) {
    assert(!strcmp([[NSUnitLength baseUnit].symbol UTF8String],"m"));
    assert(!strcmp([[[[NSUnit alloc] initWithSymbol:@"widget"] symbol] UTF8String],"widget"));
    double values[]={-1,0,1,1234.5};
    NSUnit *from[]={[NSUnitLength meters],[NSUnitLength miles],[NSUnitLength feet],[NSUnitLength centimeters]};
    NSUnit *to[]={[NSUnitLength kilometers],[NSUnitLength meters],[NSUnitLength inches],[NSUnitLength meters]};
    // Expected values are the supplied macOS 12.7.6 public-API observations.
    double converted[4][4]={{-.001,0,.001,1.2344999999999999},
        {-1609.3440000000001,0,1609.3440000000001,1986735.1680000001},
        {-12.000000000000002,0,12.000000000000002,14814},
        {-.01,0,.01,12.345000000000001}};
    double added[4][4]={{999,1000,1001,2234.5},
        {-1608.3440000000001,1,1610.3440000000001,1986736.1680000001},
        {-.27940000000000004,.025399999999999999,.33019999999999999,376.30099999999999},
        {.98999999999999999,1,1.01,13.345000000000001}};
    for(int u=0;u<4;u++)for(int i=0;i<4;i++) {
        NSMeasurement *a=m(values[i],from[u]), *b=m(1,to[u]);
        assert([[a measurementByConvertingToUnit:to[u]] doubleValue]==converted[u][i]);
        NSMeasurement *sum=[a measurementByAddingMeasurement:b];
        assert([sum.unit isEqual:[NSUnitLength meters]]);
        assert(sum.doubleValue==added[u][i]);
        assert(![a canBeConvertedToUnit:[NSUnitTemperature celsius]]);
    }
    assert([m(1,[NSUnitLength kilometers]) measurementBySubtractingMeasurement:m(1,[NSUnitLength meters])].doubleValue==999);
    assert([m(2,[NSUnitLength feet]) measurementByAddingMeasurement:m(3,[NSUnitLength feet])].doubleValue==5);
    double temperatures[]={-40,0,100};
    for(int i=0;i<3;i++) {
        closeEnough([m(temperatures[i],[NSUnitTemperature celsius]) measurementByConvertingToUnit:[NSUnitTemperature kelvin]].doubleValue,temperatures[i]+273.15);
        closeEnough([m(temperatures[i],[NSUnitTemperature fahrenheit]) measurementByConvertingToUnit:[NSUnitTemperature kelvin]].doubleValue,temperatures[i]*.55555555555556+255.37222222222427);
    }
    assert(isnan([m(NAN,[NSUnitLength meters]) measurementByConvertingToUnit:[NSUnitLength kilometers]].doubleValue));
    assert(isinf([m(INFINITY,[NSUnitLength meters]) measurementByConvertingToUnit:[NSUnitLength kilometers]].doubleValue));
    assert(!signbit([m(-0.,[NSUnitLength meters]) measurementByConvertingToUnit:[NSUnitLength kilometers]].doubleValue));
    BOOL raised=NO; @try { [m(1,[NSUnitLength meters]) measurementByConvertingToUnit:[NSUnitTemperature celsius]]; } @catch(id e) { raised=YES; } assert(raised);
    NSUnitConverterLinear *converter=[[NSUnitConverterLinear alloc] initWithCoefficient:2 constant:5];
    assert([converter baseUnitValueFromValue:3]==11 && [converter valueFromBaseUnitValue:11]==3);
    NSCoder *coder=[NSCoder alloc]; [converter encodeWithCoder:coder];
    assert([converter isEqual:[[NSUnitConverterLinear alloc] initWithCoder:coder]]);
    NSUnit *unit=[NSUnitLength centimeters];coder=[NSCoder alloc];[unit encodeWithCoder:coder];
    assert([unit isEqual:[[NSUnitLength alloc] initWithCoder:coder]]);
    NSMeasurement *a=m(7,unit);coder=[NSCoder alloc];[a encodeWithCoder:coder];
    assert([a isEqual:[[NSMeasurement alloc] initWithCoder:coder]]);
    assert([a copy]==a && [unit copy]==unit);
    puts("PASS: production unit/measurement conversions, arithmetic, errors, special values, copy and coding");
}
