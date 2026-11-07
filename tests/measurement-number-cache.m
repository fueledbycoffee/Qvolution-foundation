#import <Foundation/Foundation.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
 NSMeasurementFormatter *f=[NSMeasurementFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US"];
 f.unitOptions=NSMeasurementFormatterUnitOptionsProvidedUnit;f.unitStyle=NSFormattingUnitStyleLong;
 NSMeasurement *m=[[NSMeasurement alloc] initWithDoubleValue:1.1 unit:[NSUnitLength meters]];
 #define SHOW(label) printf(label ": %s\n",[f stringFromMeasurement:m].UTF8String);fflush(stdout)
 SHOW("initial");
 f.numberFormatter.minimumFractionDigits=2;f.numberFormatter.maximumFractionDigits=2;
 SHOW("mutated");
 f.unitStyle=NSFormattingUnitStyleMedium;SHOW("style");
 f.unitStyle=NSFormattingUnitStyleLong;SHOW("styleBack");
 f.unitOptions=0;SHOW("options");
 f.unitOptions=NSMeasurementFormatterUnitOptionsProvidedUnit;SHOW("optionsBack");
 NSNumberFormatter *nf=[f.numberFormatter copy];
 f.numberFormatter=nf;SHOW("newNumberFormatter");
 printf("setter.identity: %d\n",nf==f.numberFormatter);
 nf.maximumFractionDigits=0;nf.minimumFractionDigits=0;
 SHOW("setterSourceMutation");
 f.numberFormatter=nf;SHOW("sameNumberFormatter");
 f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US"];SHOW("sameLocale");
 f.locale=[NSLocale localeWithLocaleIdentifier:@"fr_FR"];SHOW("newLocale");
 f.numberFormatter=nil;SHOW("nilNumberFormatter");
} }
