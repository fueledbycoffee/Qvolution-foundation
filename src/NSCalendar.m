//
//  NSCalendar.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSCalendarInternal.h"
#import "NSObjectInternal.h"
#import <Foundation/NSNotification.h>
#include <limits.h>

@implementation NSCalendar (NSCalendar)

- (NSInteger)component:(NSCalendarUnit)unit fromDate:(NSDate *)date
{
    NSDateComponents *components = [self components:unit fromDate:date];
    switch (unit)
    {
        case NSCalendarUnitEra: return [components era];
        case NSCalendarUnitYear: return [components year];
        case NSCalendarUnitMonth: return [components month];
        case NSCalendarUnitDay: return [components day];
        case NSCalendarUnitHour: return [components hour];
        case NSCalendarUnitMinute: return [components minute];
        case NSCalendarUnitSecond: return [components second];
        case NSCalendarUnitWeekday: return [components weekday];
        case NSCalendarUnitWeekdayOrdinal: return [components weekdayOrdinal];
        case NSCalendarUnitQuarter: return [components quarter];
        case NSCalendarUnitWeekOfMonth: return [components weekOfMonth];
        case NSCalendarUnitWeekOfYear: return [components weekOfYear];
        case NSCalendarUnitYearForWeekOfYear: return [components yearForWeekOfYear];
        case NSCalendarUnitNanosecond: return [components nanosecond];
        default: return NSUndefinedDateComponent;
    }
}

- (NSDate *)startOfDayForDate:(NSDate *)date
{
    NSDate *start = nil;
    NSTimeInterval interval;
    if (![self rangeOfUnit:NSCalendarUnitDay startDate:&start interval:&interval forDate:date])
        return nil;
    return start;
}

- (NSDate *)dateByAddingUnit:(NSCalendarUnit)unit value:(NSInteger)value toDate:(NSDate *)date options:(NSUInteger)opts
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    [components setValue:value forComponent:unit];
    NSDate *result = [self dateByAddingComponents:components toDate:date options:opts];
    [components release];
    return result;
}

OBJC_PROTOCOL_IMPL_PUSH
+ (id)autoupdatingCurrentCalendar
{
    return [[[NSAutoCalendar alloc] init] autorelease];
}
OBJC_PROTOCOL_IMPL_POP

@end



@implementation NSAutoCalendar

- (id)init
{
    self = [super init];
    if (self)
    {
        cal = [[NSCalendar currentCalendar] retain];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(_update:) name:(NSString *)kCFLocaleCurrentLocaleDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(_update:) name:(NSString *)kCFTimeZoneSystemTimeZoneDidChangeNotification object:nil];
    }
    return self;
}

- (id)initWithCalendarIdentifier:(NSCalendarIdentifier)ident
{
    return [self init];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [cal release];
    [super dealloc];
}

- (NSCalendarIdentifier)calendarIdentifier
{
    return [cal calendarIdentifier];
}

- (void)setLocale:(NSLocale *)locale
{
    [cal setLocale:locale];
}

- (NSLocale *)locale
{
    return [cal locale];
}

- (void)setTimeZone:(NSTimeZone *)tz
{
    [cal setTimeZone:tz];
}

- (NSTimeZone *)timeZone
{
    return [cal timeZone];
}

- (void)setFirstWeekday:(NSUInteger)weekday
{
    [cal setFirstWeekday:weekday];
}

- (NSUInteger)firstWeekday
{
    return [cal firstWeekday];
}

- (void)setMinimumDaysInFirstWeek:(NSUInteger)mdw
{
    [cal setMinimumDaysInFirstWeek:mdw];
}

- (NSUInteger)minimumDaysInFirstWeek
{
    return [cal minimumDaysInFirstWeek];
}

- (NSRange)minimumRangeOfUnit:(NSCalendarUnit)unit
{
    return [cal minimumRangeOfUnit:unit];
}

- (NSRange)maximumRangeOfUnit:(NSCalendarUnit)unit
{
    return [cal maximumRangeOfUnit:unit];
}

- (NSRange)rangeOfUnit:(NSCalendarUnit)smaller inUnit:(NSCalendarUnit)larger forDate:(NSDate *)date
{
    return [cal rangeOfUnit:smaller inUnit:larger forDate:date];
}

- (NSUInteger)ordinalityOfUnit:(NSCalendarUnit)smaller inUnit:(NSCalendarUnit)larger forDate:(NSDate *)date
{
    return [cal ordinalityOfUnit:smaller inUnit:larger forDate:date];
}

- (BOOL)rangeOfUnit:(NSCalendarUnit)unit startDate:(NSDate **)datep interval:(NSTimeInterval *)tip forDate:(NSDate *)date
{
    return [cal rangeOfUnit:unit startDate:datep interval:tip forDate:date];
}

- (NSDate *)dateFromComponents:(NSDateComponents *)comps
{
    return [cal dateFromComponents:comps];
}

- (NSDateComponents *)components:(NSUInteger)unitFlags fromDate:(NSDate *)date
{
    return [cal components:unitFlags fromDate:date];
}

- (NSDate *)dateByAddingComponents:(NSDateComponents *)comps toDate:(NSDate *)date options:(NSUInteger)opts
{
    return [cal dateByAddingComponents:comps toDate:date options:opts];
}

