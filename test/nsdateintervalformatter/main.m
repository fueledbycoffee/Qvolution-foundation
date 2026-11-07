#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

#if __has_feature(objc_arc)
#define RELEASE(object) ((void)0)
#else
#define RELEASE(object) [(object) release]
#endif
static int failures;
static void expect(BOOL ok, const char *label)
{
    if (!ok) { fprintf(stderr, "FAIL: %s\n", label); failures++; }
}
static void same(NSString *actual, NSString *expected, const char *label)
{
    if (![actual isEqualToString:expected]) {
        fprintf(stderr,"FAIL: %s expected=%s actual=%s\n",label,[expected UTF8String],[actual UTF8String]);
        failures++;
    }
}
static NSCalendar *calendar(void)
{
    NSCalendar *c=[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    c.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    c.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];
    return c;
}
static void copyZones(void)
{
    for (NSTimeZone *zone in @[[NSTimeZone timeZoneForSecondsFromGMT:0],
                               [NSTimeZone timeZoneForSecondsFromGMT:7200],
                               [NSTimeZone timeZoneWithName:@"Europe/Paris"]]) {
        NSTimeZone *copy=[zone copy];
        expect([copy isEqual:zone],"time zone copying");
        same(copy.name,zone.name,"copy keeps zone name");
        RELEASE(copy);
    }
}
static void components(void)
{
    NSArray *zero=@[@"00:00:01",@"0h 0m 1s",@"0 hr, 0 min, 1 sec",
                    @"0 hours, 0 minutes, 1 second",@"zero hours, zero minutes, one second",@"0hr 0min 1sec"];
    NSArray *negative=@[@"-01:01:01",@"-1h 1m 1s",@"-1 hr, 1 min, 1 sec",
                        @"-1 hour, 1 minute, 1 second",@"minus one hour, one minute, one second",@"-1hr 1min 1sec"];
    for (NSInteger style=0;style<6;style++) {
        NSDateComponentsFormatter *f=[NSDateComponentsFormatter new];
        f.calendar=calendar(); f.allowedUnits=NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond;
        f.unitsStyle=style; f.zeroFormattingBehavior=NSDateComponentsFormatterZeroFormattingBehaviorPad;
        same([f stringFromTimeInterval:-1],zero[style],"negative zero leading unit");
        same([f stringFromTimeInterval:-3661],negative[style],"negative nonzero leading unit");
        same([f stringFromTimeInterval:1],zero[style],"positive control");
        if (style==0) {
            f.zeroFormattingBehavior=NSDateComponentsFormatterZeroFormattingBehaviorDefault;
            same([f stringFromTimeInterval:-1],@"-1","negative seconds without leading clock field");
            same([f stringFromTimeInterval:1],@"1","positive seconds drop leading clock field");
            same([f stringFromTimeInterval:0],@"0","zero seconds drop leading clock fields");
        }
        RELEASE(f);
    }
}
static void intervals(void)
{
    NSDate *start=[NSDate dateWithTimeIntervalSince1970:1609459200];
    NSDate *minute=[start dateByAddingTimeInterval:60];
    NSDate *day=[start dateByAddingTimeInterval:86400];
    NSDateIntervalFormatter *f=[NSDateIntervalFormatter new];
    expect(f.dateStyle==1 && f.timeStyle==1,"default styles");
    expect(f.locale!=nil && f.calendar!=nil && f.timeZone!=nil,"default locale calendar time zone");
    f.locale=calendar().locale; f.calendar=calendar(); f.timeZone=calendar().timeZone;
    f.dateStyle=NSDateIntervalFormatterMediumStyle; f.timeStyle=NSDateIntervalFormatterShortStyle;
    same([f stringFromDate:start toDate:minute],@"Jan 1, 2021, 12:00\u2009–\u200912:01 AM","same-day minimization");
    same([f stringFromDate:start toDate:start],@"Jan 1, 2021, 12:00 AM","equal endpoints");
    same([f stringFromDate:start toDate:day],@"Jan 1, 2021, 12:00 AM\u2009–\u2009Jan 2, 2021, 12:00 AM","cross-day interval");
    same([f stringFromDate:start toDate:[start dateByAddingTimeInterval:-3600]],@"Jan 1, 2021, 12:00 AM\u2009–\u2009Dec 31, 2020, 11:00 PM","endpoint order");
    f.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"fr_FR"];
    same([f stringFromDate:start toDate:minute],@"1 janv. 2021 à 00:00\u2009–\u200900:01","locale invalidates ICU formatter");
    f.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"ja_JP"];
    same([f stringFromDate:start toDate:minute],@"2021/01/01 0時00分～0時01分","Japanese interval pattern");
    f.locale=calendar().locale; f.dateTemplate=@"yMMMd";
    same([f stringFromDate:start toDate:day],@"Jan 1\u2009–\u20092, 2021","custom template");
    f.dateTemplate=@"";
    same([f stringFromDate:start toDate:day],@"","empty template");
    f.dateStyle=NSDateIntervalFormatterMediumStyle;
    same([f stringFromDate:start toDate:minute],@"Jan 1, 2021, 12:00\u2009–\u200912:01 AM","style replaces template");
    NSDateIntervalFormatter *copy=[f copy];
    expect(copy!=f,"formatter copy is independent");
    f.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:7200];
    same([f stringFromDate:start toDate:start],@"Jan 1, 2021, 2:00 AM","time zone invalidates ICU formatter");
    same([copy stringFromDate:start toDate:minute],@"Jan 1, 2021, 12:00\u2009–\u200912:01 AM","copy retains prior settings");
    NSDateInterval *interval=[[NSDateInterval alloc] initWithStartDate:start endDate:minute];
    same([copy stringFromDateInterval:interval],[copy stringFromDate:start toDate:minute],"date interval entry point");
    same([copy stringForObjectValue:interval],[copy stringFromDate:start toDate:minute],"formatter entry point");
    copy.dateStyle=0; copy.timeStyle=0;
    same([copy stringFromDate:start toDate:day],@"","no styles");
    RELEASE(copy); RELEASE(f);
}
int main(void)
{
    @autoreleasepool {
        @try { copyZones(); } @catch (NSException *e) { expect(NO,"time zone copy raised"); }
        @try { components(); } @catch (NSException *e) { expect(NO,"components raised"); }
        @try { intervals(); } @catch (NSException *e) { expect(NO,"interval formatter raised"); }
        if (failures==0) puts("PASS: time zone copying, component signs, localized date intervals and cache invalidation");
    }
    return failures ? EXIT_FAILURE : EXIT_SUCCESS;
}
