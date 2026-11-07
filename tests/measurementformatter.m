#import <Foundation/Foundation.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        NSMeasurementFormatter *formatter = [[NSMeasurementFormatter alloc] init];
        expect(formatter.unitOptions == 0, @"default unitOptions");
        expect(formatter.unitStyle == NSFormattingUnitStyleMedium, @"default unitStyle");
        expect([formatter.locale.localeIdentifier isEqualToString:[(NSLocale *)[NSLocale currentLocale] localeIdentifier]], @"default locale is the current locale");
        expect(formatter.numberFormatter.numberStyle == NSNumberFormatterDecimalStyle, @"default number formatter is decimal");

        formatter.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit | NSMeasurementFormatterUnitOptionsNaturalScale;
        formatter.unitStyle = NSFormattingUnitStyleLong;
        NSLocale *german = [NSLocale localeWithLocaleIdentifier:@"de_DE"];
        formatter.locale = german;
        formatter.numberFormatter.locale = german;
        expect(formatter.unitOptions == (NSMeasurementFormatterUnitOptionsProvidedUnit | NSMeasurementFormatterUnitOptionsNaturalScale), @"unitOptions");
        expect(formatter.unitStyle == NSFormattingUnitStyleLong, @"unitStyle");
        expect([formatter.locale.localeIdentifier isEqualToString:@"de_DE"], @"locale");
        expect([[formatter.numberFormatter stringFromNumber:@1234.5] isEqualToString:@"1.234,5"], @"number formatter keeps its locale");

        NSNumberFormatter *percent = [[NSNumberFormatter alloc] init];
        percent.numberStyle = NSNumberFormatterPercentStyle;
        formatter.numberFormatter = percent;
        expect(formatter.numberFormatter != percent && formatter.numberFormatter.numberStyle == NSNumberFormatterPercentStyle, @"numberFormatter is copied");

        NSMeasurementFormatter *copy = [formatter copy];
        expect(copy == formatter, @"copy retains the formatter");

        formatter.locale = nil;
        formatter.numberFormatter = nil;
        expect([formatter.locale.localeIdentifier isEqualToString:[(NSLocale *)[NSLocale currentLocale] localeIdentifier]], @"nil locale resets");
        expect(formatter.numberFormatter.numberStyle == NSNumberFormatterDecimalStyle, @"nil numberFormatter resets");

        NSArray *locales = @[@"en_US_POSIX", @"fr_FR", @"ja_JP"];
        NSArray *expected = @[
            @[@"-1 m", @"0 m", @"1 m", @"1234.5 m"],
            @[@"-1\u202fm", @"0\u202fm", @"1\u202fm", @"1\u202f234,5\u202fm"],
            @[@"-1 m", @"0 m", @"1 m", @"1,234.5 m"]
        ];
        double values[] = {-1, 0, 1, 1234.5};
        formatter.unitStyle = NSFormattingUnitStyleMedium;
        formatter.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
        for (NSUInteger l = 0; l < [locales count]; ++l) {
            formatter.locale = [NSLocale localeWithLocaleIdentifier:[locales objectAtIndex:l]];
            for (NSUInteger i = 0; i < 4; ++i) {
                NSMeasurement *measurement = [[NSMeasurement alloc] initWithDoubleValue:values[i] unit:[NSUnitLength meters]];
                expect([[formatter stringFromMeasurement:measurement] isEqualToString:[[expected objectAtIndex:l] objectAtIndex:i]], @"macOS observed localized meter formatting");
                [measurement release];
            }
        }
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        expect([[formatter stringFromUnit:[NSUnitLength meters]] isEqualToString:@"m"], @"localized unit symbol");
        expect([formatter stringForObjectValue:@"not a measurement"] == nil, @"reject unrelated object");

        NSArray *roundingLocales = @[@"en_US", @"ru_RU"];
        NSArray *rounded = @[@"1 meter", @"1 метр"];
        NSArray *padded = @[@"1.0 meters", @"1,0 метра"];
        formatter.unitStyle = NSFormattingUnitStyleLong;
        for (NSUInteger l = 0; l < [roundingLocales count]; ++l) {
            formatter.locale = [NSLocale localeWithLocaleIdentifier:[roundingLocales objectAtIndex:l]];
            formatter.numberFormatter.minimumFractionDigits = 0;
            formatter.numberFormatter.maximumFractionDigits = 0;
            NSMeasurement *m = [[NSMeasurement alloc] initWithDoubleValue:1.1 unit:[NSUnitLength meters]];
            expect([[formatter stringFromMeasurement:m] isEqualToString:[rounded objectAtIndex:l]], @"rounding chooses the displayed singular quantity");
            [m release];
            NSNumberFormatter *paddedNumbers = [formatter.numberFormatter copy];
            paddedNumbers.minimumFractionDigits = 1;
            paddedNumbers.maximumFractionDigits = 1;
            formatter.numberFormatter = paddedNumbers;
            [paddedNumbers release];
            m = [[NSMeasurement alloc] initWithDoubleValue:1 unit:[NSUnitLength meters]];
            expect([[formatter stringFromMeasurement:m] isEqualToString:[padded objectAtIndex:l]], @"visible fraction digits participate in plural selection");
            [m release];
        }

        NSLog(@"PASS: NSMeasurementFormatter");
    }
    return 0;
}
