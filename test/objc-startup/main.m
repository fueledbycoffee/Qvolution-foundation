#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    if (getenv("DYLD_FORCE_FLAT_NAMESPACE") || getenv("DYLD_INSERT_LIBRARIES")) {
        fprintf(stderr,"FAIL: startup must not use diagnostic loader overrides\n");
        return 2;
    }
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    for (uint32_t i=0; i<_dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name,"libswiftFoundation.dylib")) {
            fprintf(stderr,"FAIL: Objective-C startup eagerly loaded the legacy Swift overlay\n");
            return 1;
        }
    }
    NSDictionary *value = [NSDictionary dictionaryWithObject:@"Qvolution — café 🐧" forKey:@"text"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:0 error:&error];
    NSDictionary *decoded = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
    if (![decoded isEqual:value]) {
        fprintf(stderr,"FAIL: Foundation Unicode JSON round trip after normal startup\n");
        return 1;
    }
    [pool drain];
    puts("PASS: normal Objective-C Foundation startup and Unicode JSON round trip");
    return 0;
}
