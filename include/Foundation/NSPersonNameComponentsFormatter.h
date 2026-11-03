#import <Foundation/NSFormatter.h>

@class NSLocale, NSPersonNameComponents;

typedef NS_ENUM(NSInteger, NSPersonNameComponentsFormatterStyle) {
    NSPersonNameComponentsFormatterStyleDefault = 0,
    NSPersonNameComponentsFormatterStyleShort,
    NSPersonNameComponentsFormatterStyleMedium,
    NSPersonNameComponentsFormatterStyleLong,
    NSPersonNameComponentsFormatterStyleAbbreviated,
};

typedef NS_OPTIONS(NSUInteger, NSPersonNameComponentsFormatterOptions) {
    NSPersonNameComponentsFormatterPhonetic = 1UL << 1,
};

FOUNDATION_EXPORT NSString * const NSPersonNameComponentKey;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentGivenName;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentFamilyName;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentMiddleName;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentPrefix;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentSuffix;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentNickname;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentDelimiter;

@interface NSPersonNameComponentsFormatter : NSFormatter
{
    NSPersonNameComponentsFormatterStyle _style;
    NSLocale *_locale;
    BOOL _phonetic;
}
@property NSPersonNameComponentsFormatterStyle style;
@property (copy) NSLocale *locale;
@property (getter=isPhonetic) BOOL phonetic;

+ (NSString *)localizedStringFromPersonNameComponents:(NSPersonNameComponents *)components
    style:(NSPersonNameComponentsFormatterStyle)style options:(NSPersonNameComponentsFormatterOptions)options;
- (NSString *)stringFromPersonNameComponents:(NSPersonNameComponents *)components;
- (NSAttributedString *)annotatedStringFromPersonNameComponents:(NSPersonNameComponents *)components;
- (NSPersonNameComponents *)personNameComponentsFromString:(NSString *)string;
@end