- (NSDateComponents *)components:(NSUInteger)unitFlags fromDate:(NSDate *)startingDate toDate:(NSDate *)resultDate options:(NSUInteger)opts
{
    return [cal components:unitFlags fromDate:startingDate toDate:resultDate options:opts];
}

- (void)_update:(NSNotification *)notif
{
    [cal release];
    cal = [[NSCalendar currentCalendar] retain];
}

@end

@implementation NSDateComponents (NSCalendarComponents)

- (NSInteger)valueForComponent:(NSCalendarUnit)unit
{
    NSInteger value;
    switch (unit) {
        case NSCalendarUnitEra: value = [self era]; break;
        case NSCalendarUnitYear: value = [self year]; break;
        case NSCalendarUnitMonth: value = [self month]; break;
        case NSCalendarUnitDay: value = [self day]; break;
        case NSCalendarUnitHour: value = [self hour]; break;
        case NSCalendarUnitMinute: value = [self minute]; break;
        case NSCalendarUnitSecond: value = [self second]; break;
        case NSCalendarUnitWeekday: value = [self weekday]; break;
        case NSCalendarUnitWeekdayOrdinal: value = [self weekdayOrdinal]; break;
        case NSCalendarUnitQuarter: value = [self quarter]; break;
        case NSCalendarUnitWeekOfMonth: value = [self weekOfMonth]; break;
        case NSCalendarUnitWeekOfYear: value = [self weekOfYear]; break;
        case NSCalendarUnitYearForWeekOfYear: value = [self yearForWeekOfYear]; break;
        case NSCalendarUnitNanosecond: value = [self nanosecond]; break;
        default: return NSDateComponentUndefined;
    }
    return value;
}

- (void)setValue:(NSInteger)value forComponent:(NSCalendarUnit)unit
{
    switch (unit) {
        case NSCalendarUnitEra: [self setEra:value]; break;
        case NSCalendarUnitYear: [self setYear:value]; break;
        case NSCalendarUnitMonth: [self setMonth:value]; break;
        case NSCalendarUnitDay: [self setDay:value]; break;
        case NSCalendarUnitHour: [self setHour:value]; break;
        case NSCalendarUnitMinute: [self setMinute:value]; break;
        case NSCalendarUnitSecond: [self setSecond:value]; break;
        case NSCalendarUnitWeekday: [self setWeekday:value]; break;
        case NSCalendarUnitWeekdayOrdinal: [self setWeekdayOrdinal:value]; break;
        case NSCalendarUnitQuarter: [self setQuarter:value]; break;
        case NSCalendarUnitWeekOfMonth: [self setWeekOfMonth:value]; break;
        case NSCalendarUnitWeekOfYear: [self setWeekOfYear:value]; break;
        case NSCalendarUnitYearForWeekOfYear: [self setYearForWeekOfYear:value]; break;
        case NSCalendarUnitNanosecond: [self setNanosecond:value]; break;
        default: break;
    }
}

- (BOOL)isValidDate
{
    NSCalendar *calendar = [self calendar];
    return calendar ? [self isValidDateInCalendar:calendar] : NO;
}

- (BOOL)isValidDateInCalendar:(NSCalendar *)calendar
{
    if (!calendar) return NO;
    NSInteger nanosecond = [self valueForComponent:NSCalendarUnitNanosecond];
    if (nanosecond != NSDateComponentUndefined && (nanosecond < 0 || nanosecond >= 1000000000))
        return NO;

    NSCalendarUnit units[] = {
        NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay,
        NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond,
        NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitQuarter,
        NSCalendarUnitWeekOfMonth, NSCalendarUnitWeekOfYear, NSCalendarUnitYearForWeekOfYear
    };
    NSUInteger flags = 0;
    for (NSUInteger i = 0; i < sizeof(units) / sizeof(units[0]); i++) {
        NSInteger value = [self valueForComponent:units[i]];
        if (value == NSDateComponentUndefined) continue;
        // The CF calendar component vector contains ints; do not truncate input.
        if (value < INT_MIN || value >= INT_MAX) return NO;
        flags |= units[i];
    }
    NSCalendar *workingCalendar = [calendar copy];
    if ([self timeZone]) [workingCalendar setTimeZone:[self timeZone]];
    NSDateComponents *wholeSeconds = [[NSDateComponents alloc] init];
    for (NSUInteger i = 0; i < sizeof(units) / sizeof(units[0]); i++) {
        if (flags & units[i]) [wholeSeconds setValue:[self valueForComponent:units[i]] forComponent:units[i]];
    }
    [wholeSeconds setNanosecond:0];
    NSDate *date = [workingCalendar dateFromComponents:wholeSeconds];
    [wholeSeconds release];
    BOOL valid = date != nil;
    if (date) {
        NSDateComponents *actual = [workingCalendar components:flags fromDate:date];
        valid = actual != nil;
        for (NSUInteger i = 0; valid && i < sizeof(units) / sizeof(units[0]); i++) {
            if ((flags & units[i]) && [actual valueForComponent:units[i]] != [self valueForComponent:units[i]])
                valid = NO;
        }
    }
    [workingCalendar release];
    return valid;
}

@end
