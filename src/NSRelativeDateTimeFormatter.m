// Written for Darling using ICU's documented relative-date interface.
// GUESS: largest-component selection and rounding pending black-box validation.
#import <Foundation/NSRelativeDateTimeFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSString.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>
#include <unicode/ureldatefmt.h>
#include <unicode/unum.h>
#include <math.h>
#include <stdlib.h>

@implementation NSRelativeDateTimeFormatter
@synthesize locale = _locale, calendar = _calendar, dateTimeStyle = _dateTimeStyle;
@synthesize unitsStyle = _unitsStyle, formattingContext = _formattingContext;

- (instancetype)init
{
    if ((self = [super init])) {
        _locale = [[NSLocale currentLocale] copy];
        _calendar = [[NSCalendar currentCalendar] copy];
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        if ([coder containsValueForKey:@"locale"]) self.locale = [coder decodeObjectForKey:@"locale"];
        if ([coder containsValueForKey:@"calendar"]) self.calendar = [coder decodeObjectForKey:@"calendar"];
        _dateTimeStyle = [coder decodeIntegerForKey:@"dateTimeStyle"];
        _unitsStyle = [coder decodeIntegerForKey:@"unitsStyle"];
        _formattingContext = [coder decodeIntegerForKey:@"formattingContext"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_locale forKey:@"locale"];
    [coder encodeObject:_calendar forKey:@"calendar"];
    [coder encodeInteger:_dateTimeStyle forKey:@"dateTimeStyle"];
    [coder encodeInteger:_unitsStyle forKey:@"unitsStyle"];
    [coder encodeInteger:_formattingContext forKey:@"formattingContext"];
}
- (void)dealloc { [_locale release]; [_calendar release]; [super dealloc]; }
- (id)copyWithZone:(NSZone *)zone
{
    NSRelativeDateTimeFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy.locale = _locale; copy.calendar = _calendar;
    copy.dateTimeStyle = _dateTimeStyle; copy.unitsStyle = _unitsStyle;
    copy.formattingContext = _formattingContext;
    return copy;
}
- (NSString *)_formatValue:(double)value unit:(URelativeDateTimeUnit)unit
{
    UErrorCode status = U_ZERO_ERROR;
    const char *locale = [[_locale localeIdentifier] UTF8String];
    UNumberFormat *number = NULL;
    if (_unitsStyle == NSRelativeDateTimeFormatterUnitsStyleSpellOut) {
        number = unum_open(UNUM_SPELLOUT, NULL, 0, locale, NULL, &status);
        if (U_FAILURE(status)) return nil;
    }
    UDateRelativeDateTimeFormatterStyle style = UDAT_STYLE_LONG;
    if (_unitsStyle == NSRelativeDateTimeFormatterUnitsStyleShort) style = UDAT_STYLE_SHORT;
    if (_unitsStyle == NSRelativeDateTimeFormatterUnitsStyleAbbreviated) style = UDAT_STYLE_NARROW;
    UDisplayContext context = UDISPCTX_CAPITALIZATION_NONE;
    if (_formattingContext == NSFormattingContextBeginningOfSentence) context = UDISPCTX_CAPITALIZATION_FOR_BEGINNING_OF_SENTENCE;
    if (_formattingContext == NSFormattingContextStandalone) context = UDISPCTX_CAPITALIZATION_FOR_STANDALONE;
    if (_formattingContext == NSFormattingContextListItem) context = UDISPCTX_CAPITALIZATION_FOR_UI_LIST_OR_MENU;
    URelativeDateTimeFormatter *formatter = ureldatefmt_open(locale, number, style, context, &status);
    if (U_FAILURE(status)) return nil;
    UChar buffer[256];
    int32_t length = _dateTimeStyle == NSRelativeDateTimeFormatterStyleNamed
        ? ureldatefmt_format(formatter, value, unit, buffer, 256, &status)
        : ureldatefmt_formatNumeric(formatter, value, unit, buffer, 256, &status);
    UChar *result = buffer;
    if (status == U_BUFFER_OVERFLOW_ERROR) {
        status = U_ZERO_ERROR;
        result = malloc((length + 1) * sizeof(UChar));
        if (!result) { ureldatefmt_close(formatter); return nil; }
        if (_dateTimeStyle == NSRelativeDateTimeFormatterStyleNamed)
            ureldatefmt_format(formatter, value, unit, result, length + 1, &status);
        else ureldatefmt_formatNumeric(formatter, value, unit, result, length + 1, &status);
    }
    NSString *string = U_SUCCESS(status) ? [NSString stringWithCharacters:result length:length] : nil;
    if (result != buffer) free(result);
    ureldatefmt_close(formatter);
    return string;
}
- (NSString *)localizedStringFromDateComponents:(NSDateComponents *)components
{
    const NSInteger values[] = { [components year], [components month], [components weekOfYear],
        [components day], [components hour], [components minute], [components second] };
    const URelativeDateTimeUnit units[] = { UDAT_REL_UNIT_YEAR, UDAT_REL_UNIT_MONTH, UDAT_REL_UNIT_WEEK,
        UDAT_REL_UNIT_DAY, UDAT_REL_UNIT_HOUR, UDAT_REL_UNIT_MINUTE, UDAT_REL_UNIT_SECOND };
    for (unsigned i = 0; i < 7; ++i) {
        if (values[i] != NSUndefinedDateComponent && values[i] != 0) return [self _formatValue:values[i] unit:units[i]];
    }
    return [self _formatValue:0 unit:UDAT_REL_UNIT_SECOND];
}
- (NSString *)localizedStringForDate:(NSDate *)date relativeToDate:(NSDate *)referenceDate
{
    NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitWeekOfYear |
        NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    return [self localizedStringFromDateComponents:[_calendar components:units fromDate:referenceDate toDate:date options:0]];
}
- (NSString *)localizedStringFromTimeInterval:(NSTimeInterval)interval
{
    if (!isfinite(interval)) return nil;
    // Use a fixed reference: interval formatting must not depend on the wall clock.
    NSDate *reference = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    return [self localizedStringForDate:[reference dateByAddingTimeInterval:round(interval)] relativeToDate:reference];
}
- (NSString *)stringForObjectValue:(id)object
{
    if ([object isKindOfClass:[NSDate class]]) return [self localizedStringForDate:object relativeToDate:[NSDate date]];
    if ([object isKindOfClass:[NSDateComponents class]]) return [self localizedStringFromDateComponents:object];
    return nil;
}
- (BOOL)getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString **)error
{
    if (object) *object = nil;
    if (error) *error = @"Relative date strings cannot be parsed";
    return NO;
}
@end
