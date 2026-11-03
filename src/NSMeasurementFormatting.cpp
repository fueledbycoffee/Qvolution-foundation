#include "NSMeasurementFormatting.h"
#include <unicode/measfmt.h>
#include <unicode/measure.h>
#include <unicode/measunit.h>
#include <unicode/numfmt.h>
#include <stdlib.h>
#include <string.h>

UChar *_NSMeasurementFormat(const char *locale, const char *unit, int style,
                            double value, const UNumberFormat *numberFormat,
                            int32_t *length, int32_t *unitStart, int32_t *unitEnd)
{
    UErrorCode status = U_ZERO_ERROR;
    UNumberFormat *number = numberFormat ? unum_clone(numberFormat, &status) :
        unum_open(UNUM_DECIMAL, NULL, 0, locale, NULL, &status);
    if (U_FAILURE(status) || !number) { unum_close(number); return NULL; }
    // ICU's C handles are NumberFormat objects (Apple OSS ICU, unum.cpp).
    icu::MeasureFormat formatter(icu::Locale(locale), style == 3 ? UMEASFMT_WIDTH_WIDE :
        style == 1 ? UMEASFMT_WIDTH_NARROW : UMEASFMT_WIDTH_SHORT,
        reinterpret_cast<icu::NumberFormat *>(number), status);
    static const struct { const char *identifier; icu::MeasureUnit *(*create)(UErrorCode &); } units[] = {
        {"length-kilometer", icu::MeasureUnit::createKilometer},
        {"length-meter", icu::MeasureUnit::createMeter},
        {"length-decimeter", icu::MeasureUnit::createDecimeter},
        {"length-centimeter", icu::MeasureUnit::createCentimeter},
        {"length-millimeter", icu::MeasureUnit::createMillimeter},
        {"length-micrometer", icu::MeasureUnit::createMicrometer},
        {"length-nanometer", icu::MeasureUnit::createNanometer},
        {"length-picometer", icu::MeasureUnit::createPicometer},
        {"length-inch", icu::MeasureUnit::createInch},
        {"length-foot", icu::MeasureUnit::createFoot},
        {"length-yard", icu::MeasureUnit::createYard},
        {"length-mile", icu::MeasureUnit::createMile},
        {"length-mile-scandinavian", icu::MeasureUnit::createMileScandinavian},
        {"length-light-year", icu::MeasureUnit::createLightYear},
        {"length-nautical-mile", icu::MeasureUnit::createNauticalMile},
        {"length-fathom", icu::MeasureUnit::createFathom},
        {"length-furlong", icu::MeasureUnit::createFurlong},
        {"length-astronomical-unit", icu::MeasureUnit::createAstronomicalUnit},
        {"length-parsec", icu::MeasureUnit::createParsec},
        {"temperature-celsius", icu::MeasureUnit::createCelsius},
        {"temperature-fahrenheit", icu::MeasureUnit::createFahrenheit},
        {"temperature-kelvin", icu::MeasureUnit::createKelvin},
    };
    icu::MeasureUnit *measureUnit = NULL;
    for (const auto &entry : units) if (!strcmp(unit, entry.identifier)) {
        measureUnit = entry.create(status);
        break;
    }
    if (!measureUnit || U_FAILURE(status)) { delete measureUnit; return NULL; }
    icu::Measure measure(value, measureUnit, status);
    icu::UnicodeString formatted;
    icu::FieldPosition field(UNUM_MEASURE_UNIT_FIELD);
    formatter.formatMeasures(&measure, 1, formatted, field, status);
    if (U_FAILURE(status)) return NULL;
    *length = formatted.length();
    *unitStart = field.getBeginIndex(); *unitEnd = field.getEndIndex();
    UChar *output = static_cast<UChar *>(malloc((*length + 1) * sizeof(UChar)));
    if (output) formatted.extract(output, *length + 1, status);
    if (U_FAILURE(status)) { free(output); return NULL; }
    return output;
}
