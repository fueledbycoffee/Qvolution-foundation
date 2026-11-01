//
//  NSDate.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSDate.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSDateFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSCalendarDate.h>

#import "NSExternals.h"
#import "NSObjectInternal.h"

#import <Foundation/NSCoder.h>
#import <Foundation/NSPortCoder.h>

@implementation NSDate (NSDate)

- (Class)classForCoder
{
    return [NSDate self];
}

OBJC_PROTOCOL_IMPL_PUSH
- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSTimeInterval timeInterval = 0.0;
    if ([aDecoder allowsKeyedCoding])
    {
        timeInterval = [aDecoder decodeDoubleForKey:NS_time];
    }
    else
    {
        [aDecoder decodeValueOfObjCType:@encode(NSTimeInterval) at:&timeInterval];
    }
    return [self initWithTimeIntervalSinceReferenceDate:timeInterval];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    NSTimeInterval timeInterval = [self timeIntervalSinceReferenceDate];
    if ([aCoder allowsKeyedCoding])
    {
        [aCoder encodeDouble:timeInterval forKey:NS_time];
    }
    else
    {
        [aCoder encodeValueOfObjCType:@encode(NSTimeInterval) at:&timeInterval];
    }
}
OBJC_PROTOCOL_IMPL_POP

@end


@implementation NSDate (NSDatePortCoding)

- (id) replacementObjectForPortCoder: (NSPortCoder *) portCoder {
    return self;
}

@end

@implementation NSCalendarDate

+ (id) calendarDate {
    return [[[self alloc] init] autorelease];
}

+ (id) date {
    return [self calendarDate];
}

+ (id) dateWithTimeIntervalSinceReferenceDate: (NSTimeInterval) ti {
    return [[[self alloc] initWithTimeIntervalSinceReferenceDate: ti] autorelease];
}

+ (id) dateWithYear:(NSInteger)year month:(NSUInteger)month day:(NSUInteger)day hour:(NSUInteger)hour minute:(NSUInteger)minute second:(NSUInteger)second timeZone:(NSTimeZone *)aTimeZone {
    return [[[self alloc] initWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:aTimeZone] autorelease];
}

- (id) init {
    return [self initWithTimeIntervalSinceReferenceDate: CFAbsoluteTimeGetCurrent()];
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval) ti {
    _ti = ti;
    _timeZone = [[NSTimeZone defaultTimeZone] retain];
    _format = [@"%Y-%m-%d %H:%M:%S %z" copy];
    return self;
}

- (id) initWithYear:(NSInteger)year month:(NSUInteger)month day:(NSUInteger)day hour:(NSUInteger)hour minute:(NSUInteger)minute second:(NSUInteger)second timeZone:(NSTimeZone *)aTimeZone {
    NSDateComponents *comp = [[NSDateComponents alloc] init];
    [comp setYear: year];
    [comp setMonth: month];
    [comp setDay: day];
    [comp setHour: hour];
    [comp setMinute: minute];
    [comp setSecond: second];
    NSCalendar *cal = [[NSCalendar currentCalendar] copy];
    if (aTimeZone) [cal setTimeZone: aTimeZone];
    NSDate *d = [cal dateFromComponents: comp];
    [cal release];
    [comp release];
    self = [self initWithTimeIntervalSinceReferenceDate: [d timeIntervalSinceReferenceDate]];
    if (self && aTimeZone) {
        [self setTimeZone: aTimeZone];
    }
    return self;
}

- (void) dealloc {
    [_timeZone release];
    [_format release];
    [super dealloc];
}

- (NSTimeInterval) timeIntervalSinceReferenceDate {
    return _ti;
}

- (NSTimeZone *) timeZone {
    return _timeZone ?: [NSTimeZone defaultTimeZone];
}

- (void) setTimeZone: (NSTimeZone *) tz {
    if (_timeZone != tz) {
        [_timeZone release];
        _timeZone = [tz retain];
    }
}

- (NSString *) calendarFormat {
    return _format;
}

- (void) setCalendarFormat: (NSString *) format {
    if (_format != format) {
        [_format release];
        _format = [format copy];
    }
}

