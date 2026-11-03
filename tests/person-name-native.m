/* The production formatter runs on Linux libobjc against controlled primitive
 * doubles. Expectations come from the authored macOS batch and Apple docs. */
static unsigned checks;
#define CHECK(c) do { ++checks; if (!(c)) { fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#c); return 1; } } while(0)
static BOOL equal(NSString *a, NSString *b) { return a == b || [a isEqual:b]; }
int main(void)
{
    Class formatterClass = objc_getClass("NSPersonNameComponentsFormatter");
    CHECK(formatterClass != Nil);
    #ifndef QV_PERSON_NAME_BASELINE
    NSPersonNameComponentsFormatter *f = [formatterClass new];
    CHECK(f.style == NSPersonNameComponentsFormatterStyleDefault && !f.isPhonetic);
    CHECK(f.locale == [NSLocale autoupdatingCurrentLocale]);
    NSPersonNameComponents *cases[7];
    for (unsigned i=0;i<7;i++) cases[i]=[NSPersonNameComponents new];
    cases[1].givenName=@"Ada";
    cases[2].givenName=@"Ada"; cases[2].familyName=@"Lovelace";
    cases[3].givenName=@"Ada"; cases[3].familyName=@"Lovelace";
    cases[3].middleName=@"Byron"; cases[3].namePrefix=@"Dr."; cases[3].nameSuffix=@"III"; cases[3].nickname=@"A";
    cases[4].givenName=@"太郎"; cases[4].familyName=@"山田";
    cases[5].givenName=@"Élodie"; cases[5].familyName=@"O’Neil";
    cases[6].givenName=@""; cases[6].familyName=@"";
    NSString *expected[7][5] = {
        {@"",@"",@"",@"",@""},
        {@"Ada",@"Ada",@"Ada",@"Ada",@"A"},
        {@"Ada Lovelace",@"Ada",@"Ada Lovelace",@"Ada Lovelace",@"AL"},
        {@"Ada Lovelace",@"A",@"Ada Lovelace",@"Dr. Ada Byron Lovelace III",@"AL"},
        {@"山田太郎",@"山田太郎",@"山田太郎",@"山田太郎",@"山田"},
        {@"Élodie O’Neil",@"Élodie",@"Élodie O’Neil",@"Élodie O’Neil",@"ÉO"},
        {@"",@"",@"",@"",@""}
    };
    for (unsigned i=0;i<7;i++) for(unsigned s=0;s<5;s++) {
        f.style=s;
        CHECK(equal([f stringFromPersonNameComponents:cases[i]],expected[i][s]));
        CHECK(equal([[f annotatedStringFromPersonNameComponents:cases[i]]string],expected[i][s]));
    }
    CHECK([f personNameComponentsFromString:@""] == nil);
    CHECK([f personNameComponentsFromString:@" \n\t "] == nil);
    NSString *inputs[] = {@"Ada Lovelace",@"Dr. Ada Byron Lovelace III",@"山田 太郎",@"Lovelace, Ada Byron",@"Ada (a.k.a. A) Lovelace"};
    for(unsigned i=0;i<5;i++) {
        NSPersonNameComponents *n=[f personNameComponentsFromString:inputs[i]];
        CHECK(equal(n.givenName,i==2?@"太郎":@"Ada"));
        CHECK(equal(n.familyName,i==2?@"山田":@"Lovelace"));
        if(i==1) {CHECK(equal(n.namePrefix,@"Dr."));CHECK(equal(n.middleName,@"Byron"));CHECK(equal(n.nameSuffix,@"III"));}
        if(i==3) CHECK(equal(n.middleName,@"Byron"));
    }
    cases[2].phoneticRepresentation=[NSPersonNameComponents new];
    cases[2].phoneticRepresentation.givenName=@"Ayda";
    cases[2].phoneticRepresentation.familyName=@"Luvlays";
    for(unsigned flag=0;flag<2;flag++) for(unsigned style=1;style<4;style++) {
        f.phonetic=flag;f.style=style;
        NSString *s=flag?(style==1?@"Ayda":@"Ayda Luvlays"):(style==1?@"Ada":@"Ada Lovelace");
        CHECK(equal([f stringFromPersonNameComponents:cases[2]],s));
    }
    f.phonetic=NO; f.style=NSPersonNameComponentsFormatterStyleLong;
    NSAttributedString *annotated=[f annotatedStringFromPersonNameComponents:cases[3]];
    unsigned indexes[]={0,3,4,7,8,13,14,23};
    NSString *keys[]={NSPersonNameComponentPrefix,NSPersonNameComponentDelimiter,NSPersonNameComponentGivenName,
        NSPersonNameComponentDelimiter,NSPersonNameComponentMiddleName,NSPersonNameComponentDelimiter,NSPersonNameComponentFamilyName,NSPersonNameComponentSuffix};
    for(unsigned i=0;i<8;i++) CHECK(equal([annotated attribute:NSPersonNameComponentKey atIndex:indexes[i] effectiveRange:NULL],keys[i]));
    CHECK([f stringForObjectValue:@"wrong type"] == nil);
    CHECK(equal([f stringForObjectValue:cases[2]],@"Ada Lovelace"));
    id parsed=nil; NSString *error=nil;
    CHECK([f getObjectValue:&parsed forString:@"Ada Lovelace" errorDescription:&error] && parsed);
    CHECK(![f getObjectValue:&parsed forString:@"" errorDescription:&error] && parsed==nil && error);
    f.locale=[NSLocale new];NSPersonNameComponentsFormatter *copy=[f copy];
    CHECK(copy!=f && copy.style==f.style && copy.locale==f.locale);
    copy.style=NSPersonNameComponentsFormatterStyleAbbreviated;
    CHECK(f.style==NSPersonNameComponentsFormatterStyleLong);
    f.locale=nil;CHECK(f.locale==[NSLocale autoupdatingCurrentLocale]);
    for(unsigned keyed=0;keyed<2;keyed++) {
        f.phonetic=YES;f.style=NSPersonNameComponentsFormatterStyleShort;
        NSCoder *coder=[NSCoder new];coder->keyed=keyed;[f encodeWithCoder:coder];
        NSPersonNameComponentsFormatter *decoded=[[formatterClass alloc]initWithCoder:coder];
        CHECK(decoded.style==f.style && decoded.phonetic==f.phonetic && decoded.locale==f.locale);
        CHECK(equal([decoded stringFromPersonNameComponents:cases[2]],@"Ayda"));
    }
    CHECK(equal([formatterClass localizedStringFromPersonNameComponents:cases[2] style:NSPersonNameComponentsFormatterStyleMedium options:NSPersonNameComponentsFormatterPhonetic],@"Ayda Luvlays"));
    // Composed letter units remain intact in monograms.
    NSPersonNameComponents *accent=[NSPersonNameComponents new];accent.givenName=@"E\u0301lodie";accent.familyName=@"O’Neil";
    f.phonetic=NO;f.style=NSPersonNameComponentsFormatterStyleAbbreviated;
    CHECK(equal([f stringFromPersonNameComponents:accent],@"E\u0301O"));
    BOOL raised=NO;@try{[f stringFromPersonNameComponents:nil];}@catch(id e){raised=YES;}
    CHECK(raised);
    printf("PASS person-name production formatter: %u assertions\n",checks);
    #endif
    return 0;
}
