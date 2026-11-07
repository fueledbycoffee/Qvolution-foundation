#import <Foundation/Foundation.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
 for (NSString *locale in @[@"en_US_POSIX", @"en_GB", @"fr_FR", @"ja_JP"]) {
  NSMeasurementFormatter *f=[NSMeasurementFormatter new];f.locale=[[NSLocale alloc] initWithLocaleIdentifier:locale];
  for (NSNumber *options in @[@0,@1,@2,@3]) {
   f.unitOptions=options.unsignedIntegerValue;
   for (NSNumber *value in @[@0,@0.001,@0.1,@1,@12,@999,@12000]) {
    NSMeasurement *m=[[NSMeasurement alloc] initWithDoubleValue:value.doubleValue unit:[NSUnitLength meters]];
    printf("formatter(%s,%lu,%g): %s\n",locale.UTF8String,(unsigned long)f.unitOptions,value.doubleValue,[f stringFromMeasurement:m].UTF8String);
   }
  }
  f.unitStyle=NSFormattingUnitStyleLong;f.unitOptions=NSMeasurementFormatterUnitOptionsProvidedUnit;
  printf("unitName(%s): %s\n",locale.UTF8String,[f stringFromUnit:[NSUnitLength meters]].UTF8String);
  f.numberFormatter.maximumFractionDigits=0;
  printf("roundedPlural(%s): %s\n",locale.UTF8String,[f stringFromMeasurement:[[NSMeasurement alloc] initWithDoubleValue:1.2 unit:[NSUnitLength meters]]].UTF8String);
  f.unitOptions|=NSMeasurementFormatterUnitOptionsTemperatureWithoutUnit;
  printf("temperature(%s): %s\n",locale.UTF8String,[f stringFromMeasurement:[[NSMeasurement alloc] initWithDoubleValue:72 unit:[NSUnitTemperature fahrenheit]]].UTF8String);
 }
} }
