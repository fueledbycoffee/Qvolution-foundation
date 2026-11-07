// Public-API regression for the NSNumberFormatter/ICU backend bridge.
#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void) { @autoreleasepool {
    NSMeasurementFormatter *formatter = [NSMeasurementFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
    formatter.unitStyle = NSFormattingUnitStyleMedium;
    NSMeasurement *measurement = [[NSMeasurement alloc] initWithDoubleValue:1234.5 unit:[NSUnitLength meters]];
    printf("backend.format: %s\n", [formatter stringFromMeasurement:measurement].UTF8String);
    printf("backend.options: %lu\n", (unsigned long)formatter.unitOptions);
    printf("backend.style: %ld\n", (long)formatter.unitStyle);
    formatter.numberFormatter.maximumFractionDigits = 0;
    printf("backend.round: %s\n", [formatter stringFromMeasurement:measurement].UTF8String);
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"fr_FR"];
    formatter.numberFormatter.minimumFractionDigits = 1;
    formatter.numberFormatter.maximumFractionDigits = 1;
    printf("backend.locale: %s\n", [formatter stringFromMeasurement:measurement].UTF8String);
    formatter.unitStyle = NSFormattingUnitStyleLong;
    printf("backend.long: %s\n", [formatter stringFromMeasurement:measurement].UTF8String);
    printf("backend.longStyle: %ld\n", (long)formatter.unitStyle);
} return 0; }
