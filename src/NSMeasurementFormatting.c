#include "NSMeasurementFormatting.h"
#include <unicode/unumberformatter.h>
#include <unicode/unum.h>
#include <stdlib.h>
#include <stdio.h>

UChar *_NSMeasurementFormat(const char *locale, const char *unit, int style,
                            double value, int32_t *length, int32_t *numberStart,
                            int32_t *numberEnd, int32_t *unitStart, int32_t *unitEnd)
{
    char skeleton[160];
    int n = snprintf(skeleton, sizeof(skeleton), "measure-unit/%s unit-width-%s precision-unlimited",
                     unit, style == 3 ? "full-name" : style == 1 ? "narrow" : "short");
    if (n < 0 || n >= sizeof(skeleton)) return NULL;
    UChar wide[160];
    for (int i = 0; i <= n; ++i) wide[i] = (unsigned char)skeleton[i];
    UErrorCode status = U_ZERO_ERROR;
    UNumberFormatter *formatter = unumf_openForSkeletonAndLocale(wide, n, locale, &status);
    UFormattedNumber *result = unumf_openResult(&status);
    UFieldPositionIterator *fields = ufieldpositer_open(&status);
    UChar *output = NULL;
    if (U_FAILURE(status)) goto done;
    unumf_formatDouble(formatter, value, result, &status);
    if (U_FAILURE(status)) goto done;
    *length = unumf_resultToString(result, NULL, 0, &status);
    if (status != U_BUFFER_OVERFLOW_ERROR && U_FAILURE(status)) goto done;
    status = U_ZERO_ERROR;
    output = malloc((*length + 1) * sizeof(UChar));
    if (!output) goto done;
    unumf_resultToString(result, output, *length + 1, &status);
    unumf_resultGetAllFieldPositions(result, fields, &status);
    *numberStart = *length; *numberEnd = 0; *unitStart = *unitEnd = 0;
    int32_t start, end, field;
    while ((field = ufieldpositer_next(fields, &start, &end)) >= 0) {
        if (field == UNUM_MEASURE_UNIT_FIELD) { *unitStart = start; *unitEnd = end; }
        else {
            if (start < *numberStart) *numberStart = start;
            if (end > *numberEnd) *numberEnd = end;
        }
    }
    if (U_FAILURE(status) || *numberEnd <= *numberStart) { free(output); output = NULL; }
done:
    ufieldpositer_close(fields);
    unumf_closeResult(result);
    unumf_close(formatter);
    return output;
}
