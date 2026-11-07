#include "NSMeasurementFormatting.h"
#include "NSMeasurementLocaleData.h"
#include <unicode/measfmt.h>
#include <unicode/measure.h>
#include <unicode/measunit.h>
#include <unicode/numfmt.h>
#include <unicode/ulocdata.h>
#include <unicode/uchar.h>
#include <stdlib.h>
#include <string.h>

static const _NSMeasurementLocaleUpdate *localeUpdate(const icu::Locale &locale, const char *unit, int style)
{
    for (const char *name : {locale.getBaseName(), locale.getLanguage()})
        for (const auto &entry : cldrUpdates)
            if (entry.style == style && !strcmp(entry.locale, name) && !strcmp(entry.unit, unit))
                return &entry;
    return NULL;
}

static icu::UnicodeString withNumber(const char *pattern, const icu::UnicodeString &number)
{
    icu::UnicodeString result = icu::UnicodeString::fromUTF8(pattern);
    int32_t offset = result.indexOf(icu::UnicodeString::fromUTF8("{0}"));
    return result.replace(offset, 3, number);
}

static bool usesPreviousPattern(const _NSMeasurementLocaleUpdate &entry,
                                const icu::UnicodeString &formatted, const icu::UnicodeString &number)
{
    for (const auto &pattern : entry.patterns) {
        if (!pattern.previous) break;
        if (formatted == withNumber(pattern.previous, number)) return true;
    }
    return false;
}

int _NSMeasurementUsesMetricLength(const char *locale)
{
    UErrorCode status = U_ZERO_ERROR;
    return ulocdata_getMeasurementSystem(locale, &status) == UMS_SI;
}

UChar *_NSMeasurementFormat(const char *locale, const char *unit, int style,
                            double value, const UNumberFormat *numberFormat,
                            int32_t *length, int32_t *unitStart, int32_t *unitEnd)
{
    UErrorCode status = U_ZERO_ERROR;
    UNumberFormat *number = numberFormat ? unum_clone(numberFormat, &status) :
        unum_open(UNUM_DECIMAL, NULL, 0, locale, NULL, &status);
    if (U_FAILURE(status) || !number) { unum_close(number); return NULL; }
    // ICU's C handles are NumberFormat objects (Apple OSS ICU, unum.cpp).
    icu::Locale icuLocale(locale);
    icu::MeasureFormat formatter(icuLocale, style == 3 ? UMEASFMT_WIDTH_WIDE :
        style == 1 ? UMEASFMT_WIDTH_NARROW : UMEASFMT_WIDTH_SHORT,
        reinterpret_cast<icu::NumberFormat *>(number), status);
    if (U_FAILURE(status)) return NULL;
    static const struct { const char *identifier; icu::MeasureUnit *(*create)(UErrorCode &); const char *symbol; } units[] = {
        {"length-megameter", NULL, "Mm"},
        {"length-hectometer", NULL, "hm"},
        {"length-decameter", NULL, "dam"},
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
        {"temperature-generic", icu::MeasureUnit::createGenericTemperature},
    };
    icu::MeasureUnit *measureUnit = NULL;
    const char *symbol = NULL;
    for (const auto &entry : units) if (!strcmp(unit, entry.identifier)) {
        if (entry.create) measureUnit = style == 3 && !strcmp(unit, "temperature-generic") ?
            icu::MeasureUnit::createDegree(status) : entry.create(status);
        symbol = entry.symbol;
        break;
    }
    if ((!measureUnit && !symbol) || U_FAILURE(status)) { delete measureUnit; return NULL; }
    const _NSMeasurementLocaleUpdate *update = localeUpdate(icuLocale, unit, style);
    icu::UnicodeString formatted;
    icu::FieldPosition field(UNUM_MEASURE_UNIT_FIELD);
    if (symbol) {
        if (numberFormat) {
            reinterpret_cast<const icu::NumberFormat *>(number)->format(value, formatted);
            formatted.append((UChar)' ');
        }
        field.setBeginIndex(formatted.length());
        formatted.append(icu::UnicodeString::fromUTF8(symbol));
        field.setEndIndex(formatted.length());
    } else if (!numberFormat) {
        formatted = formatter.getUnitDisplayName(*measureUnit, status);
        if (update && update->display && formatted == icu::UnicodeString::fromUTF8(update->previousDisplay)) {
            icu::UnicodeString quantity, numeric;
            icu::Measure measure(1, measureUnit->clone(), status);
            icu::FieldPosition unused;
            formatter.formatMeasures(&measure, 1, quantity, unused, status);
            reinterpret_cast<const icu::NumberFormat *>(number)->format(1, numeric);
            if (usesPreviousPattern(*update, quantity, numeric))
                formatted = icu::UnicodeString::fromUTF8(update->display);
        }
        delete measureUnit;
        field.setBeginIndex(0);
        field.setEndIndex(formatted.length());
    } else {
        icu::Measure measure(value, measureUnit, status);
        formatter.formatMeasures(&measure, 1, formatted, field, status);
        if (update) {
            icu::UnicodeString numeric;
            reinterpret_cast<const icu::NumberFormat *>(number)->format(value, numeric);
            for (const auto &pattern : update->patterns) {
                if (!pattern.previous) break;
                if (!pattern.replacement || formatted != withNumber(pattern.previous, numeric)) continue;
                formatted = withNumber(pattern.replacement, numeric);
                int32_t start = numeric.length();
                while (start < formatted.length() && u_isUWhiteSpace(formatted.charAt(start))) ++start;
                field.setBeginIndex(start);
                field.setEndIndex(formatted.length());
                break;
            }
        }
    }
    if (U_FAILURE(status)) return NULL;
    *length = formatted.length();
    *unitStart = field.getBeginIndex(); *unitEnd = field.getEndIndex();
    UChar *output = static_cast<UChar *>(malloc((*length + 1) * sizeof(UChar)));
    if (output) formatted.extract(output, *length + 1, status);
    if (U_FAILURE(status)) { free(output); return NULL; }
    return output;
}
