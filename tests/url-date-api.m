/* Public API regression, also runnable as an authored qv-diff check. */
#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdio.h>
#include <limits.h>

int main(void) {
    @autoreleasepool {
        NSArray *strings = @[@"https://user:pw@example.com:8443/a%20b/c.txt?q=a%2Bb#frag",
            @"https://example.com", @"file:///tmp/a%20b", @"../x?y#z",
            @"https://[::1]:80/a", @"mailto:a@example.com", @"https://example.com/?a=&a&b=2"];
        NSArray *paths = @[@"/a%20b/c.txt", @"", @"/tmp/a%20b", @"../x", @"/a", @"a@example.com", @"/"];
        for (NSUInteger i = 0; i < strings.count; i++) {
            NSURLComponents *c = [NSURLComponents componentsWithString:strings[i]];
            assert([c.percentEncodedPath isEqual:paths[i]]);
            assert([c.string isEqual:strings[i]]);
        }
        NSURLComponents *c = [NSURLComponents componentsWithString:strings[0]];
        assert([c.query isEqual:@"q=a+b"] && [c.fragment isEqual:@"frag"]);
        c.query = @"é=a+b c";
        c.fragment = @"é #";
        assert([c.query isEqual:@"é=a+b c"] && [c.fragment isEqual:@"é #"]);
        c.query = nil; c.fragment = nil;
        assert(!c.query && !c.fragment);
        c.percentEncodedPath = @"/a%2Fb";
        assert([c.percentEncodedPath isEqual:@"/a%2Fb"]);
        BOOL raised = NO;
        @try { c.percentEncodedPath = @"%zz"; }
        @catch (NSException *e) { raised = [e.name isEqual:NSInvalidArgumentException]; }
        assert(raised && [c.percentEncodedPath isEqual:@"/a%2Fb"]);
        c = [NSURLComponents componentsWithString:@"https://example.com/"];
        c.queryItems = @[[NSURLQueryItem queryItemWithName:@"a" value:nil],
            [NSURLQueryItem queryItemWithName:@"b" value:@""],
            [NSURLQueryItem queryItemWithName:@"é" value:@"a+b c"]];
        assert([c.string isEqual:@"https://example.com/?a&b=&%C3%A9=a+b%20c"]);
        assert(c.queryItems.count == 3 && [c.queryItems[0] value] == nil && [[c.queryItems[1] value] isEqual:@""]);
        c.queryItems = @[]; assert([c.query isEqual:@""]);
        c.queryItems = nil; assert(!c.query);
        puts("NSURLComponents: PASS");

        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        [calendar setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        double epochs[] = {-2208988800,-1,0,951782400,1609459200,1640995200,2147483647};
        double starts[] = {-2208988800,-86400,0,951782400,1609459200,1640995200,2147472000};
        double months[] = {-2206310400,2678399,2678400,954288000,1612137600,1643673600,2150162047};
        for (int i = 0; i < 7; i++) {
            NSDate *d = [NSDate dateWithTimeIntervalSince1970:epochs[i]];
            assert([[calendar startOfDayForDate:d] timeIntervalSince1970] == starts[i]);
            assert([[calendar dateByAddingUnit:NSCalendarUnitMonth value:1 toDate:d options:0] timeIntervalSince1970] == months[i]);
        }
        [calendar setTimeZone:[NSTimeZone timeZoneWithName:@"America/Havana"]];
        assert([[calendar startOfDayForDate:[NSDate dateWithTimeIntervalSince1970:1446397200]] timeIntervalSince1970] == 1446350400);
        [calendar setTimeZone:[NSTimeZone timeZoneWithName:@"America/Sao_Paulo"]];
        assert([[calendar startOfDayForDate:[NSDate dateWithTimeIntervalSince1970:1541340000]] timeIntervalSince1970] == 1541300400);
        [calendar setTimeZone:[NSTimeZone timeZoneWithName:@"America/New_York"]];
        double dstInputs[] = {1615654800,1636214400}; // Noon before spring/fall transitions.
        double dstLengths[] = {23*3600,25*3600};
        for (int i = 0; i < 2; i++) {
            NSDate *d = [NSDate dateWithTimeIntervalSince1970:dstInputs[i]];
            NSDate *next = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:d options:0];
            assert([next timeIntervalSinceDate:d] == dstLengths[i]);
            assert([calendar component:NSCalendarUnitHour fromDate:next] == 12);
        }
        [calendar setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        assert([[calendar dateByAddingUnit:NSCalendarUnitMonth value:1 toDate:[NSDate dateWithTimeIntervalSince1970:1612094400] options:0] timeIntervalSince1970] == 1614513600);
        NSDateComponents *parts = [[NSDateComponents alloc] init];
        assert(![parts isValidDate]);
        NSCalendarUnit units[] = {NSCalendarUnitEra,NSCalendarUnitYear,NSCalendarUnitMonth,NSCalendarUnitDay,
            NSCalendarUnitHour,NSCalendarUnitMinute,NSCalendarUnitSecond,NSCalendarUnitWeekday,NSCalendarUnitWeekdayOrdinal,
            NSCalendarUnitQuarter,NSCalendarUnitWeekOfMonth,NSCalendarUnitWeekOfYear,NSCalendarUnitYearForWeekOfYear,NSCalendarUnitNanosecond};
        for (int i = 0; i < 14; i++) {
            assert([parts valueForComponent:units[i]] == NSDateComponentUndefined);
            [parts setValue:2 forComponent:units[i]];
            assert([parts valueForComponent:units[i]] == 2);
            [parts setValue:NSDateComponentUndefined forComponent:units[i]];
            assert([parts valueForComponent:units[i]] == NSDateComponentUndefined);
        }
        [parts setCalendar:calendar];
        int dates[][4] = {{2000,2,29,1},{1900,2,29,0},{2020,2,30,0},{2021,13,1,0},{2021,0,1,0},{2021,1,-1,0}};
        for (int i = 0; i < 6; i++) {
            [parts setYear:dates[i][0]]; [parts setMonth:dates[i][1]]; [parts setDay:dates[i][2]];
            assert([parts isValidDate] == dates[i][3]);
        }
        [parts setYear:2020]; [parts setMonth:2]; [parts setDay:29];
        if (sizeof(NSInteger) > sizeof(int)) {
            [parts setNanosecond:INT_MAX];
            assert([parts valueForComponent:NSCalendarUnitNanosecond] == INT_MAX && ![parts isValidDate]);
        }
        [parts setValue:NSDateComponentUndefined forComponent:NSCalendarUnitDay];
        assert([parts day] == NSDateComponentUndefined);
        [parts setDay:NSDateComponentUndefined];
        assert([parts valueForComponent:NSCalendarUnitDay] == NSDateComponentUndefined);
        if (sizeof(NSInteger) > sizeof(int)) {
            [parts setDay:INT_MAX]; assert([parts valueForComponent:NSCalendarUnitDay] == INT_MAX);
            [parts setValue:INT_MAX forComponent:NSCalendarUnitDay]; assert([parts day] == INT_MAX);
            [parts setValue:(NSInteger)INT_MAX + 1 forComponent:NSCalendarUnitDay];
            assert([parts day] == (NSInteger)INT_MAX + 1 && ![parts isValidDate]);
        }
        [parts setDay:29];
        [parts setNanosecond:999999999]; assert([parts isValidDate] && [parts nanosecond] == 999999999);
        [parts setNanosecond:1000000000]; assert(![parts isValidDate]);
        [parts setNanosecond:0]; [parts setHour:24]; assert(![parts isValidDate]);
        [parts setHour:0]; [parts setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:7200]];
        assert([parts isValidDate] && [[calendar timeZone] secondsFromGMT] == 0);
        puts("NSCalendar/NSDateComponents: PASS");
    }
    return 0;
}
