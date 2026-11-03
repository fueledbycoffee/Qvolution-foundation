#import <Foundation/NSDimension.h>

@interface NSUnitTemperature : NSDimension
+ (instancetype)kelvin;
+ (instancetype)celsius;
+ (instancetype)fahrenheit;
@end
