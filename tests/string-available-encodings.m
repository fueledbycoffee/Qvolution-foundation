// Guest test: +[NSString availableStringEncodings] and
// +localizedNameOfStringEncoding: per the NSString reference (rung 3).
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
static void expect(BOOL ok, const char *what) {
    if (!ok) { failures++; printf("FAIL %s\n", what); }
}

int main(void) {
    @autoreleasepool {
        const NSStringEncoding *list = [NSString availableStringEncodings];
        expect(list != NULL, "list is not NULL");
        NSUInteger count = 0;
        BOOL utf8 = NO, ascii = NO, latin1 = NO, unicode = NO, duplicate = NO, convertible = YES;
        BOOL utf16be = NO, utf16le = NO, utf32 = NO, utf32be = NO, utf32le = NO;
        while (list != NULL && count < 4096 && list[count] != 0) {
            NSStringEncoding e = list[count];
            utf16be |= e == NSUTF16BigEndianStringEncoding; utf16le |= e == NSUTF16LittleEndianStringEncoding;
            utf32 |= e == NSUTF32StringEncoding; utf32be |= e == NSUTF32BigEndianStringEncoding;
            utf32le |= e == NSUTF32LittleEndianStringEncoding;
            utf8 |= e == NSUTF8StringEncoding; ascii |= e == NSASCIIStringEncoding;
            latin1 |= e == NSISOLatin1StringEncoding; unicode |= e == NSUnicodeStringEncoding;
            for (NSUInteger j = 0; j < count; j++) duplicate |= list[j] == e;
            CFStringEncoding cf = CFStringConvertNSStringEncodingToEncoding(e);
            convertible &= cf != kCFStringEncodingInvalidId && CFStringIsEncodingAvailable(cf);
            count++;
        }
        expect(count > 0 && count < 4096, "list is non-empty and zero-terminated");
        expect(utf8 && ascii && latin1 && unicode, "list holds UTF-8, ASCII, ISO Latin 1 and UTF-16");
        expect(utf16be && utf16le && utf32 && utf32be && utf32le, "explicit-endian Unicode encodings use public constants");
        expect(!duplicate, "no encoding is listed twice");
        expect(convertible, "every listed encoding is available to CoreFoundation");
        expect([NSString availableStringEncodings] == list, "the list is built once");
        NSString *name = [NSString localizedNameOfStringEncoding: NSUTF8StringEncoding];
        expect(name != nil && [name length] > 0, "UTF-8 has a name");
        expect([[NSString localizedNameOfStringEncoding: NSASCIIStringEncoding] length] > 0, "ASCII has a name");
        expect([NSString localizedNameOfStringEncoding: (NSStringEncoding) 0x7fffff00] == nil,
               "an unknown encoding has no name");
        printf("%s string-available-encodings count=%lu failures=%d\n",
               failures ? "FAIL" : "PASS", (unsigned long) count, failures);
        return failures ? 1 : 0;
    }
}
