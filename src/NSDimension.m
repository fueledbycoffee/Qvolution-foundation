// Adapted from swift-corelibs-foundation, Sources/Foundation/{Unit,NSMeasurement}.swift.
// Copyright (c) 2014-2017 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception.

#import <Foundation/NSDimension.h>
#import <Foundation/NSUnitConverterLinear.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>

@implementation NSDimension
@synthesize converter = _converter;
- (instancetype)initWithSymbol:(NSString *)symbol {
    [self release];
    [NSException raise:NSInvalidArgumentException format:@"Dimensions require a converter"];
    return nil;
}
- (instancetype)initWithSymbol:(NSString *)symbol converter:(NSUnitConverter *)converter {
    if (!(self = [super initWithSymbol:symbol])) return nil;
    if (!converter) { [self release]; [NSException raise:NSInvalidArgumentException format:@"Dimensions require a converter"]; }
    _converter = [converter retain];
    return self;
}
- (void)dealloc { [_converter release]; [super dealloc]; }
+ (instancetype)baseUnit {
    [NSException raise:NSInvalidArgumentException format:@"Dimension subclasses must define their base unit"];
    return nil;
}
- (BOOL)isEqual:(id)object {
    return self == object || ([object isMemberOfClass:[self class]] && [super isEqual:object] && [_converter isEqual:[object converter]]);
}
- (NSUInteger)hash { return [super hash] ^ [_converter hash]; }
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:_converter forKey:@"NS.converter"];
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if (![coder allowsKeyedCoding]) {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"Dimensions require keyed coding"];
    }
    NSString *symbol = [coder decodeObjectOfClass:[NSString class] forKey:@"NS.symbol"];
    NSUnitConverter *converter = [coder decodeObjectOfClass:[NSUnitConverterLinear class] forKey:@"NS.converter"];
    if (!symbol || !converter) { [self release]; return nil; }
    return [self initWithSymbol:symbol converter:converter];
}
@end
