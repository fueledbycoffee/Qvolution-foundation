#include <unicode/utypes.h>

// Caller owns the returned UTF-16 buffer. Fields are UTF-16 offsets.
UChar *_NSMeasurementFormat(const char *locale, const char *unit, int style,
                            double value, int32_t *length, int32_t *numberStart,
                            int32_t *numberEnd, int32_t *unitStart, int32_t *unitEnd);
