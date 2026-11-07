#import <Foundation/NSListFormatter.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSString.h>
#include <unicode/uloc.h>
#import "NSListFormatterInternal.h"

@interface NSObject (NSListItemDescription)
- (NSString *)localizedDescription;
@end

@implementation NSListFormatter
- (NSFormatter *)itemFormatter
{
    @synchronized (self) { return [[_itemFormatter retain] autorelease]; }
}

- (void)setItemFormatter:(NSFormatter *)itemFormatter
{
    NSFormatter *copy = [itemFormatter copy];
    NSFormatter *previous;
    @synchronized (self) {
        previous = _itemFormatter;
        _itemFormatter = copy;
    }
    [previous release];
}

- (NSLocale *)locale
{
    @synchronized (self) {
        return [[(_locale ?: [NSLocale autoupdatingCurrentLocale]) retain] autorelease];
    }
}

- (void)setLocale:(NSLocale *)locale
{
    NSLocale *copy = [locale copy];
    NSLocale *previous;
    @synchronized (self) {
        previous = _locale;
        _locale = copy;
        ulistfmt_close(_listFormatter);
        _listFormatter = NULL;
        [_listLocaleIdentifier release];
        _listLocaleIdentifier = nil;
    }
    [previous release];
}

- (void)dealloc
{
    [_locale release];
    [_itemFormatter release];
    [_listLocaleIdentifier release];
    ulistfmt_close(_listFormatter);
    [super dealloc];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        if ([coder allowsKeyedCoding]) {
            self.locale = [coder decodeObjectForKey:@"locale"];
            self.itemFormatter = [coder decodeObjectForKey:@"itemFormatter"];
        } else {
            self.locale = [coder decodeObject];
            self.itemFormatter = [coder decodeObject];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSLocale *locale;
    NSFormatter *itemFormatter;
    @synchronized (self) {
        locale = [_locale retain];
        itemFormatter = [_itemFormatter retain];
    }
    @try {
        if ([coder allowsKeyedCoding]) {
            [coder encodeObject:locale forKey:@"locale"];
            [coder encodeObject:itemFormatter forKey:@"itemFormatter"];
        } else {
            [coder encodeObject:locale];
            [coder encodeObject:itemFormatter];
        }
    } @finally {
        [locale release];
        [itemFormatter release];
    }
}

+ (NSString *)localizedStringByJoiningStrings:(NSArray<NSString *> *)strings
{
    NSListFormatter *formatter = [[self alloc] init];
    NSString *result = [formatter stringFromItems:strings];
    [formatter release];
    return result;
}

- (NSString *)stringFromItems:(NSArray *)items
{
    if (![items isKindOfClass:[NSArray class]]) return nil;
    NSUInteger count = [items count];
    if (!count) return @"";
    if (count > INT32_MAX || count > SIZE_MAX / sizeof(UChar *)) return nil;
    UChar **characters = calloc(count, sizeof(*characters));
    int32_t *lengths = calloc(count, sizeof(*lengths));
    if (!characters || !lengths) { free(characters); free(lengths); return nil; }
    NSString *result = nil;
    NSLocale *locale = nil;
    NSFormatter *itemFormatter = nil;
    @try {
        @synchronized (self) {
            locale = [[self locale] retain];
            itemFormatter = [[self itemFormatter] retain];
        }
        NSString *identifier = [locale localeIdentifier];
        for (NSUInteger i = 0; i < count; ++i) {
            id item = [items objectAtIndex:i];
            NSString *text = [itemFormatter stringForObjectValue:item];
            if (!text) {
                if ([item respondsToSelector:@selector(descriptionWithLocale:)])
                    text = [item descriptionWithLocale:locale];
                else if ([item respondsToSelector:@selector(localizedDescription)])
                    text = [item localizedDescription];
                else
                    text = [item description];
            }
            if (![text isKindOfClass:[NSString class]]) return nil;
            NSUInteger length = [text length];
            if (length > INT32_MAX - 2 || length > SIZE_MAX / sizeof(UChar) - 1) return nil;
            lengths[i] = (int32_t)length;
            characters[i] = malloc((length + 1) * sizeof(UChar));
            if (!characters[i]) return nil;
            [text getCharacters:characters[i] range:NSMakeRange(0, length)];
        }
        int32_t length = 0;
        UChar *buffer;
        @synchronized (self) {
            if (!_listFormatter || ![_listLocaleIdentifier isEqualToString:identifier]) {
                NSString *cacheIdentifier = [identifier copy];
                UErrorCode status = U_ZERO_ERROR;
                UListFormatter *formatter = ulistfmt_open([identifier UTF8String], &status);
                if (U_FAILURE(status)) {
                    ulistfmt_close(formatter);
                    [cacheIdentifier release];
                    return nil;
                }
                ulistfmt_close(_listFormatter);
                _listFormatter = formatter;
                [_listLocaleIdentifier release];
                _listLocaleIdentifier = cacheIdentifier;
            }
            buffer = NSListFormatItems(_listFormatter, uloc_isRightToLeft([identifier UTF8String]),
                                       (const UChar *const *)characters, lengths, (int32_t)count, &length);
        }
        if (buffer) {
            @try { result = [NSString stringWithCharacters:buffer length:length]; }
            @finally { free(buffer); }
        }
    } @finally {
        [locale release];
        [itemFormatter release];
        for (NSUInteger i = 0; i < count; ++i) free(characters[i]);
        free(characters);
        free(lengths);
    }
    return result;
}

- (NSString *)stringForObjectValue:(id)object
{
    return [self stringFromItems:object];
}

- (BOOL)getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString **)error
{
    if (object) *object = nil;
    if (error) *error = @"Lists cannot be parsed";
    return NO;
}
@end
