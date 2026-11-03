#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void) { @autoreleasepool {
    NSArray *units = @[[NSUnitLength megameters], [NSUnitLength kilometers],
        [NSUnitLength hectometers], [NSUnitLength decameters], [NSUnitLength meters],
        [NSUnitLength decimeters], [NSUnitLength centimeters], [NSUnitLength millimeters],
        [NSUnitLength micrometers], [NSUnitLength nanometers], [NSUnitLength picometers],
        [NSUnitLength inches], [NSUnitLength feet], [NSUnitLength yards], [NSUnitLength miles],
        [NSUnitLength scandinavianMiles], [NSUnitLength lightyears], [NSUnitLength nauticalMiles],
        [NSUnitLength fathoms], [NSUnitLength furlongs], [NSUnitLength astronomicalUnits], [NSUnitLength parsecs]];
    for (NSString *locale in @[@"en_US", @"fr_FR", @"ru_RU"]) {
        NSMeasurementFormatter *f = [NSMeasurementFormatter new];
        f.locale = [NSLocale localeWithLocaleIdentifier:locale];
        f.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
        for (NSUInteger style = 1; style <= 3; ++style) {
            f.unitStyle = style;
            for (NSUnit *unit in units) {
                printf("unit(%s,%lu,%s): %s\n", locale.UTF8String, (unsigned long)style, unit.symbol.UTF8String, [f stringFromUnit:unit].UTF8String);
                for (NSNumber *value in @[@1, @2]) {
                    NSMeasurement *m = [[NSMeasurement alloc] initWithDoubleValue:value.doubleValue unit:unit];
                    printf("quantity(%s,%lu,%s,%g): %s\n", locale.UTF8String, (unsigned long)style, unit.symbol.UTF8String, value.doubleValue, [f stringFromMeasurement:m].UTF8String);
                }
            }
        }
        f.unitStyle = NSFormattingUnitStyleLong;
        for (NSUInteger fraction = 0; fraction <= 1; ++fraction) {
            f.numberFormatter.minimumFractionDigits = fraction;
            f.numberFormatter.maximumFractionDigits = fraction;
            for (NSNumber *value in @[@0.99, @1, @1.1, @1.6, @2.1, @5.1]) {
                NSMeasurement *m = [[NSMeasurement alloc] initWithDoubleValue:value.doubleValue unit:[NSUnitLength meters]];
                printf("rounded(%s,%lu,%g): %s\n", locale.UTF8String, (unsigned long)fraction, value.doubleValue, [f stringFromMeasurement:m].UTF8String);
            }
        }
    }
} }
