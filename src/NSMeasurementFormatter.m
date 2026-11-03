#import <Foundation/NSMeasurementFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSNumberFormatter.h>
#import "NSUnitFormatterInternal.h"
#import <Foundation/NSMeasurement.h>
#import <Foundation/NSUnitLength.h>
#import <Foundation/NSUnitTemperature.h>
#import <Foundation/NSUnitConverterLinear.h>
#import "NSMeasurementFormatting.h"
#include <math.h>
#include <stdlib.h>

static const char *unitIdentifier(NSUnit *unit)
{
    if (![unit isKindOfClass:[NSDimension class]]) return NULL;
    NSUnitConverter *converter = [(NSDimension *)unit converter];
    if (![converter isKindOfClass:[NSUnitConverterLinear class]]) return NULL;
    NSUnitConverterLinear *linear = (NSUnitConverterLinear *)converter;
    NSString *symbol = [unit symbol];
    if ([unit isKindOfClass:[NSUnitLength class]] && [linear constant] == 0) {
        static const struct { NSString *symbol; const char *identifier; double coefficient; } units[] = {
            {@"km", "length-kilometer", 1000}, {@"m", "length-meter", 1},
            {@"dm", "length-decimeter", .1}, {@"cm", "length-centimeter", .01},
            {@"mm", "length-millimeter", .001}, {@"µm", "length-micrometer", 1e-6},
            {@"nm", "length-nanometer", 1e-9}, {@"pm", "length-picometer", 1e-12},
            {@"in", "length-inch", .0254}, {@"ft", "length-foot", .3048},
            {@"yd", "length-yard", .9144}, {@"mi", "length-mile", 1609.344},
            {@"smi", "length-mile-scandinavian", 10000}, {@"ly", "length-light-year", 9.461e15},
            {@"NM", "length-nautical-mile", 1852}, {@"ftm", "length-fathom", 1.8288},
            {@"fur", "length-furlong", 201.168}, {@"ua", "length-astronomical-unit", 1.496e11},
            {@"pc", "length-parsec", 3.086e16}
        };
        for (NSUInteger i = 0; i < sizeof(units)/sizeof(units[0]); ++i)
            if ([linear coefficient] == units[i].coefficient && [symbol isEqualToString:units[i].symbol])
                return units[i].identifier;
    }
    if ([unit isKindOfClass:[NSUnitTemperature class]]) {
        if ([symbol isEqualToString:@"°C"] && [linear coefficient] == 1 && [linear constant] == 273.15)
            return "temperature-celsius";
        if ([symbol isEqualToString:@"°F"] && [linear coefficient] == .55555555555556 && [linear constant] == 255.37222222222427)
            return "temperature-fahrenheit";
        if ([symbol isEqualToString:@"K"] && [linear coefficient] == 1 && [linear constant] == 0)
            return "temperature-kelvin";
    }
    return NULL;
}

@implementation NSMeasurementFormatter

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _unitStyle = NSFormattingUnitStyleMedium;
        _locale = [[NSLocale currentLocale] copy];
        _numberFormatter = _NSUnitFormatterNewNumberFormatter();
        [_numberFormatter setLocale:_locale];
    }
    return self;
}

- (void)dealloc
{
    [_locale release];
    [_numberFormatter release];
    [super dealloc];
}

- (NSLocale *)locale
{
    return _locale;
}

- (void)setLocale:(NSLocale *)locale
{
    NSLocale *old = _locale;
    _locale = [locale ?: [NSLocale currentLocale] copy];
    [old release];
    [_numberFormatter setLocale:_locale];
}

- (NSNumberFormatter *)numberFormatter
{
    return _numberFormatter;
}

- (void)setNumberFormatter:(NSNumberFormatter *)numberFormatter
{
    NSNumberFormatter *old = _numberFormatter;
    _numberFormatter = numberFormatter != nil ? [numberFormatter copy] : _NSUnitFormatterNewNumberFormatter();
    if (numberFormatter == nil) [_numberFormatter setLocale:_locale];
    [old release];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSMeasurementFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy->_unitOptions = _unitOptions;
    copy->_unitStyle = _unitStyle;
    [copy setLocale:_locale];
    [copy setNumberFormatter:_numberFormatter];
    return copy;
}

