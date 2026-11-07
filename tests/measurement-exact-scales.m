#import <Foundation/Foundation.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
 NSMeasurementFormatter *f=[NSMeasurementFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US"];f.unitOptions=2;
 for(NSNumber *meters in @[@1.9811999,@1.9812,@1.9812001,@274.319999,@274.32,@274.320001,@804.671999,@804.672,@804.672001,@304.799,@304.8,@304.80001,@300,@299.999,@300.001])
  printf("boundary(%.10g): %s\n",meters.doubleValue,[f stringFromMeasurement:[[NSMeasurement alloc]initWithDoubleValue:meters.doubleValue unit:[NSUnitLength meters]]].UTF8String);
 for(NSUnit *unit in @[[NSUnitLength nanometers],[NSUnitLength decimeters],[NSUnitLength yards],[NSUnitLength furlongs],[NSUnitLength fathoms],[NSUnitLength nauticalMiles],[NSUnitLength scandinavianMiles],[NSUnitLength astronomicalUnits],[NSUnitLength parsecs],[NSUnitLength lightyears]]) {
  f.unitOptions=3;
  printf("providedScale(%s): %s\n",unit.symbol.UTF8String,[f stringFromMeasurement:[[[NSMeasurement alloc]initWithDoubleValue:100 unit:[NSUnitLength meters]] measurementByConvertingToUnit:unit]].UTF8String);
 }
} }
