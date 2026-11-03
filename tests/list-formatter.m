/* Public API regression; run against macOS or a committed Darling build.
 * clang -framework Foundation tests/list-formatter.m -o list-formatter */
#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdio.h>

@interface ListLocaleItem : NSObject @end
@implementation ListLocaleItem
- (NSString *)descriptionWithLocale:(id)locale { return [locale localeIdentifier]; }
- (NSString *)description { return @"wrong fallback"; }
@end
@interface ListLocalizedItem : NSObject @end
@implementation ListLocalizedItem
- (NSString *)localizedDescription { return @"localized"; }
- (NSString *)description { return @"wrong fallback"; }
@end
@interface ListUndescribableItem : NSObject @end
@implementation ListUndescribableItem
- (NSString *)description { return nil; }
@end
@interface ListItemFormatter : NSFormatter @end
@implementation ListItemFormatter
- (NSString *)stringForObjectValue:(id)value { return [value isKindOfClass:[NSString class]] ? @"formatted" : nil; }
@end

int main(void) { @autoreleasepool {
    NSListFormatter *f = [NSListFormatter new];
    assert((f.locale != nil && f.itemFormatter == nil));
    f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    assert(([[f stringFromItems:@[]] isEqualToString:@""]));
    assert(([[f stringFromItems:@[@"a", @"b", @"c"]] isEqualToString:@"a, b, and c"]));
    assert(([[f stringForObjectValue:@[@"a", @"b"]] isEqualToString:@"a and b"]));
    assert(([f stringFromItems:nil] == nil));
    assert(([f stringForObjectValue:@"a"] == nil));
    f.itemFormatter = [ListItemFormatter new];
    assert(([[f stringFromItems:@[@"a", [ListLocaleItem new], [ListLocalizedItem new]]]
            isEqualToString:@"formatted, en_US_POSIX, and localized"]));
    assert(([f stringFromItems:@[[ListUndescribableItem new]]] == nil));
    f.itemFormatter = nil;
    NSListFormatter *copy = [f copy];
    assert((copy == f));
    f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"ja_JP"];
    assert(([[f stringFromItems:@[@"a", @"b"]] isEqualToString:@"a、b"]));
    assert(([[copy.locale localeIdentifier] isEqualToString:@"ja_JP"]));
    assert(([[copy stringFromItems:@[@"a", @"b"]] isEqualToString:@"a、b"]));
    copy.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"fr_FR"];
    assert(([[f.locale localeIdentifier] isEqualToString:@"fr_FR"]));
    assert(([[f stringFromItems:@[@"a", @"b"]] isEqualToString:@"a et b"]));
    f.itemFormatter = [ListItemFormatter new];
    assert((copy.itemFormatter == f.itemFormatter));
    assert(([[copy stringFromItems:@[@"a", @"b"]] isEqualToString:@"formatted et formatted"]));
    copy.itemFormatter = nil;
    assert((f.itemFormatter == nil));
    f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"ar_EG"];
    assert(([[f stringFromItems:@[@"a", @"😀", @"b"]] isEqualToString:@"\u2068a\u2069 و😀 و\u2068b\u2069"]));
    f.locale = nil;
    assert(([f.locale.localeIdentifier isEqualToString:[[NSLocale autoupdatingCurrentLocale] localeIdentifier]]));
    assert(([[NSListFormatter localizedStringByJoiningStrings:@[@"a", @"b"]]
            isEqualToString:[f stringFromItems:@[@"a", @"b"]]]));
    puts("NSListFormatter.publicAPI: PASS");
} return 0; }
