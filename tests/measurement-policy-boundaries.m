#import <Foundation/Foundation.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
 for (NSString *locale in @[@"en_US",@"en_GB",@"fr_FR"]) {
  for (NSNumber *option in @[@2,@3]) {
   for (NSUnitLength *unit in @[[NSUnitLength meters],[NSUnitLength centimeters],[NSUnitLength kilometers],[NSUnitLength inches],[NSUnitLength feet],[NSUnitLength yards],[NSUnitLength miles],[NSUnitLength nauticalMiles]]) {
    NSMeasurementFormatter *f=[NSMeasurementFormatter new]; f.locale=[NSLocale localeWithLocaleIdentifier:locale]; f.unitOptions=option.unsignedIntegerValue;
    for (NSNumber *meters in @[@0,@0.000001,@0.000999,@0.001,@0.009,@0.01,@0.099,@0.1,@0.999,@1,@1.999,@2,@2.999,@3,@9.999,@10,@99,@100,@160,@161,@999,@1000,@-0.1,@-999]) {
     NSMeasurement *m=[[[NSMeasurement alloc] initWithDoubleValue:meters.doubleValue unit:[NSUnitLength meters]] measurementByConvertingToUnit:unit];
     printf("scale(%s,%lu,%s,%g): %s\n",locale.UTF8String,(unsigned long)f.unitOptions,unit.symbol.UTF8String,meters.doubleValue,[f stringFromMeasurement:m].UTF8String);
    }
   }
  }
 }
 for(NSString *locale in @[@"en_US",@"en_GB",@"fr_FR",@"ja_JP",@"ru_RU"]) {
  NSMeasurementFormatter *f=[NSMeasurementFormatter new]; f.locale=[NSLocale localeWithLocaleIdentifier:locale];
  for(NSUnit *unit in @[[NSUnitTemperature celsius],[NSUnitTemperature fahrenheit],[NSUnitTemperature kelvin]])
   for(NSNumber *option in @[@4,@5,@6,@7]) for(NSUInteger style=1;style<=3;style++) {
    f.unitOptions=option.unsignedIntegerValue;f.unitStyle=style;
    for(NSNumber *value in @[@1,@2,@-1])
     printf("degrees(%s,%lu,%lu,%s,%g): %s\n",locale.UTF8String,(unsigned long)f.unitOptions,(unsigned long)style,unit.symbol.UTF8String,value.doubleValue,[f stringFromMeasurement:[[NSMeasurement alloc]initWithDoubleValue:value.doubleValue unit:unit]].UTF8String);
   }
 }
} }
