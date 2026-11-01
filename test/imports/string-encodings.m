#import <Foundation/Foundation.h>
#include <stdio.h>
int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    const NSStringEncoding *encodings = [NSString availableStringEncodings];
    if (!encodings) return 1;
    BOOL utf8 = NO;
    for (NSUInteger i = 0; encodings[i]; ++i) {
        if (encodings[i] == NSUTF8StringEncoding) utf8 = YES;
    }
    if (!utf8 || ![[NSString localizedNameOfStringEncoding:NSUTF8StringEncoding] length]) return 2;
    if ([[NSString localizedNameOfStringEncoding:(NSStringEncoding)-1] length]) return 3;
    [pool drain];
    puts("string-encodings: passed");
    return 0;
}
