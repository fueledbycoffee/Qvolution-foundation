#import <Foundation/NSUnit.h>
@class NSUnitConverter;

@interface NSDimension : NSUnit {
    NSUnitConverter *_converter;
}
@property (readonly, retain) NSUnitConverter *converter;
- (instancetype)initWithSymbol:(NSString *)symbol converter:(NSUnitConverter *)converter;
+ (instancetype)baseUnit;
@end
