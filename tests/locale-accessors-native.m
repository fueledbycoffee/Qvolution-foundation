/* Linux libobjc fixture: actual production accessor methods, controlled locale
 * primitives. This tests dispatch and return semantics, not ICU locale data. */
#include <objc/runtime.h>
#include <objc/message.h>
#include <stdio.h>
#include <stdint.h>
#include <assert.h>

__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)new;
@end
@implementation NSObject
+ (id)new { return class_createInstance(self, 0); }
@end
@interface NSString : NSObject @end
@implementation NSString @end
@interface NSNumber : NSObject { @public BOOL value; }
- (BOOL)boolValue;
@end
@implementation NSNumber
- (BOOL)boolValue { return value; }
@end

static id NSLocaleCountryCode, NSLocaleScriptCode, NSLocaleDecimalSeparator;
static id NSLocaleGroupingSeparator, NSLocaleCurrencyCode, NSLocaleCurrencySymbol;
static id NSLocaleUsesMetricSystem, NSLocaleLanguageCode;

@interface NSLocale : NSObject {
@public id expectedKey, result, seenValue;
    unsigned primitiveCalls;
}
- (id)objectForKey:(id)key;
- (NSString *)displayNameForKey:(id)key value:(id)value;
@end
@implementation NSLocale
- (id)objectForKey:(id)key {
    assert(key == expectedKey);
    ++primitiveCalls;
    return result;
}
- (NSString *)displayNameForKey:(id)key value:(id)value {
    assert(key == NSLocaleLanguageCode);
    ++primitiveCalls;
    seenValue = value;
    return result;
}
@end

@interface NSLocale (Accessors)
- (NSString *)countryCode;
- (NSString *)scriptCode;
- (NSString *)decimalSeparator;
- (NSString *)groupingSeparator;
- (NSString *)currencyCode;
- (NSString *)currencySymbol;
- (BOOL)usesMetricSystem;
- (NSString *)localizedStringForLanguageCode:(NSString *)code;
@end
@implementation NSLocale (Accessors)
PRODUCTION_METHODS
@end

static unsigned failures;
static BOOL available(SEL selector) {
    if (class_getInstanceMethod(objc_getClass("NSLocale"), selector)) return YES;
    ++failures;
    printf("FAIL missing %s\n", sel_getName(selector));
    return NO;
}
int main(void) {
    NSLocaleCountryCode = [NSObject new]; NSLocaleScriptCode = [NSObject new];
    NSLocaleDecimalSeparator = [NSObject new]; NSLocaleGroupingSeparator = [NSObject new];
    NSLocaleCurrencyCode = [NSObject new]; NSLocaleCurrencySymbol = [NSObject new];
    NSLocaleUsesMetricSystem = [NSObject new]; NSLocaleLanguageCode = [NSObject new];
    NSLocale *locale = [NSLocale new];
    id first = [NSString new], second = [NSString new];
    struct { const char *selector; id key; } accessors[] = {
        {"countryCode", NSLocaleCountryCode}, {"scriptCode", NSLocaleScriptCode},
        {"decimalSeparator", NSLocaleDecimalSeparator}, {"groupingSeparator", NSLocaleGroupingSeparator},
        {"currencyCode", NSLocaleCurrencyCode}, {"currencySymbol", NSLocaleCurrencySymbol}
    };
    for (unsigned i = 0; i < sizeof(accessors)/sizeof(accessors[0]); ++i) {
        SEL selector = sel_registerName(accessors[i].selector);
        if (!available(selector)) continue;
        locale->expectedKey = accessors[i].key;
        id (*call)(id, SEL) = (void *)objc_msg_lookup(locale, selector);
        id values[] = {first, nil, second};
        for (unsigned j = 0; j < 3; ++j) {
            locale->result = values[j]; unsigned before = locale->primitiveCalls;
            assert(call(locale, selector) == values[j]);
            assert(locale->primitiveCalls == before + 1);
        }
    }
    if (available(@selector(usesMetricSystem))) {
        locale->expectedKey = NSLocaleUsesMetricSystem;
        NSNumber *number = [NSNumber new]; locale->result = number;
        number->value = NO; assert([locale usesMetricSystem] == NO);
        number->value = YES; assert([locale usesMetricSystem] == YES);
        locale->result = nil; assert([locale usesMetricSystem] == NO);
    }
    if (available(@selector(localizedStringForLanguageCode:))) {
        locale->result = second;
        assert([locale localizedStringForLanguageCode:first] == second);
        assert(locale->seenValue == first);
        locale->result = nil;
        assert([locale localizedStringForLanguageCode:second] == nil);
        assert(locale->seenValue == second);
    }
    printf("locale-accessors-native: %u failures\n", failures);
    return failures ? 1 : 0;
}
