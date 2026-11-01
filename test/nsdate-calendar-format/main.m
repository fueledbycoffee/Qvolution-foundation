#import <Foundation/Foundation.h>
#import <Foundation/NSCalendarDate.h>
#include <stdio.h>

static int failures;

static void expectString(NSString *actual, NSString *expected, const char *label)
{
    BOOL matches = [actual isEqualToString:expected];
    printf("%s %s", matches ? "PASS" : "FAIL", label);
    if (!matches)
        printf(" expected=%s actual=%s", [expected UTF8String], [actual UTF8String]);
    printf("\n");
    failures += !matches;
}

int main(void)
{
    @autoreleasepool
    {
        NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:3723];
        NSTimeZone *gmt = [NSTimeZone timeZoneWithName:@"GMT"];
        NSTimeZone *pacific = [NSTimeZone timeZoneWithName:@"America/Los_Angeles"];
        NSTimeZone *savedDefault = [[NSTimeZone defaultTimeZone] retain];
        if (!gmt || !pacific)
        {
            printf("FAIL required time zones unavailable\n");
            [savedDefault release];
            return 1;
        }
        @try
        {
            [NSTimeZone setDefaultTimeZone:pacific];
            NSString *format = @"%Y-%m-%d %H:%M:%S %Z";
            // Send directly to the NSDate class cluster, as Chess does. Before the
            // implementation this raises an unrecognized-selector exception.
            expectString([date descriptionWithCalendarFormat:format timeZone:gmt locale:nil],
                         @"2001-01-01 01:02:03 GMT", "explicit GMT overrides default zone");
            expectString([date descriptionWithCalendarFormat:format timeZone:pacific locale:nil],
                         @"2000-12-31 17:02:03 PST", "Pacific crosses the year boundary");
            expectString([date descriptionWithCalendarFormat:format timeZone:nil locale:nil],
                         @"2000-12-31 17:02:03 PST", "nil zone uses default");
            expectString([date descriptionWithCalendarFormat:nil timeZone:gmt locale:nil],
                         @"2001-01-01 01:02:03 +0000", "nil format uses default calendar format");
            expectString([date descriptionWithCalendarFormat:nil timeZone:nil locale:nil],
                         @"2000-12-31 17:02:03 -0800", "nil format and zone use defaults");

            NSTimeZone *india = [NSTimeZone timeZoneForSecondsFromGMT:19800];
            expectString([date descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S %z" timeZone:india locale:nil],
                         @"2001-01-01 06:32:03 +0530", "fractional hour offset");
            NSLocale *locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
            expectString([date descriptionWithCalendarFormat:@"yyyy-MM-dd HH:mm:ss Z" timeZone:gmt locale:locale],
                         @"2001-01-01 01:02:03 +0000", "NSDateFormatter path uses passed zone");

            NSCalendarDate *calendarDate = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:3723];
            [calendarDate setTimeZone:gmt];
            [calendarDate setCalendarFormat:@"%Y/%m/%d %H:%M:%S %Z"];
            expectString([calendarDate descriptionWithCalendarFormat:nil locale:nil],
                         @"2001/01/01 01:02:03 GMT", "NSCalendarDate keeps stored format and zone");
            expectString([calendarDate descriptionWithCalendarFormat:nil],
                         @"2001/01/01 01:02:03 GMT", "one argument form keeps stored settings");
            expectString([calendarDate description],
                         @"2001/01/01 01:02:03 GMT", "NSCalendarDate description keeps stored settings");
            expectString([calendarDate descriptionWithCalendarFormat:format timeZone:pacific locale:nil],
                         @"2000-12-31 17:02:03 PST", "explicit zone overrides NSCalendarDate zone");
        }
        @catch (NSException *exception)
        {
            printf("FAIL exception %s: %s\n", [[exception name] UTF8String], [[exception reason] UTF8String]);
            ++failures;
        }
        @finally
        {
            [NSTimeZone setDefaultTimeZone:savedDefault];
            [savedDefault release];
        }
    }
    printf("RESULT failures=%d\n", failures);
    return failures != 0;
}
