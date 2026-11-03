#ifndef NS_LIST_FORMATTER_INTERNAL_H
#define NS_LIST_FORMATTER_INTERNAL_H

#include <unicode/ulistformatter.h>
#include <unicode/ubidi.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* The caller owns the returned UTF-16 buffer, including for an empty list. */
static UChar *NSListFormatItems(UListFormatter *formatter, int rightToLeft,
                              const UChar *const *items, const int32_t *lengths,
                              int32_t count, int32_t *resultLength)
{
    if (!formatter || count < 0) return NULL;
    const UChar **strings = calloc(count ? count : 1, sizeof(*strings));
    int32_t *sizes = calloc(count ? count : 1, sizeof(*sizes));
    if (!strings || !sizes) { free(strings); free(sizes); return NULL; }
    UChar *result = NULL;
    for (int32_t i = 0; i < count; ++i) {
        if (lengths[i] < 0 || lengths[i] > INT32_MAX - 2) goto cleanup;
        sizes[i] = lengths[i];
        if (!rightToLeft || ubidi_getBaseDirection(items[i], lengths[i]) != UBIDI_LTR) {
            strings[i] = items[i];
            continue;
        }
        sizes[i] += 2;
        if ((size_t)sizes[i] > SIZE_MAX / sizeof(UChar) - 1) goto cleanup;
        UChar *text = malloc(((size_t)sizes[i] + 1) * sizeof(UChar));
        if (!text) goto cleanup;
        strings[i] = text;
        text[0] = 0x2068;
        memcpy(text + 1, items[i], (size_t)lengths[i] * sizeof(UChar));
        text[sizes[i] - 1] = 0x2069;
        text[sizes[i]] = 0;
    }
    UErrorCode status = U_ZERO_ERROR;
    int32_t length = ulistfmt_format(formatter, strings, sizes, count, NULL, 0, &status);
    if (status != U_BUFFER_OVERFLOW_ERROR && U_FAILURE(status)) goto cleanup;
    if (length < 0 || length == INT32_MAX || (size_t)length > SIZE_MAX / sizeof(UChar) - 1) goto cleanup;
    result = malloc(((size_t)length + 1) * sizeof(UChar));
    if (!result) goto cleanup;
    status = U_ZERO_ERROR;
    *resultLength = ulistfmt_format(formatter, strings, sizes, count, result, length + 1, &status);
    if (U_FAILURE(status)) { free(result); result = NULL; }
cleanup:
    for (int32_t i = 0; i < count; ++i)
        if (strings[i] && strings[i] != items[i]) free((void *)strings[i]);
    free(strings);
    free(sizes);
    return result;
}
#endif
