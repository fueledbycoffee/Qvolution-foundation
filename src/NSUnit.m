// Adapted from swift-corelibs-foundation, Sources/Foundation/{Unit,NSMeasurement}.swift.
// Copyright (c) 2014-2017 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception.

#import <Foundation/NSUnit.h>
#import <Foundation/NSString.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>

@implementation NSUnit
@synthesize symbol = _symbol;
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithSymbol:(NSString *)symbol {
    if (!(self = [super init])) return nil;
    if (!symbol) {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"A unit requires a symbol"];
    }
    _symbol = [symbol copy];
    return self;
}
- (void)dealloc { [_symbol release]; [super dealloc]; }
- (id)copyWithZone:(NSZone *)zone { return [self retain]; }
- (BOOL)isEqual:(id)object {
    return self == object || ([object isKindOfClass:[NSUnit class]] && [_symbol isEqual:[object symbol]]);
}
- (NSUInteger)hash { return [_symbol hash]; }
- (void)encodeWithCoder:(NSCoder *)coder {
    if (![coder allowsKeyedCoding]) [NSException raise:NSInvalidArgumentException format:@"Units require keyed coding"];
    [coder encodeObject:_symbol forKey:@"NS.symbol"];
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if (![coder allowsKeyedCoding]) {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"Units require keyed coding"];
    }
    NSString *symbol = [coder decodeObjectOfClass:[NSString class] forKey:@"NS.symbol"];
    if (!symbol) { [self release]; return nil; }
    return [self initWithSymbol:symbol];
}
@end
