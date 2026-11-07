#import <Foundation/Foundation.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
 for(NSUnitLength *u in @[[NSUnitLength astronomicalUnits],[NSUnitLength lightyears],[NSUnitLength parsecs]])
  printf("coefficient(%s): %.17g\n",u.symbol.UTF8String,[(NSUnitConverterLinear *)u.converter coefficient]);
} }
