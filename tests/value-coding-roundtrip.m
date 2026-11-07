#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>
int main(void) { @autoreleasepool {
    int number = 42;
    NSArray *values = @[[NSValue valueWithRange:NSMakeRange(NSUIntegerMax-1,1)],
        [NSValue valueWithPoint:NSMakePoint(1.5,-2.5)],
        [NSValue valueWithSize:NSMakeSize(3.25,4.5)],
        [NSValue valueWithRect:NSMakeRect(1.5,-2.5,3.25,4.5)],
        [NSValue valueWithBytes:&number objCType:@encode(int)]];
    for (NSUInteger format = 0; format < 2; format++) {
        for (NSUInteger secure = 0; secure < 2; secure++) {
            for (NSUInteger i = 0; i < values.count; i++) {
                @try {
                    NSKeyedArchiver *a = [[NSKeyedArchiver alloc] initRequiringSecureCoding:secure];
                    a.outputFormat = format ? NSPropertyListXMLFormat_v1_0 : NSPropertyListBinaryFormat_v1_0;
                    [a encodeObject:values[i] forKey:NSKeyedArchiveRootObjectKey];
                    [a finishEncoding];
                    NSError *error = nil;
                    NSValue *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSValue class] fromData:a.encodedData error:&error];
                    BOOL equal = decoded && [values[i] isEqualToValue:decoded];
                    printf("valueCoding(%lu,%lu,%lu): equal=%d,error=%ld\n",(unsigned long)format,(unsigned long)secure,(unsigned long)i,equal,(long)error.code);
                } @catch (NSException *e) {
                    printf("valueCoding(%lu,%lu,%lu): EXCEPTION %s\n",(unsigned long)format,(unsigned long)secure,(unsigned long)i,[e.name UTF8String]);
                }
            }
        }
    }
    NSValue *raw = values[4];
    for (NSUInteger size = 0; size <= 8; size++) {
        unsigned char bytes[16]; memset(bytes,0xa5,sizeof bytes);
        @try {
            [raw getValue:bytes size:size];
            printf("valueBuffer(%lu): %u,%u,%u,%u,%u\n",(unsigned long)size,bytes[0],bytes[1],bytes[2],bytes[3],bytes[4]);
        } @catch (NSException *e) {
            printf("valueBuffer(%lu): EXCEPTION %s\n",(unsigned long)size,[e.name UTF8String]);
        }
    }
} return 0; }
