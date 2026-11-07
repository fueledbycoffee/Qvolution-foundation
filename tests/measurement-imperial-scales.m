#import <Foundation/Foundation.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
 NSMeasurementFormatter *f=[NSMeasurementFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US"];f.unitOptions=2;
 for(NSNumber *meters in @[@1,@1.01,@1.1,@1.21919,@1.2192,@1.21921,@1.5,@99.999,@100,@100.001,@199,@200,@200.001,@400,@499,@500,@500.001,@799,@800,@800.001,@803,@804,@804.6719,@804.672,@804.6721,@805,@999,@1000])
  printf("imperial(%.10g): %s\n",meters.doubleValue,[f stringFromMeasurement:[[NSMeasurement alloc]initWithDoubleValue:meters.doubleValue unit:[NSUnitLength meters]]].UTF8String);
 for(NSUnit *unit in @[[NSUnitLength hectometers],[NSUnitLength decameters],[NSUnitLength megameters],[NSUnitLength micrometers],[NSUnitLength astronomicalUnits],[NSUnitLength fathoms]]) for(NSNumber *opt in @[@0,@2,@3]) {
  f.unitOptions=opt.unsignedIntegerValue;
  printf("source(%s,%lu): %s\n",unit.symbol.UTF8String,(unsigned long)f.unitOptions,[f stringFromMeasurement:[[NSMeasurement alloc]initWithDoubleValue:1 unit:unit]].UTF8String);
 }
} }
