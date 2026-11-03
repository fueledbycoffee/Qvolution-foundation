#include <unicode/utypes.h>
#include <unicode/unum.h>

#ifdef __cplusplus
extern "C" {
#endif

// Caller owns the returned UTF-16 buffer. Fields are UTF-16 offsets.
UChar *_NSMeasurementFormat(const char *locale, const char *unit, int style,
                            double value, const UNumberFormat *numberFormat, int32_t *length,
                            int32_t *unitStart, int32_t *unitEnd);

#ifdef __cplusplus
}
#endif
