#import <Foundation/NSDate.h>

@class NSTimeZone, NSString, NSCalendar, NSLocale;

@interface NSDate (NSCalendarDate)

- (NSString *) descriptionWithCalendarFormat:(NSString *)format timeZone:(NSTimeZone *)aTimeZone locale:(id)locale;

@end

@interface NSCalendarDate (NSCalendarDateMethods)

+ (id) calendarDate;
+ (id) dateWithYear:(NSInteger)year month:(NSUInteger)month day:(NSUInteger)day hour:(NSUInteger)hour minute:(NSUInteger)minute second:(NSUInteger)second timeZone:(NSTimeZone *)aTimeZone;

- (id) initWithYear:(NSInteger)year month:(NSUInteger)month day:(NSUInteger)day hour:(NSUInteger)hour minute:(NSUInteger)minute second:(NSUInteger)second timeZone:(NSTimeZone *)aTimeZone;
- (id) initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)ti;

- (NSInteger) dayOfCommonEra;
- (NSInteger) dayOfMonth;
- (NSInteger) dayOfWeek;
- (NSInteger) dayOfYear;
- (NSInteger) hourOfDay;
- (NSInteger) minuteOfHour;
- (NSInteger) monthOfYear;
- (NSInteger) secondOfMinute;
- (NSInteger) yearOfCommonEra;

- (NSString *) descriptionWithCalendarFormat:(NSString *)format locale:(id)locale;
- (NSString *) descriptionWithCalendarFormat:(NSString *)format;

- (NSTimeZone *) timeZone;
- (void) setTimeZone:(NSTimeZone *)aTimeZone;
- (NSString *) calendarFormat;
- (void) setCalendarFormat:(NSString *)format;

@end

