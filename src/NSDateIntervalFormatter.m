/* Implementation of class NSDateIntervalFormatter
   Copyright (C) 2019 Free Software Foundation, Inc.

   By: heron
   Date: Wed Oct  9 16:23:55 EDT 2019

   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

   Adapted for Darling: GNUstep's retain/release macros expanded to plain
   Objective-C message sends, which is this project's idiom.
*/

#import <Foundation/NSCalendar.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDateFormatter.h>
#import <Foundation/NSDateInterval.h>
#import <Foundation/NSDateIntervalFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#include <stdlib.h>
#include <string.h>
#include <unicode/udateintervalformat.h>
#include <unicode/uloc.h>

// Maps this class's style enum onto NSDateFormatter's. The two share their
// numeric values, but the mapping is written out so a future divergence in
// either enum is a compile error here rather than a silently wrong style.
static NSDateFormatterStyle NSDateFormatterStyleFromIntervalStyle(NSDateIntervalFormatterStyle style)
{
    switch (style)
    {
        case NSDateIntervalFormatterShortStyle:  return NSDateFormatterShortStyle;
        case NSDateIntervalFormatterMediumStyle: return NSDateFormatterMediumStyle;
        case NSDateIntervalFormatterLongStyle:   return NSDateFormatterLongStyle;
        case NSDateIntervalFormatterFullStyle:   return NSDateFormatterFullStyle;
        case NSDateIntervalFormatterNoStyle:     return NSDateFormatterNoStyle;
    }
    return NSDateFormatterNoStyle;
}

@implementation NSDateIntervalFormatter

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _dateStyle = NSDateIntervalFormatterShortStyle;
        _timeStyle = NSDateIntervalFormatterShortStyle;
    }
    return self;
}

- (void)_clearIntervalFormatter
{
    if (_intervalFormatter != NULL)
    {
        udtitvfmt_close(_intervalFormatter);
        _intervalFormatter = NULL;
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    NSDateIntervalFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy->_locale = [_locale copy];
    copy->_calendar = [_calendar copy];
    copy->_timeZone = [_timeZone copy];
    copy->_dateTemplate = [_dateTemplate copy];
    copy->_dateStyle = _dateStyle;
    copy->_timeStyle = _timeStyle;
    return copy;
}

- (void)dealloc
{
    [self _clearIntervalFormatter];
    [_locale release];
    [_calendar release];
    [_timeZone release];
    [_dateTemplate release];
    [super dealloc];
}

- (NSLocale *)locale
{
    return _locale ?: [NSLocale currentLocale];
}

- (void)setLocale:(NSLocale *)locale
{
    id old = _locale;
    _locale = [locale copy];
    [old release];
    [self _clearIntervalFormatter];
}

- (NSCalendar *)calendar
{
    return _calendar ?: (NSCalendar *)CFLocaleGetValue((CFLocaleRef)[self locale], kCFLocaleCalendar);
}

- (void)setCalendar:(NSCalendar *)calendar
{
    id old = _calendar;
    _calendar = [calendar copy];
    [old release];
    [self _clearIntervalFormatter];
}

- (NSTimeZone *)timeZone
{
    return _timeZone ?: [NSTimeZone defaultTimeZone];
}

- (void)setTimeZone:(NSTimeZone *)timeZone
{
    id old = _timeZone;
    _timeZone = [timeZone copy];
    [old release];
    [self _clearIntervalFormatter];
}

- (NSString *)dateTemplate
{
    return _dateTemplate ?: [self _datePattern];
}

- (void)setDateTemplate:(NSString *)dateTemplate
{
    id old = _dateTemplate;
    _dateTemplate = [(dateTemplate ?: @"") copy];
    [old release];
    [self _clearIntervalFormatter];
}

- (NSDateIntervalFormatterStyle)dateStyle
{
    return _dateStyle;
}

- (void)setDateStyle:(NSDateIntervalFormatterStyle)dateStyle
{
    _dateStyle = dateStyle;
    [_dateTemplate release];
    _dateTemplate = nil;
    [self _clearIntervalFormatter];
}

- (NSDateIntervalFormatterStyle)timeStyle
{
    return _timeStyle;
}

- (void)setTimeStyle:(NSDateIntervalFormatterStyle)timeStyle
{
    _timeStyle = timeStyle;
    [_dateTemplate release];
    _dateTemplate = nil;
    [self _clearIntervalFormatter];
}

- (NSString *)_datePattern
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[self locale]];
    [formatter setCalendar:[self calendar]];
    [formatter setDateStyle:NSDateFormatterStyleFromIntervalStyle(_dateStyle)];
    [formatter setTimeStyle:NSDateFormatterStyleFromIntervalStyle(_timeStyle)];
    NSString *pattern = [[[formatter dateFormat] retain] autorelease];
    [formatter release];
    return pattern;
}

