/* Rung 4: the authored Foundation2 macOS comparison; rung 3: Apple's
 * personNameComponents(from:) examples, exercised through the public API. */
#import <Foundation/Foundation.h>
#include <stdio.h>
static unsigned checks;
#define CHECK(c) do { ++checks; if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)
int main(void) { @autoreleasepool {
    Class cls = NSClassFromString(@"NSPersonNameComponentsFormatter");
    CHECK(cls != Nil);
    NSPersonNameComponentsFormatter *f = [cls new];
    f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    NSPersonNameComponents *n = [NSPersonNameComponents new];
    n.givenName = @"Ada"; n.familyName = @"Lovelace";
    n.middleName = @"Byron"; n.namePrefix = @"Dr."; n.nameSuffix = @"III"; n.nickname = @"A";
    NSArray *strings = @[@"Ada Lovelace", @"A", @"Ada Lovelace", @"Dr. Ada Byron Lovelace III", @"AL"];
    for (NSUInteger style = 0; style < strings.count; ++style) {
        f.style = style;
        CHECK([[f stringFromPersonNameComponents:n] isEqual:strings[style]]);
        CHECK([[[f annotatedStringFromPersonNameComponents:n] string] isEqual:strings[style]]);
    }
    f.style = NSPersonNameComponentsFormatterStyleLong;
    NSAttributedString *a = [f annotatedStringFromPersonNameComponents:n];
    CHECK([[a attribute:NSPersonNameComponentKey atIndex:0 effectiveRange:NULL] isEqual:NSPersonNameComponentPrefix]);
    CHECK([[a attribute:NSPersonNameComponentKey atIndex:4 effectiveRange:NULL] isEqual:NSPersonNameComponentGivenName]);
    n.phoneticRepresentation = [NSPersonNameComponents new];
    n.phoneticRepresentation.givenName = @"Ayda";
    n.phoneticRepresentation.familyName = @"Luvlays";
    f.phonetic = YES; f.style = NSPersonNameComponentsFormatterStyleMedium;
    CHECK([[f stringFromPersonNameComponents:n] isEqual:@"Ayda Luvlays"]);
    f.phonetic = NO;
    NSPersonNameComponents *parsed = [f personNameComponentsFromString:@"Jean-Philippe de Zélicourt"];
    CHECK([parsed.givenName isEqual:@"Jean-Philippe"] && [parsed.familyName isEqual:@"de Zélicourt"]);
    parsed = [f personNameComponentsFromString:@"Jonathan (a.k.a. Johnny) Appleseed 🍎"];
    CHECK([parsed.givenName isEqual:@"Jonathan"] && [parsed.familyName isEqual:@"Appleseed"]);
    parsed = [f personNameComponentsFromString:@"Dr. Jonathan, Esq."];
    CHECK([parsed.givenName isEqual:@"Jonathan"] && parsed.familyName == nil);
    CHECK([parsed.namePrefix isEqual:@"Dr."] && [parsed.nameSuffix isEqual:@"Esq."]);
    CHECK([f personNameComponentsFromString:@""] == nil);
    n = [NSPersonNameComponents new]; n.familyName = @"山田"; n.givenName = @"太郎";
    CHECK([[f stringFromPersonNameComponents:n] isEqual:@"山田太郎"]);
    f.style = NSPersonNameComponentsFormatterStyleAbbreviated;
    CHECK([[f stringFromPersonNameComponents:n] isEqual:@"山田"]);
    printf("PASS person-name public API: %u assertions\n", checks);
} return 0; }
