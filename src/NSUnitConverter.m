// Adapted from swift-corelibs-foundation, Sources/Foundation/{Unit,NSMeasurement}.swift.
// Copyright (c) 2014-2017 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception.

#import <Foundation/NSUnitConverter.h>
@implementation NSUnitConverter
- (double)baseUnitValueFromValue:(double)value { return value; }
- (double)valueFromBaseUnitValue:(double)value { return value; }
@end