- (BOOL)_createIntervalFormatterWithPattern:(NSString *)pattern
{
    NSString *zone = [[self timeZone] name];
    UChar *patternChars = malloc(sizeof(UChar) * ([pattern length] + 1));
    UChar *zoneChars = malloc(sizeof(UChar) * ([zone length] + 1));
    if (patternChars == NULL || zoneChars == NULL)
    {
        free(patternChars);
        free(zoneChars);
        return NO;
    }
    [pattern getCharacters:patternChars range:NSMakeRange(0, [pattern length])];
    [zone getCharacters:zoneChars range:NSMakeRange(0, [zone length])];
    char locale[ULOC_FULLNAME_CAPACITY];
    strlcpy(locale, [[[self locale] localeIdentifier] UTF8String], sizeof(locale));
    UErrorCode status = U_ZERO_ERROR;
    uloc_setKeywordValue("calendar", [[[self calendar] calendarIdentifier] UTF8String],
                         locale, sizeof(locale), &status);
    if (U_SUCCESS(status))
    {
        _intervalFormatter = udtitvfmt_open(locale, patternChars, (int32_t)[pattern length],
                                           zoneChars, (int32_t)[zone length], &status);
    }
    free(patternChars);
    free(zoneChars);
    if (U_FAILURE(status))
    {
        [self _clearIntervalFormatter];
        return NO;
    }
    return _intervalFormatter != NULL;
}

- (NSString *)stringFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate
{
    if (fromDate == nil || toDate == nil)
    {
        return nil;
    }
    @synchronized (self)
    {
        if (_intervalFormatter == NULL)
        {
            NSString *pattern = [self dateTemplate];
            if ([pattern length] == 0)
            {
                return @"";
            }
            if (![self _createIntervalFormatterWithPattern:pattern])
            {
                return nil;
            }
        }
        UDate start = [fromDate timeIntervalSince1970] * 1000;
        UDate end = [toDate timeIntervalSince1970] * 1000;
        UChar stack[128];
        UChar *buffer = stack;
        UErrorCode status = U_ZERO_ERROR;
        int32_t length = udtitvfmt_format(_intervalFormatter, start, end, stack, 128, NULL, &status);
        if (status == U_BUFFER_OVERFLOW_ERROR)
        {
            buffer = malloc(sizeof(UChar) * (length + 1));
            if (buffer == NULL)
            {
                return nil;
            }
            status = U_ZERO_ERROR;
            length = udtitvfmt_format(_intervalFormatter, start, end, buffer, length + 1, NULL, &status);
        }
        NSString *result = U_SUCCESS(status) ? [NSString stringWithCharacters:buffer length:length] : nil;
        if (buffer != stack)
        {
            free(buffer);
        }
        return result;
    }
}

- (NSString *)stringFromDateInterval:(NSDateInterval *)dateInterval
{
    if (dateInterval == nil)
    {
        return nil;
    }
    return [self stringFromDate:[dateInterval startDate] toDate:[dateInterval endDate]];
}

- (NSString *)stringForObjectValue:(id)obj
{
    if ([obj isKindOfClass:[NSDateInterval class]])
    {
        return [self stringFromDateInterval:obj];
    }
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self != nil)
    {
        if ([coder allowsKeyedCoding])
        {
            _locale = [[coder decodeObjectForKey:@"NS.locale"] retain];
            _calendar = [[coder decodeObjectForKey:@"NS.calendar"] retain];
            _timeZone = [[coder decodeObjectForKey:@"NS.timeZone"] retain];
            _dateTemplate = [[coder decodeObjectForKey:@"NS.dateTemplate"] retain];
            _dateStyle = [coder decodeIntegerForKey:@"NS.dateStyle"];
            _timeStyle = [coder decodeIntegerForKey:@"NS.timeStyle"];
        }
        else
        {
            [coder decodeValueOfObjCType:@encode(id) at:&_locale];
            [coder decodeValueOfObjCType:@encode(id) at:&_calendar];
            [coder decodeValueOfObjCType:@encode(id) at:&_timeZone];
            [coder decodeValueOfObjCType:@encode(id) at:&_dateTemplate];
            [coder decodeValueOfObjCType:@encode(NSUInteger) at:&_dateStyle];
            [coder decodeValueOfObjCType:@encode(NSUInteger) at:&_timeStyle];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    if ([coder allowsKeyedCoding])
    {
        [coder encodeObject:_locale forKey:@"NS.locale"];
        [coder encodeObject:_calendar forKey:@"NS.calendar"];
        [coder encodeObject:_timeZone forKey:@"NS.timeZone"];
        [coder encodeObject:_dateTemplate forKey:@"NS.dateTemplate"];
        [coder encodeInteger:_dateStyle forKey:@"NS.dateStyle"];
        [coder encodeInteger:_timeStyle forKey:@"NS.timeStyle"];
    }
    else
    {
        [coder encodeValueOfObjCType:@encode(id) at:&_locale];
        [coder encodeValueOfObjCType:@encode(id) at:&_calendar];
        [coder encodeValueOfObjCType:@encode(id) at:&_timeZone];
        [coder encodeValueOfObjCType:@encode(id) at:&_dateTemplate];
        [coder encodeValueOfObjCType:@encode(NSUInteger) at:&_dateStyle];
        [coder encodeValueOfObjCType:@encode(NSUInteger) at:&_timeStyle];
    }
}

@end
