#import <Foundation/NSFormatter.h>
#import <Foundation/NSArray.h>

@class NSLocale;

@interface NSListFormatter : NSFormatter {
    NSLocale *_locale;
    NSFormatter *_itemFormatter;
    NSString *_listLocaleIdentifier;
    void *_listFormatter;
}
@property (copy, null_resettable) NSLocale *locale;
@property (copy, nullable) NSFormatter *itemFormatter;
+ (NSString *)localizedStringByJoiningStrings:(NSArray<NSString *> *)strings;
- (NSString *)stringFromItems:(NSArray *)items;
@end
