#import <Foundation/Foundation.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
 for(NSString *locale in @[@"en_US",@"fr_FR"])
 for(NSUnitLength *unit in @[[NSUnitLength meters],[NSUnitLength megameters],[NSUnitLength decimeters],[NSUnitLength picometers],[NSUnitLength lightyears],[NSUnitLength scandinavianMiles]]) {
  NSMeasurementFormatter *f=[NSMeasurementFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:locale];f.unitOptions=3;
  for(NSNumber *meters in @[@-1000,@-0.001001,@0,@0.0009999,@0.001,@0.0010001,@0.002,@0.99,@1,@1.000001,@499,@500,@500.00001,@999.9999,@1000]) {
   NSMeasurement *m=[[[NSMeasurement alloc]initWithDoubleValue:meters.doubleValue unit:[NSUnitLength meters]]measurementByConvertingToUnit:unit];
   printf("boundary(%s,%s,%.8g): %s\n",locale.UTF8String,unit.symbol.UTF8String,meters.doubleValue,[f stringFromMeasurement:m].UTF8String);
  }
 }
 NSMeasurementFormatter *f=[NSMeasurementFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US"];f.unitOptions=2;
 for(NSNumber *meters in @[@1,@1.0000001,@499,@500,@500.000001,@999])
  printf("imperial(%.10g): %s\n",meters.doubleValue,[f stringFromMeasurement:[[NSMeasurement alloc]initWithDoubleValue:meters.doubleValue unit:[NSUnitLength meters]]].UTF8String);
} }
