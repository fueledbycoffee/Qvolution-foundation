#import <Foundation/NSFormatter.h>

@class NSLocale, NSNumberFormatter, NSMeasurement, NSUnit;

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSMeasurementFormatterUnitOptions) {
    NSMeasurementFormatterUnitOptionsProvidedUnit = (1UL << 0),
    NSMeasurementFormatterUnitOptionsNaturalScale = (1UL << 1),
    NSMeasurementFormatterUnitOptionsTemperatureWithoutUnit = (1UL << 2),
};

@interface NSMeasurementFormatter : NSFormatter
{
    NSMeasurementFormatterUnitOptions _unitOptions;
    NSFormattingUnitStyle _unitStyle;
    NSLocale *_locale;
    NSNumberFormatter *_numberFormatter;
}

- (NSString *)stringFromMeasurement:(NSMeasurement *)measurement;
- (NSString *)stringFromUnit:(NSUnit *)unit;

@property NSMeasurementFormatterUnitOptions unitOptions;
@property NSFormattingUnitStyle unitStyle;
@property (null_resettable, copy) NSLocale *locale;
@property (null_resettable, copy) NSNumberFormatter *numberFormatter;

@end

NS_ASSUME_NONNULL_END
