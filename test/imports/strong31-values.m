#import <Foundation/Foundation.h>
#import <Foundation/NSRelativeDateTimeFormatter.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d\n", __LINE__); return 1; } } while (0)
int main(void) {
    @autoreleasepool {
        NSMutableData *data = [NSMutableData dataWithBytes:"abc" length:3];
        NSURLSessionWebSocketMessage *binary = [[NSURLSessionWebSocketMessage alloc] initWithData:data];
        [data appendBytes:"d" length:1];
        CHECK([binary type] == NSURLSessionWebSocketMessageTypeData);
        CHECK([[binary data] length] == 3 && [binary string] == nil);
        NSMutableString *text = [NSMutableString stringWithString:@"hello"];
        NSURLSessionWebSocketMessage *message = [[NSURLSessionWebSocketMessage alloc] initWithString:text];
        [text appendString:@"!"];
        CHECK([message type] == NSURLSessionWebSocketMessageTypeString);
        CHECK([[message string] isEqualToString:@"hello"] && [message data] == nil);
        NSRelativeDateTimeFormatter *format = [[NSRelativeDateTimeFormatter alloc] init];
        [format setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
        [format setDateTimeStyle:NSRelativeDateTimeFormatterStyleNumeric];
        NSDateComponents *components = [[NSDateComponents alloc] init];
        [components setDay:-1];
        CHECK([[format localizedStringFromDateComponents:components] isEqualToString:@"1 day ago"]);
        [format setDateTimeStyle:NSRelativeDateTimeFormatterStyleNamed];
        CHECK([[format localizedStringFromDateComponents:components] isEqualToString:@"yesterday"]);
        [format setDateTimeStyle:NSRelativeDateTimeFormatterStyleNumeric];
        CHECK([[format localizedStringFromTimeInterval:120] isEqualToString:@"in 2 minutes"]);
        CHECK([NSPresentationIntentAttributeName isEqualToString:@"NSPresentationIntent"]);
        int fds[2];
        CHECK(pipe(fds) == 0);
        NSFileHandle *writer = [[NSFileHandle alloc] initWithFileDescriptor:fds[1] closeOnDealloc:YES];
        NSFileHandle *reader = [[NSFileHandle alloc] initWithFileDescriptor:fds[0] closeOnDealloc:YES];
        [writer closeFile];
        puts("PASS checked writer close"); fflush(stdout);
        NSError *error = nil;
        CHECK(![writer writeData:data error:&error]);
        CHECK([[error domain] isEqualToString:NSPOSIXErrorDomain] && [error code] == EBADF);
        CHECK(![writer writeData:[NSData data] error:NULL]);
        [reader closeFile];
        error = nil;
        CHECK([reader readDataUpToLength:1 error:&error] == nil);
        CHECK([[error domain] isEqualToString:NSPOSIXErrorDomain] && [error code] == EBADF);
        CHECK([reader readDataUpToLength:0 error:NULL] == nil);
        [writer release]; [reader release];
        puts("PASS strong31 Objective-C values"); fflush(stdout);
    }
    return 0;
}
