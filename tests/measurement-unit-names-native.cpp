#include "NSMeasurementFormatting.h"
#include <unicode/ustring.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

int main() {
    struct { const char *locale, *expected; } cases[] = {
        {"en_US", "meters"}, {"fr_FR", "mètres"}, {"ru_RU", "метры"}
    };
    for (auto item : cases) {
        int32_t length, start, end;
        UChar *result = _NSMeasurementFormat(item.locale, "length-meter", 3, 1,
                                             NULL, &length, &start, &end);
        assert(result && start == 0 && end == length);
        char utf8[256];
        UErrorCode status = U_ZERO_ERROR;
        u_strToUTF8(utf8, sizeof utf8, NULL, result, length, &status);
        assert(U_SUCCESS(status) && !strcmp(utf8, item.expected));
        printf("PASS: %s standalone %s\n", item.locale, utf8);
        free(result);
    }
}
