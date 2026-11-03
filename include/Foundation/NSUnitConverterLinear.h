#import <Foundation/NSUnitConverter.h>

@interface NSUnitConverterLinear : NSUnitConverter <NSSecureCoding> {
    double _coefficient;
    double _constant;
}
@property (readonly) double coefficient;
@property (readonly) double constant;
- (instancetype)initWithCoefficient:(double)coefficient;
- (instancetype)initWithCoefficient:(double)coefficient constant:(double)constant;
@end
