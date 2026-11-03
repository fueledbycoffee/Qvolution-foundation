// Adapted from swift-corelibs-foundation, Sources/Foundation/{Unit,NSMeasurement}.swift.
// Copyright (c) 2014-2017 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception.

#import <Foundation/NSUnitConverterLinear.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>
#import <Foundation/NSValue.h>

@implementation NSUnitConverterLinear
@synthesize coefficient = _coefficient, constant = _constant;
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoefficient:(double)coefficient { return [self initWithCoefficient:coefficient constant:0]; }
- (instancetype)initWithCoefficient:(double)coefficient constant:(double)constant {
    if ((self = [super init])) { _coefficient = coefficient; _constant = constant; }
    return self;
}
- (double)baseUnitValueFromValue:(double)value { return value * _coefficient + _constant; }
- (double)valueFromBaseUnitValue:(double)value { return (value - _constant) / _coefficient; }
- (BOOL)isEqual:(id)object {
    return self == object || ([object isKindOfClass:[NSUnitConverterLinear class]] &&
        _coefficient == [object coefficient] && _constant == [object constant]);
}
- (NSUInteger)hash { return [[NSNumber numberWithDouble:_coefficient] hash] ^ [[NSNumber numberWithDouble:_constant] hash]; }
- (void)encodeWithCoder:(NSCoder *)coder {
    if (![coder allowsKeyedCoding]) [NSException raise:NSInvalidArgumentException format:@"Converters require keyed coding"];
    [coder encodeDouble:_coefficient forKey:@"NS.coefficient"];
    [coder encodeDouble:_constant forKey:@"NS.constant"];
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if (![coder allowsKeyedCoding]) {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"Converters require keyed coding"];
    }
    return [self initWithCoefficient:[coder decodeDoubleForKey:@"NS.coefficient"] constant:[coder decodeDoubleForKey:@"NS.constant"]];
}
@end
