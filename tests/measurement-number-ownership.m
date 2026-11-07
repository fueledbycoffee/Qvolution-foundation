#import <Foundation/Foundation.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
 NSMeasurementFormatter *f=[NSMeasurementFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US"];
 f.unitOptions=NSMeasurementFormatterUnitOptionsProvidedUnit;f.unitStyle=NSFormattingUnitStyleLong;
 NSMeasurement *m=[[NSMeasurement alloc] initWithDoubleValue:1.1 unit:[NSUnitLength meters]];
 NSNumberFormatter *n=f.numberFormatter;
 printf("getter.identity: %d\n",n==f.numberFormatter);
 n.maximumFractionDigits=0;
 printf("getter.maximum: %lu\n",(unsigned long)f.numberFormatter.maximumFractionDigits);
 printf("getter.format: %s\n",[f stringFromMeasurement:m].UTF8String);
 f.numberFormatter=n;
 printf("setter.maximum: %lu\n",(unsigned long)f.numberFormatter.maximumFractionDigits);
 printf("setter.format: %s\n",[f stringFromMeasurement:m].UTF8String);
 n.minimumFractionDigits=1;n.maximumFractionDigits=1;
 printf("setter.copy: %lu\n",(unsigned long)f.numberFormatter.minimumFractionDigits);
 f.numberFormatter=n;
 printf("setter.padded: %s\n",[f stringFromMeasurement:m].UTF8String);
 printf("copy.identity: %d\n",[f copy]==f);
 f.locale=[NSLocale localeWithLocaleIdentifier:@"fr_FR"];
 printf("locale.numberLocale: %s\n",f.numberFormatter.locale.localeIdentifier.UTF8String);
 printf("locale.format: %s\n",[f stringFromMeasurement:m].UTF8String);
} }
