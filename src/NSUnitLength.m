// Adapted from swift-corelibs-foundation, Sources/Foundation/{Unit,NSMeasurement}.swift.
// Copyright (c) 2014-2017 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception.

#import <Foundation/NSUnitLength.h>
#import <Foundation/NSUnitConverterLinear.h>

@implementation NSUnitLength
+ (instancetype)megameters {
    return [[[self alloc] initWithSymbol:@"Mm" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1e6 constant:0] autorelease]] autorelease];
}
+ (instancetype)kilometers {
    return [[[self alloc] initWithSymbol:@"km" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1e3 constant:0] autorelease]] autorelease];
}
+ (instancetype)hectometers {
    return [[[self alloc] initWithSymbol:@"hm" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1e2 constant:0] autorelease]] autorelease];
}
+ (instancetype)decameters {
    return [[[self alloc] initWithSymbol:@"dam" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1e1 constant:0] autorelease]] autorelease];
}
+ (instancetype)meters {
    return [[[self alloc] initWithSymbol:@"m" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1 constant:0] autorelease]] autorelease];
}
+ (instancetype)decimeters {
    return [[[self alloc] initWithSymbol:@"dm" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1e-1 constant:0] autorelease]] autorelease];
}
+ (instancetype)centimeters {
    return [[[self alloc] initWithSymbol:@"cm" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1e-2 constant:0] autorelease]] autorelease];
}
+ (instancetype)millimeters {
    return [[[self alloc] initWithSymbol:@"mm" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1e-3 constant:0] autorelease]] autorelease];
}
+ (instancetype)micrometers {
    return [[[self alloc] initWithSymbol:@"µm" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1e-6 constant:0] autorelease]] autorelease];
}
+ (instancetype)nanometers {
    return [[[self alloc] initWithSymbol:@"nm" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1e-9 constant:0] autorelease]] autorelease];
}
+ (instancetype)picometers {
    return [[[self alloc] initWithSymbol:@"pm" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1e-12 constant:0] autorelease]] autorelease];
}
+ (instancetype)inches {
    return [[[self alloc] initWithSymbol:@"in" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:0.0254 constant:0] autorelease]] autorelease];
}
+ (instancetype)feet {
    return [[[self alloc] initWithSymbol:@"ft" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:0.3048 constant:0] autorelease]] autorelease];
}
+ (instancetype)yards {
    return [[[self alloc] initWithSymbol:@"yd" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:0.9144 constant:0] autorelease]] autorelease];
}
+ (instancetype)miles {
    return [[[self alloc] initWithSymbol:@"mi" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1609.344 constant:0] autorelease]] autorelease];
}
+ (instancetype)scandinavianMiles {
    return [[[self alloc] initWithSymbol:@"smi" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:10000 constant:0] autorelease]] autorelease];
}
+ (instancetype)lightyears {
    return [[[self alloc] initWithSymbol:@"ly" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:9460730472580800.0 constant:0] autorelease]] autorelease];
}
+ (instancetype)nauticalMiles {
    return [[[self alloc] initWithSymbol:@"NM" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1852 constant:0] autorelease]] autorelease];
}
+ (instancetype)fathoms {
    return [[[self alloc] initWithSymbol:@"ftm" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1.8288 constant:0] autorelease]] autorelease];
}
+ (instancetype)furlongs {
    return [[[self alloc] initWithSymbol:@"fur" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:201.168 constant:0] autorelease]] autorelease];
}
+ (instancetype)astronomicalUnits {
    return [[[self alloc] initWithSymbol:@"ua" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:149597870700.0 constant:0] autorelease]] autorelease];
}
+ (instancetype)parsecs {
    return [[[self alloc] initWithSymbol:@"pc" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:30856775814913672.0 constant:0] autorelease]] autorelease];
}
+ (instancetype)baseUnit { return [self meters]; }
@end
