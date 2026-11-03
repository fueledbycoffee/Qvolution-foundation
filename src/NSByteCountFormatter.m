//
//  NSByteCountFormatter.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSByteCountFormatter.h>
#import <Foundation/NSNumberFormatter.h>
#import "NSObjectInternal.h"
#import <Foundation/NSLocale.h>

@implementation NSByteCountFormatter

static NSArray *_NSByteCountFormatterUnits;

+ (void)initialize
{
    if ([self class] == [NSByteCountFormatter class])
    {
        _NSByteCountFormatterUnits = [[NSArray alloc] initWithObjects:@"bytes", @"KB", @"MB", @"GB", @"TB", @"PB", @"EB", @"ZB", @"YB", nil];
    }
}

+ (NSString *)stringFromByteCount:(long long)byteCount countStyle:(NSByteCountFormatterCountStyle)style
{
    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter->_countStyle = style;

    NSString *string = [formatter stringFromByteCount:byteCount];

    [formatter release];

    return string;
}

- (NSByteCountFormatter *)init
{
    self = [super init];

    if (self)
    {
        _adaptive = YES;
        _allowsNonnumericFormatting = YES;
        _includesUnit = YES;
        _includesCount = YES;
    }

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSByteCountFormatter *copy = [[NSByteCountFormatter allocWithZone:zone] init];

    copy->_allowedUnits = _allowedUnits;
    copy->_countStyle = _countStyle;
    copy->_allowsNonnumericFormatting = _allowsNonnumericFormatting;
    copy->_includesUnit = _includesUnit;
    copy->_includesCount = _includesCount;
    copy->_includesActualByteCount = _includesActualByteCount;
    copy->_adaptive = _adaptive;
    copy->_zeroPadsFractionDigits = _zeroPadsFractionDigits;
    copy->_formattingContext = _formattingContext;

    return copy;
}

- (id)initWithCoder:(NSCoder *)coder
{
#warning TODO coder
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
#warning TODO coder
    return;
}

// This property must be defined by hand as the type of the ivar does
// not match the declared type in the getter and setter.
- (NSByteCountFormatterCountStyle)countStyle
{
    return _countStyle;
}

- (void)setCountStyle:(NSByteCountFormatterCountStyle)countStyle
{
    _countStyle = countStyle;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
              originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error
{
    return NO;
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error
{
    return NO;
}

#warning TODO localization
- (NSString *)stringFromByteCount:(long long)byteCount
{
    if (byteCount == 0 && _allowsNonnumericFormatting && _includesUnit && _includesCount)
    {
        NSString *zero = _formattingContext == NSFormattingContextMiddleOfSentence ? @"zero" : @"Zero";
        if (_allowedUnits == NSByteCountFormatterUseAll ||
            _allowedUnits == NSByteCountFormatterUseDefault ||
            (_allowedUnits & NSByteCountFormatterUseKB && !(_allowedUnits & NSByteCountFormatterUseBytes)))
        {
            return [zero stringByAppendingString:@" KB"];
        }
        return [zero stringByAppendingString:@" bytes"];
    }

    if (!_includesCount && !_includesUnit)
    {
        return @"";
    }

    unsigned long long magnitude = byteCount < 0 ? 0ULL - (unsigned long long)byteCount : (unsigned long long)byteCount;
    NSUInteger base = (_countStyle == NSByteCountFormatterCountStyleBinary ||
                       _countStyle == NSByteCountFormatterCountStyleMemory) ? 1024 : 1000;
    NSByteCountFormatterUnits units = _allowedUnits;
    if (units == NSByteCountFormatterUseDefault)
    {
        units = NSByteCountFormatterUseAll;
    }

    NSUInteger unitIdx = NSNotFound;
    double divisor = 1;
    double selectedDivisor = 1;
    for (NSUInteger i = 0; i < [_NSByteCountFormatterUnits count]; i++, divisor *= base)
    {
        if ((units & (1UL << i)) && (unitIdx == NSNotFound || magnitude >= divisor))
        {
            unitIdx = i;
            selectedDivisor = divisor;
        }
    }
    if (unitIdx == NSNotFound)
    {
        return @"";
    }

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setLocale:[NSLocale currentLocale]];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setUsesGroupingSeparator:YES];
    NSUInteger fractionDigits = unitIdx <= 1 ? 0 : (unitIdx == 2 ? 1 : 2);
    if (unitIdx == 0 || _adaptive)
    {
        [formatter setMaximumFractionDigits:unitIdx == 0 ? 0 : fractionDigits];
        [formatter setMinimumFractionDigits:_zeroPadsFractionDigits && unitIdx != 0 ? fractionDigits : 0];
    }
    else
    {
        [formatter setUsesSignificantDigits:YES];
        [formatter setMaximumSignificantDigits:3];
        [formatter setMinimumSignificantDigits:_zeroPadsFractionDigits ? 3 : 1];
    }

    NSNumber *count = unitIdx == 0 ? @(byteCount) : @((double)byteCount / selectedDivisor);
    NSString *countString = _includesCount ? [formatter stringFromNumber:count] : @"";
    NSString *unitString = @"";
    if (_includesUnit)
    {
        unitString = unitIdx == 0 && magnitude == 1 ? @"byte" : [_NSByteCountFormatterUnits objectAtIndex:unitIdx];
    }
    NSString *actualCountString = @"";
    if (_includesActualByteCount && _includesCount && _includesUnit && unitIdx != 0)
    {
        [formatter setUsesSignificantDigits:NO];
        [formatter setMinimumFractionDigits:0];
        [formatter setMaximumFractionDigits:0];
        actualCountString = [NSString stringWithFormat:@" (%@ bytes)", [formatter stringFromNumber:@(byteCount)]];
    }
    NSString *result = [NSString stringWithFormat:@"%@%@%@%@", countString,
                        _includesCount && _includesUnit ? @" " : @"", unitString, actualCountString];
    [formatter release];
    return result;
}

- (NSString *)stringForObjectValue:(id)obj
{
    if ([obj isNSNumber__])
    {
        long long byteCount = [obj longLongValue];
        return [self stringFromByteCount:byteCount];
    }
    else
    {
        return nil;
    }
}

@end