- (NSDateComponents *) _components {
    NSCalendar *cal = [[NSCalendar currentCalendar] copy];
    if (_timeZone) [cal setTimeZone: _timeZone];
    NSDateComponents *comp = [cal components: (NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit |
                             NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit |
                             NSWeekdayCalendarUnit)
                  fromDate: self];
    [cal release];
    return comp;
}

- (NSInteger) yearOfCommonEra {
    return [[self _components] year];
}

- (NSInteger) monthOfYear {
    return [[self _components] month];
}

- (NSInteger) dayOfMonth {
    return [[self _components] day];
}

- (NSInteger) dayOfWeek {
    return [[self _components] weekday] - 1;
}

- (NSInteger) dayOfYear {
    NSCalendar *cal = [[NSCalendar currentCalendar] copy];
    if (_timeZone) [cal setTimeZone: _timeZone];
    NSInteger res = [cal ordinalityOfUnit: NSDayCalendarUnit inUnit: NSYearCalendarUnit forDate: self];
    [cal release];
    return res;
}

- (NSInteger) hourOfDay {
    return [[self _components] hour];
}

- (NSInteger) minuteOfHour {
    return [[self _components] minute];
}

- (NSInteger) secondOfMinute {
    return [[self _components] second];
}

- (NSInteger) dayOfCommonEra {
    NSTimeZone *tz = _timeZone ?: [NSTimeZone defaultTimeZone];
    NSInteger offset = [tz secondsFromGMTForDate: self];
    return (NSInteger)floor((_ti + offset) / 86400.0) + 730486;
}

- (NSString *) descriptionWithCalendarFormat: (NSString *) format locale: (id) locale {
    return [self descriptionWithCalendarFormat: format ?: _format timeZone: [self timeZone] locale: locale];
}

- (NSString *) descriptionWithCalendarFormat: (NSString *) format {
    return [self descriptionWithCalendarFormat: format locale: nil];
}

- (NSString *) description {
    return [self descriptionWithCalendarFormat: _format locale: nil];
}

@end

@implementation NSDate (NSCalendarDate)

// Rung 4: Chess sends this selector to __NSDate. GUESS (rung 6): extend
// our existing NSCalendarDate formatter to NSDate, using the supplied zone
// or the default zone and retaining the existing nil-format literal.
- (NSString *) descriptionWithCalendarFormat: (NSString *) format timeZone: (NSTimeZone *) aTimeZone locale: (id) locale {
    if (format == nil) format = @"%Y-%m-%d %H:%M:%S %z";
    NSTimeZone *tz = aTimeZone ?: [NSTimeZone defaultTimeZone];
    if ([format rangeOfString: @"%"].location != NSNotFound) {
        NSInteger offset = [tz secondsFromGMTForDate: self];
        time_t t = (time_t)([self timeIntervalSince1970] + offset);
        struct tm tmVal;
        gmtime_r(&t, &tmVal);

        int sign = (offset >= 0) ? '+' : '-';
        long abs_off = labs((long)offset);
        long off_hours = abs_off / 3600;
        long off_mins = (abs_off % 3600) / 60;
        char z_buf[8];
        snprintf(z_buf, sizeof(z_buf), "%c%02ld%02ld", sign, off_hours, off_mins);

        NSString *fmt = format;
        if ([fmt rangeOfString: @"%z"].location != NSNotFound) {
            fmt = [fmt stringByReplacingOccurrencesOfString: @"%z" withString: [NSString stringWithUTF8String: z_buf]];
        }
        if ([fmt rangeOfString: @"%Z"].location != NSNotFound) {
            NSString *abbr = [tz abbreviationForDate: self] ?: @"UTC";
            fmt = [fmt stringByReplacingOccurrencesOfString: @"%Z" withString: abbr];
        }

        char buf[256];
        buf[0] = '\0';
        strftime(buf, sizeof(buf), [fmt UTF8String], &tmVal);
        return [NSString stringWithUTF8String: buf];
    }
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat: format];
    [df setTimeZone: tz];
    if (locale) [df setLocale: locale];
    NSString *res = [df stringFromDate: self];
    [df release];
    return res ?: @"";
}

@end
