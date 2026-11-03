// Adapted from swift-corelibs-foundation, Sources/Foundation/{Unit,NSMeasurement}.swift.
// Copyright (c) 2014-2017 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception.

#import <Foundation/NSUnitTemperature.h>
#import <Foundation/NSUnitConverterLinear.h>

@implementation NSUnitTemperature
+ (instancetype)kelvin {
    return [[[self alloc] initWithSymbol:@"K" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1 constant:0] autorelease]] autorelease];
}
+ (instancetype)celsius {
    return [[[self alloc] initWithSymbol:@"°C" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1 constant:273.15] autorelease]] autorelease];
}
+ (instancetype)fahrenheit {
    return [[[self alloc] initWithSymbol:@"°F" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:0.55555555555556 constant:255.37222222222427] autorelease]] autorelease];
}
+ (instancetype)baseUnit { return [self kelvin]; }
@end
