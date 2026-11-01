#import <Foundation/NSFormatter.h>
#import <Foundation/NSDate.h>
@class NSLocale, NSCalendar, NSDateComponents;

// GUESS: public interface reconstructed from API names; validate enum ABI on a permitted host.
typedef NS_ENUM(NSInteger, NSRelativeDateTimeFormatterStyle) {
    NSRelativeDateTimeFormatterStyleNumeric = 0,
    NSRelativeDateTimeFormatterStyleNamed = 1,
};
typedef NS_ENUM(NSInteger, NSRelativeDateTimeFormatterUnitsStyle) {
    NSRelativeDateTimeFormatterUnitsStyleFull = 0,
    NSRelativeDateTimeFormatterUnitsStyleSpellOut = 1,
    NSRelativeDateTimeFormatterUnitsStyleShort = 2,
    NSRelativeDateTimeFormatterUnitsStyleAbbreviated = 3,
};

@interface NSRelativeDateTimeFormatter : NSFormatter {
    NSLocale *_locale;
    NSCalendar *_calendar;
    NSRelativeDateTimeFormatterStyle _dateTimeStyle;
    NSRelativeDateTimeFormatterUnitsStyle _unitsStyle;
    NSFormattingContext _formattingContext;
}
@property (copy) NSLocale *locale;
@property (copy) NSCalendar *calendar;
@property NSRelativeDateTimeFormatterStyle dateTimeStyle;
@property NSRelativeDateTimeFormatterUnitsStyle unitsStyle;
@property NSFormattingContext formattingContext;
- (NSString *)localizedStringForDate:(NSDate *)date relativeToDate:(NSDate *)referenceDate;
- (NSString *)localizedStringFromDateComponents:(NSDateComponents *)dateComponents;
- (NSString *)localizedStringFromTimeInterval:(NSTimeInterval)timeInterval;
@end
