#import <Foundation/Foundation.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
 for(NSString *locale in @[@"en_US",@"en_GB",@"fr_FR",@"ru_RU"]) {
  NSMeasurementFormatter *f=[NSMeasurementFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:locale];f.unitOptions=1;
  for(NSUInteger style=1;style<=3;style++) for(NSNumber *fraction in @[@0,@2]) {
   f.unitStyle=style;f.numberFormatter.minimumFractionDigits=fraction.unsignedIntegerValue;f.numberFormatter.maximumFractionDigits=fraction.unsignedIntegerValue;
   // Changing the style away and back refreshes the numeric snapshot.
   f.unitStyle=style==1?2:1;f.unitStyle=style;
   for(NSUnit *unit in @[[NSUnitLength micrometers],[NSUnitLength fathoms],[NSUnitLength picometers],[NSUnitLength scandinavianMiles],[NSUnitLength nauticalMiles],[NSUnitLength miles],[NSUnitLength lightyears]]) {
    printf("name(%s,%lu,%lu,%s): %s\n",locale.UTF8String,(unsigned long)style,(unsigned long)fraction.unsignedIntegerValue,unit.symbol.UTF8String,[f stringFromUnit:unit].UTF8String);
    for(NSNumber *value in @[@-3,@-1,@0,@0.2,@1.1,@7,@12.3]) {
     NSMeasurement *m=[[NSMeasurement alloc]initWithDoubleValue:value.doubleValue unit:unit];
     printf("pattern(%s,%lu,%lu,%s,%g): %s\n",locale.UTF8String,(unsigned long)style,(unsigned long)fraction.unsignedIntegerValue,unit.symbol.UTF8String,value.doubleValue,[f stringFromMeasurement:m].UTF8String);
    }
   }
  }
 }
} }
