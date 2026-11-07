/* Rung 3: Apple's Latin component/inversion parsing contract.
 * Rung 4: macOS 12.7.6, parser-probe.m and parser-probe-extra.m in lane
 * g11-foundation2-2; includes every rev-g11-b person-contract.m input.
 * Population priors are independently derived; see person-name-parsing.md. */
#ifndef QV_PERSON_NAME_NATIVE
#import <Foundation/Foundation.h>
#endif
#include <stdio.h>
static BOOL parsingEqual(NSString *a, NSString *b) { return a == b || [a isEqual:b]; }
static const char *parsingValue(NSString *s) { return s ? [s UTF8String] : "<nil>"; }
static int parsingContract(void)
{
    NSPersonNameComponentsFormatter *f = [NSPersonNameComponentsFormatter new];
    f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    struct { NSString *input, *given, *middle, *family; } cases[] = {
        {@"John Paul Appleseed", @"John Paul", nil, @"Appleseed"},
        {@"Jonathan Paul Appleseed", @"Jonathan", @"Paul", @"Appleseed"},
        {@"John James Appleseed", @"John James", nil, @"Appleseed"},
        {@"John Peter Appleseed", @"John", @"Peter", @"Appleseed"},
        {@"James Paul Appleseed", @"James", @"Paul", @"Appleseed"},
        {@"Jean Paul Appleseed", @"Jean Paul", nil, @"Appleseed"},
        {@"Anne Marie Appleseed", @"Anne Marie", nil, @"Appleseed"},
        {@"Mary Jane Appleseed", @"Mary Jane", nil, @"Appleseed"},
        {@"Mary Ann Smith", @"Mary Ann", nil, @"Smith"},
        {@"John Paul Smith", @"John Paul", nil, @"Smith"},
        {@"John Paul Jones", @"John Paul", nil, @"Jones"},
        {@"John Paul", @"John Paul", nil, nil},
        {@"Smith Jonathan", @"Jonathan", nil, @"Smith"},
        {@"Lovelace Ada", @"Ada", nil, @"Lovelace"},
        {@"Jones Michael", @"Michael", nil, @"Jones"},
        {@"Frobnitz Zachary", @"Zachary", nil, @"Frobnitz"},
        {@"Doe John", @"John", nil, @"Doe"},
        {@"Paul John", @"Paul", nil, @"John"},
        {@"John Paul Xavier Appleseed", @"John Paul", @"Xavier", @"Appleseed"},
        {@"José Ramiro Martín González de Rivera", @"José", @"Ramiro", @"Martín González de Rivera"},
        {@"José Ramiro García López de Rivera", @"José", @"Ramiro", @"García López de Rivera"},
        {@"José Antonio García López", @"José", @"Antonio", @"García López"},
        {@"Miguel Ramiro Martín González de Rivera", @"Miguel", @"Ramiro", @"Martín González de Rivera"},
        {@"José Ramiro Martín González", @"José", @"Ramiro", @"Martín González"},
        {@"José Ramiro Martín", @"José", @"Ramiro", @"Martín"},
        {@"José Ramiro de Rivera", @"José", @"Ramiro", @"de Rivera"},
        {@"Jonathan Paul Martín González de Rivera", @"Jonathan", @"Paul", @"Martín González de Rivera"},
        {@"Ada Byron Martín González de Rivera", @"Ada", @"Byron", @"Martín González de Rivera"},
        {@"Anne Marie de Vries", @"Anne Marie", nil, @"de Vries"},
        {@"John Paul de Vries", @"John Paul", nil, @"de Vries"},
        {@"García José", @"José", nil, @"García"},
        {@"González José", @"José", nil, @"González"},
        {@"Martín González de Rivera, José Ramiro", @"José", @"Ramiro", @"Martín González de Rivera"},
        {@"John Paul Smith Jones", @"John Paul", nil, @"Smith Jones"},
        {@"John Paul Martin de Vries", @"John Paul", nil, @"Martin de Vries"},
        {@"José Ramiro Smith Jones de Rivera", @"José", @"Ramiro", @"Smith Jones de Rivera"},
        {@"John Michael Smith", @"John Michael", nil, @"Smith"},
        {@"John Patrick Smith", @"John", @"Patrick", @"Smith"},
        {@"John Charles Smith", @"John", @"Charles", @"Smith"},
        {@"John David Smith", @"John", @"David", @"Smith"},
        {@"John James Smith", @"John James", nil, @"Smith"},
        {@"John Peter Smith", @"John", @"Peter", @"Smith"},
        {@"Jean Claude Smith", @"Jean Claude", nil, @"Smith"},
        {@"Jean Luc Smith", @"Jean Luc", nil, @"Smith"},
        {@"Anne Marie Smith", @"Anne Marie", nil, @"Smith"},
        {@"Anna Maria Smith", @"Anna Maria", nil, @"Smith"},
        {@"Ana Maria Smith", @"Ana Maria", nil, @"Smith"},
        {@"Juan Carlos Smith", @"Juan Carlos", nil, @"Smith"},
        {@"José María Smith", @"José", @"María", @"Smith"},
        {@"José Antonio Smith", @"José", @"Antonio", @"Smith"},
        {@"Mary Ellen Smith", @"Mary", @"Ellen", @"Smith"},
        {@"Mary Beth Smith", @"Mary", @"Beth", @"Smith"},
        {@"Sarah Jane Smith", @"Sarah Jane", nil, @"Smith"},
        {@"Smith, John Paul", @"John Paul", nil, @"Smith"},
        {@"de Vries, Anne Marie", @"Anne Marie", nil, @"de Vries"},
        {@"Martín Ramiro", @"Ramiro", nil, @"Martín"},
        {@"Jonathan Smith Jones", @"Jonathan", nil, @"Smith Jones"},
        {@"José García López", @"José", nil, @"García López"},
        {@"Lovelace Ada Byron", @"Ada", @"Byron", @"Lovelace"},
        {@"Smith Michael James", @"Michael James", nil, @"Smith"},
        {@"Doe John Paul", @"John Paul", nil, @"Doe"},
        {@"APPLESEED John Paul", @"John Paul", nil, @"APPLESEED"},
        {@"John Paul APPLESEED", @"John Paul", nil, @"APPLESEED"},
        {@"john paul smith", @"john paul", nil, @"smith"},
        {@"Appleseed Jonathan", @"Jonathan", nil, @"Appleseed"},
        {@"APPLESEED Jonathan", @"Jonathan", nil, @"APPLESEED"},
        {@"Jean-Philippe de Zélicourt", @"Jean-Philippe", nil, @"de Zélicourt"},
        {@"Dr. Jonathan, Esq.", @"Jonathan", nil, nil},
    };
    unsigned failures = 0;
    for (unsigned i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i)
    {
        NSPersonNameComponents *c = [f personNameComponentsFromString:cases[i].input];
        BOOL match = c && parsingEqual(c.givenName, cases[i].given)
            && parsingEqual(c.middleName, cases[i].middle) && parsingEqual(c.familyName, cases[i].family);
        if (i == sizeof(cases) / sizeof(cases[0]) - 1)
            match = match && parsingEqual(c.namePrefix, @"Dr.") && parsingEqual(c.nameSuffix, @"Esq.");
        else match = match && !c.namePrefix && !c.nameSuffix;
        printf("parse(%s): given=%s; middle=%s; family=%s; prefix=%s; suffix=%s\n",
            parsingValue(cases[i].input), parsingValue(c.givenName), parsingValue(c.middleName),
            parsingValue(c.familyName), parsingValue(c.namePrefix), parsingValue(c.nameSuffix));
        if (!match) { fprintf(stderr, "FAIL parsing case %u\n", i); ++failures; }
    }
    printf("Latin parsing contract: %u cases, %u failures\n", (unsigned)(sizeof(cases) / sizeof(cases[0])), failures);
    return failures ? 1 : 0;
}
int main(void)
{
#ifdef QV_PERSON_NAME_NATIVE
    return parsingContract();
#else
    @autoreleasepool { return parsingContract(); }
#endif
}
