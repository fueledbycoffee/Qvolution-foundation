#import <Foundation/NSObject.h>

@interface NSUnit : NSObject <NSCopying, NSSecureCoding> {
    NSString *_symbol;
}
@property (readonly, copy) NSString *symbol;
- (instancetype)initWithSymbol:(NSString *)symbol;
@end
