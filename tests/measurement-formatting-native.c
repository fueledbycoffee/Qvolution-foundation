#include "NSMeasurementFormatting.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unicode/ustring.h>

int main(void)
{
    const char *locales[] = {"en_US_POSIX", "fr_FR", "ja_JP"};
    const char *expected[][4] = {
        {"-1 m", "0 m", "1 m", "1234.5 m"},
        {"-1\xe2\x80\xafm", "0\xe2\x80\xafm", "1\xe2\x80\xafm", "1\xe2\x80\xaf" "234,5\xe2\x80\xafm"},
        {"-1 m", "0 m", "1 m", "1,234.5 m"}
    };
    double values[] = {-1, 0, 1, 1234.5};
    for (int locale = 0; locale < 3; ++locale) for (int i = 0; i < 4; ++i) {
        int32_t length, ns, ne, us, ue;
        UChar *wide = _NSMeasurementFormat(locales[locale], "length-meter", 2, values[i], &length, &ns, &ne, &us, &ue);
        assert(wide && ns == 0 && ne > ns && us > ne && ue == length);
        UErrorCode error = U_ZERO_ERROR;
        char text[100];
        u_strToUTF8(text, sizeof(text), NULL, wide, length, &error);
        assert(U_SUCCESS(error));
        if (strcmp(text, expected[locale][i])) { fprintf(stderr, "locale=%s value=%g expected=%s actual=%s\n",locales[locale],values[i],expected[locale][i],text); abort(); }
        free(wide);
    }
    int32_t length, ns, ne, us, ue;
    UChar *wide = _NSMeasurementFormat("en_US", "length-meter", 3, 2, &length, &ns, &ne, &us, &ue);
    assert(wide && ue-us == 6); free(wide);
    puts("PASS: production ICU measurement formatting, 12 macOS observations and plural unit field");
}
