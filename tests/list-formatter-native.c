/* Rung 4: oracle-foundation2/20261103T101800Z-checks/mac/NSListFormatter.txt.
 * Runs the production joining code natively with ICU, without a container. */
#include "NSListFormatterInternal.h"
#include <unicode/uloc.h>
#include <unicode/ustring.h>
#include <assert.h>
#include <stdio.h>

static UChar *utf16(const char *text, int32_t *length)
{
    UErrorCode status = U_ZERO_ERROR;
    u_strFromUTF8(NULL, 0, length, text, -1, &status);
    assert(status == U_BUFFER_OVERFLOW_ERROR || U_SUCCESS(status));
    UChar *result = calloc((size_t)*length + 1, sizeof(UChar));
    status = U_ZERO_ERROR;
    u_strFromUTF8(result, *length + 1, NULL, text, -1, &status);
    assert(U_SUCCESS(status));
    return result;
}

static const char *inputs[][3] = {
    {NULL}, {"a"}, {"a", "b"}, {"a", "b", "c"}, {"", "b"},
    {"é", "😀", "é"}, {"a,b", "c and d", "e"}, {"x", "x", "x"},
    {NULL}, {"1"}, {"1", "2.5"}, {"-1", "0", "1234.5"}
};
static const int32_t counts[] = {0,1,2,3,2,3,3,3,0,1,2,3};
static const char *locales[] = {"en_US_POSIX", "fr_FR", "ja_JP", "ar_EG", "de_DE"};
static const char *expected[][12] = {
    {"", "a", "a and b", "a, b, and c", " and b", "é, 😀, and é", "a,b, c and d, and e", "x, x, and x", "", "1", "1 and 2.5", "-1, 0, and 1234.5"},
    {"", "a", "a et b", "a, b et c", " et b", "é, 😀 et é", "a,b, c and d et e", "x, x et x", "", "1", "1 et 2.5", "-1, 0 et 1234.5"},
    {"", "a", "a、b", "a、b、c", "、b", "é、😀、é", "a,b、c and d、e", "x、x、x", "", "1", "1、2.5", "-1、0、1234.5"},
    {"", "\u2068a\u2069", "\u2068a\u2069 و\u2068b\u2069", "\u2068a\u2069 و\u2068b\u2069 و\u2068c\u2069", " و\u2068b\u2069", "\u2068é\u2069 و😀 و\u2068é\u2069", "\u2068a,b\u2069 و\u2068c and d\u2069 و\u2068e\u2069", "\u2068x\u2069 و\u2068x\u2069 و\u2068x\u2069", "", "1", "1 و2.5", "-1 و0 و1234.5"},
    {"", "a", "a und b", "a, b und c", " und b", "é, 😀 und é", "a,b, c and d und e", "x, x und x", "", "1", "1 und 2.5", "-1, 0 und 1234.5"}
};

int main(void)
{
    for (unsigned locale = 0; locale < 5; ++locale) {
        UErrorCode status = U_ZERO_ERROR;
        UListFormatter *formatter = ulistfmt_open(locales[locale], &status);
        assert(U_SUCCESS(status));
        for (unsigned test = 0; test < 12; ++test) {
            UChar *items[3] = {0}; int32_t lengths[3] = {0};
            for (int i = 0; i < counts[test]; ++i) items[i] = utf16(inputs[test][i], &lengths[i]);
            int32_t wantedLength, resultLength = -1;
            UChar *wanted = utf16(expected[locale][test], &wantedLength);
            UChar *actual = NSListFormatItems(formatter, uloc_isRightToLeft(locales[locale]),
                (const UChar *const *)items, lengths, counts[test], &resultLength);
            if (!actual || wantedLength != resultLength || memcmp(actual, wanted, wantedLength * sizeof(UChar))) {
                fprintf(stderr, "FAIL locale=%s case=%u\n", locales[locale], test);
                return 1;
            }
            free(wanted); free(actual);
            for (int i = 0; i < counts[test]; ++i) free(items[i]);
        }
        ulistfmt_close(formatter);
    }
    UErrorCode status = U_ZERO_ERROR;
    UListFormatter *formatter = ulistfmt_open("en_US_POSIX", &status);
    UChar *longItem = calloc(8192, sizeof(UChar));
    for (int i = 0; i < 8192; ++i) longItem[i] = 'x';
    const UChar *longItems[] = {longItem, longItem};
    int32_t longLengths[] = {8192,8192}, length;
    UChar *actual = NSListFormatItems(formatter, 0, longItems, longLengths, 2, &length);
    assert(actual && length == 16389 && actual[8192] == ' ' && actual[8193] == 'a');
    free(actual); free(longItem);
    const UChar nulText[] = {'a',0,'b'};
    const UChar *nulItems[] = {nulText}; int32_t nulLengths[] = {3};
    actual = NSListFormatItems(formatter, 0, nulItems, nulLengths, 1, &length);
    assert(actual && length == 3 && !memcmp(actual, nulText, sizeof(nulText)));
    free(actual);
    int32_t badLengths[] = {-1};
    assert(!NSListFormatItems(formatter, 0, nulItems, badLengths, 1, &length));
    assert(!NSListFormatItems(NULL, 0, nulItems, nulLengths, 1, &length));
    ulistfmt_close(formatter);
    puts("PASS: 60 macOS list results; long output; embedded NUL; rejected invalid lengths");
    return 0;
}
