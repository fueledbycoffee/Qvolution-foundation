// Adapted from swift-corelibs-foundation, Sources/Foundation/{Unit,NSMeasurement}.swift.
// Copyright (c) 2014-2017 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception.

#import <Foundation/NSMeasurement.h>
#import <Foundation/NSDimension.h>
#import <Foundation/NSUnitConverter.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>
#import <Foundation/NSValue.h>

@implementation NSMeasurement
@synthesize unit = _unit, doubleValue = _doubleValue;
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithDoubleValue:(double)value unit:(NSUnit *)unit {
    if (!(self = [super init])) return nil;
    if (!unit) { [self release]; [NSException raise:NSInvalidArgumentException format:@"Measurements require a unit"]; }
    _unit = [unit copy];
    _doubleValue = value;
    return self;
}
- (void)dealloc { [_unit release]; [super dealloc]; }
- (id)copyWithZone:(NSZone *)zone { return [self retain]; }
- (BOOL)canBeConvertedToUnit:(NSUnit *)unit {
    return [_unit isKindOfClass:[NSDimension class]] && [unit isKindOfClass:[_unit class]];
}
- (NSMeasurement *)measurementByConvertingToUnit:(NSUnit *)unit {
    if (![self canBeConvertedToUnit:unit]) [NSException raise:NSInvalidArgumentException format:@"Incompatible measurement units"];
    double value = _doubleValue;
    if (![_unit isEqual:unit]) {
        value = [[(NSDimension *)_unit converter] baseUnitValueFromValue:value];
        value = [[(NSDimension *)unit converter] valueFromBaseUnitValue:value];
    }
    return [[[NSMeasurement alloc] initWithDoubleValue:value unit:unit] autorelease];
}
- (NSMeasurement *)_combine:(NSMeasurement *)other subtract:(BOOL)subtract {
    NSUnit *unit = _unit;
    double left = _doubleValue, right = [other doubleValue];
    if (![_unit isEqual:[other unit]]) {
        if (![self canBeConvertedToUnit:[other unit]]) [NSException raise:NSInvalidArgumentException format:@"Incompatible measurement units"];
        left = [[(NSDimension *)_unit converter] baseUnitValueFromValue:left];
        right = [[(NSDimension *)[other unit] converter] baseUnitValueFromValue:right];
        unit = [[_unit class] baseUnit];
    }
    return [[[NSMeasurement alloc] initWithDoubleValue:subtract ? left - right : left + right unit:unit] autorelease];
}
- (NSMeasurement *)measurementByAddingMeasurement:(NSMeasurement *)other { return [self _combine:other subtract:NO]; }
- (NSMeasurement *)measurementBySubtractingMeasurement:(NSMeasurement *)other { return [self _combine:other subtract:YES]; }
- (BOOL)isEqual:(id)object {
    return self == object || ([object isKindOfClass:[NSMeasurement class]] && _doubleValue == [object doubleValue] && [_unit isEqual:[object unit]]);
}
- (NSUInteger)hash { return [[NSNumber numberWithDouble:_doubleValue] hash] ^ [_unit hash]; }
- (void)encodeWithCoder:(NSCoder *)coder {
    if (![coder allowsKeyedCoding]) [NSException raise:NSInvalidArgumentException format:@"Measurements require keyed coding"];
    [coder encodeDouble:_doubleValue forKey:@"NS.value"];
    [coder encodeObject:_unit forKey:@"NS.unit"];
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if (![coder allowsKeyedCoding]) {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"Measurements require keyed coding"];
    }
    NSUnit *unit = [coder decodeObjectOfClass:[NSUnit class] forKey:@"NS.unit"];
    if (!unit) { [self release]; return nil; }
    return [self initWithDoubleValue:[coder decodeDoubleForKey:@"NS.value"] unit:unit];
}
@end
