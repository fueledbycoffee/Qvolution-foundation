#import <Foundation/NSUnit.h>

@interface NSMeasurement<__covariant UnitType : NSUnit *> : NSObject <NSCopying, NSSecureCoding> {
    NSUnit *_unit;
    double _doubleValue;
}
@property (readonly, copy) UnitType unit;
@property (readonly) double doubleValue;
- (instancetype)initWithDoubleValue:(double)doubleValue unit:(UnitType)unit;
- (BOOL)canBeConvertedToUnit:(NSUnit *)unit;
- (NSMeasurement *)measurementByConvertingToUnit:(NSUnit *)unit;
- (NSMeasurement *)measurementByAddingMeasurement:(NSMeasurement *)measurement;
- (NSMeasurement *)measurementBySubtractingMeasurement:(NSMeasurement *)measurement;
@end
