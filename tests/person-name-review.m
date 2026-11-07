#import <Foundation/Foundation.h>
#include <stdio.h>
static const char *value(NSString *s) { return s ? [s UTF8String] : "<nil>"; }
static int reviewCases(void) {
    NSPersonNameComponentsFormatter *f=[NSPersonNameComponentsFormatter new];
    f.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    NSString *names[] = {@"John Paul Appleseed", @"José Ramiro Martín González de Rivera", @"Appleseed Jonathan", @"APPLESEED Jonathan", @"Jean-Philippe de Zélicourt", @"Dr. Jonathan, Esq."};
    for (unsigned i=0;i<sizeof(names)/sizeof(names[0]);i++) {
        NSPersonNameComponents *c=[f personNameComponentsFromString:names[i]];
        printf("parse(%s): given=%s; middle=%s; family=%s; prefix=%s; suffix=%s\n", value(names[i]),value(c.givenName),value(c.middleName),value(c.familyName),value(c.namePrefix),value(c.nameSuffix));
    }
    return 0;
}
int main(void) { @autoreleasepool { return reviewCases(); } }