- (NSString *)_stringFromValue:(double)value unit:(NSUnit *)unit unitOnly:(BOOL)unitOnly
{
    if (!unit) [NSException raise:NSInvalidArgumentException format:@"A unit is required"];
    const char *identifier = unitIdentifier(unit);
    if (!identifier) {
        if (unitOnly) return [unit symbol];
        return _NSUnitFormatterJoin(_numberFormatter, _unitStyle, value, [unit symbol]);
    }
    int32_t length, numberStart, numberEnd, unitStart, unitEnd;
    UChar *buffer = _NSMeasurementFormat([[_locale localeIdentifier] UTF8String], identifier, _unitStyle,
        value, &length, &numberStart, &numberEnd, &unitStart, &unitEnd);
    if (!buffer) [NSException raise:NSInternalInconsistencyException format:@"Unable to format measurement"];
    NSString *formatted = [[[NSString alloc] initWithCharacters:buffer length:length] autorelease];
    free(buffer);
    if (unitOnly) return [formatted substringWithRange:NSMakeRange(unitStart, unitEnd - unitStart)];
    NSString *number = [_numberFormatter stringFromNumber:[NSNumber numberWithDouble:value]];
    if (!number) [NSException raise:NSInternalInconsistencyException format:@"Unable to format measurement number"];
    formatted = [formatted stringByReplacingCharactersInRange:NSMakeRange(numberStart, numberEnd - numberStart) withString:number];
    if ((_unitOptions & NSMeasurementFormatterUnitOptionsTemperatureWithoutUnit) &&
        [unit isKindOfClass:[NSUnitTemperature class]] && ![unit isEqual:[NSUnitTemperature kelvin]])
        return [number stringByAppendingString:@"°"];
    return formatted;
}

- (NSString *)stringFromUnit:(NSUnit *)unit
{
    return [self _stringFromValue:1 unit:unit unitOnly:YES];
}

- (NSString *)stringFromMeasurement:(NSMeasurement *)measurement
{
    if (!measurement) [NSException raise:NSInvalidArgumentException format:@"A measurement is required"];
    NSUnit *unit = [measurement unit];
    if (!(_unitOptions & NSMeasurementFormatterUnitOptionsProvidedUnit)) {
        if ([unit isKindOfClass:[NSUnitTemperature class]]) {
            NSString *country = [_locale objectForKey:NSLocaleCountryCode];
            unit = [country isEqualToString:@"US"] ? [NSUnitTemperature fahrenheit] : [NSUnitTemperature celsius];
        } else if ([unit isKindOfClass:[NSUnitLength class]]) {
            BOOL metric = [[_locale objectForKey:NSLocaleUsesMetricSystem] boolValue];
            unit = metric ? [NSUnitLength kilometers] : [NSUnitLength miles];
        }
    }
    if ((_unitOptions & NSMeasurementFormatterUnitOptionsNaturalScale) && [unit isKindOfClass:[NSUnitLength class]]) {
        double meters = fabs([[measurement measurementByConvertingToUnit:[NSUnitLength meters]] doubleValue]);
        BOOL metric = (_unitOptions & NSMeasurementFormatterUnitOptionsProvidedUnit) ?
            ([unit isEqual:[NSUnitLength kilometers]] || [unit isEqual:[NSUnitLength meters]] ||
             [unit isEqual:[NSUnitLength centimeters]] || [unit isEqual:[NSUnitLength millimeters]]) :
            [[_locale objectForKey:NSLocaleUsesMetricSystem] boolValue];
        if (metric) unit = meters >= 1000 ? [NSUnitLength kilometers] : meters >= 1 || meters == 0 ?
            [NSUnitLength meters] : meters >= .01 ? [NSUnitLength centimeters] : [NSUnitLength millimeters];
        else unit = meters >= 1609.344 ? [NSUnitLength miles] : meters >= .3048 || meters == 0 ?
            [NSUnitLength feet] : [NSUnitLength inches];
    }
    if (![[measurement unit] isEqual:unit]) measurement = [measurement measurementByConvertingToUnit:unit];
    return [self _stringFromValue:[measurement doubleValue] unit:unit unitOnly:NO];
}

- (NSString *)stringForObjectValue:(id)object
{
    return [object isKindOfClass:[NSMeasurement class]] ? [self stringFromMeasurement:object] : nil;
}

- (BOOL)getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString **)error
{
    if (object) *object = nil;
    if (error) *error = @"Measurement parsing is unsupported";
    return NO;
}

@end
