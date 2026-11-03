/* Copyright (C) 2026 Darling contributors. SPDX-License-Identifier: GPL-3.0-or-later */
#import <Foundation/NSPersonNameComponentsFormatter.h>
#import <Foundation/NSPersonNameComponents.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSAttributedString.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSString.h>
#include <unicode/uscript.h>
#include <unicode/uchar.h>

NSString * const NSPersonNameComponentKey = @"NSPersonNameComponentKey";
NSString * const NSPersonNameComponentGivenName = @"givenName";
NSString * const NSPersonNameComponentFamilyName = @"familyName";
NSString * const NSPersonNameComponentMiddleName = @"middleName";
NSString * const NSPersonNameComponentPrefix = @"namePrefix";
NSString * const NSPersonNameComponentSuffix = @"nameSuffix";
NSString * const NSPersonNameComponentNickname = @"nickname";
NSString * const NSPersonNameComponentDelimiter = @"delimiter";

static NSString *namePart(NSString *part)
{
    return [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static UChar32 nameCharacter(NSString *string, NSUInteger index, NSUInteger *width)
{
    UChar32 c = [string characterAtIndex:index];
    *width = 1;
    if (c >= 0xd800 && c <= 0xdbff && index + 1 < [string length])
    {
        unichar low = [string characterAtIndex:index + 1];
        if (low >= 0xdc00 && low <= 0xdfff)
        {
            c = 0x10000 + ((c - 0xd800) << 10) + low - 0xdc00;
            *width = 2;
        }
    }
    return c;
}

static UScriptCode nameScript(NSString *given, NSString *family)
{
    UScriptCode result = USCRIPT_COMMON;
    NSString *parts[] = {given, family};
    for (unsigned p = 0; p < 2; ++p)
    {
        for (NSUInteger i = 0; i < [parts[p] length]; ++i)
        {
            NSUInteger width;
            UChar32 c = nameCharacter(parts[p], i, &width);
            i += width - 1;
            UErrorCode error = U_ZERO_ERROR;
            UScriptCode script = uscript_getScript(c, &error);
            if (U_FAILURE(error) || script == USCRIPT_COMMON || script == USCRIPT_INHERITED)
                continue;
            if (script == USCRIPT_HIRAGANA || script == USCRIPT_KATAKANA)
                script = USCRIPT_HAN;
            if (result != USCRIPT_COMMON && result != script)
                return USCRIPT_UNKNOWN;
            result = script;
        }
    }
    return result;
}

static NSString *initial(NSString *part)
{
    return [part length] ? [part substringWithRange:[part rangeOfComposedCharacterSequenceAtIndex:0]] : @"";
}

static void appendPart(NSMutableAttributedString *result, NSString *part, NSString *key, NSString *separator)
{
    if (![part length]) return;
    if ([result length] && [separator length])
    {
        NSAttributedString *delimiter = [[NSAttributedString alloc] initWithString:separator
            attributes:@{NSPersonNameComponentKey: NSPersonNameComponentDelimiter}];
        [result appendAttributedString:delimiter];
        [delimiter release];
    }
    NSAttributedString *component = [[NSAttributedString alloc] initWithString:part
        attributes:@{NSPersonNameComponentKey: key}];
    [result appendAttributedString:component];
    [component release];
}

@implementation NSPersonNameComponentsFormatter
@synthesize style = _style;
@synthesize phonetic = _phonetic;

- (instancetype)init
{
    self = [super init];
    if (self) _locale = [[NSLocale autoupdatingCurrentLocale] copy];
    return self;
}

- (void)dealloc
{
    [_locale release];
    [super dealloc];
}

- (NSLocale *)locale { return _locale; }
- (void)setLocale:(NSLocale *)locale
{
    NSLocale *replacement = [(locale ?: [NSLocale autoupdatingCurrentLocale]) copy];
    [_locale release];
    _locale = replacement;
}

+ (NSString *)localizedStringFromPersonNameComponents:(NSPersonNameComponents *)components
    style:(NSPersonNameComponentsFormatterStyle)style options:(NSPersonNameComponentsFormatterOptions)options
{
    NSPersonNameComponentsFormatter *formatter = [[self alloc] init];
    formatter.style = style;
    formatter.phonetic = (options & NSPersonNameComponentsFormatterPhonetic) != 0;
    NSString *result = [[formatter stringFromPersonNameComponents:components] retain];
    [formatter release];
    return [result autorelease];
}

- (NSAttributedString *)annotatedStringFromPersonNameComponents:(NSPersonNameComponents *)components
{
    if (![components isKindOfClass:[NSPersonNameComponents class]])
        [NSException raise:NSInvalidArgumentException format:@"Expected person name components"];
    if (_phonetic) components = [components phoneticRepresentation];
    NSString *given = namePart([components givenName]), *family = namePart([components familyName]);
    NSString *nickname = namePart([components nickname]);
    UScriptCode script = nameScript(given, family);
    BOOL cjk = script == USCRIPT_HAN || script == USCRIPT_HANGUL;
    NSPersonNameComponentsFormatterStyle style = _style;
    if (style == NSPersonNameComponentsFormatterStyleDefault) style = NSPersonNameComponentsFormatterStyleMedium;
    if (cjk && style == NSPersonNameComponentsFormatterStyleShort) style = NSPersonNameComponentsFormatterStyleMedium;
    if (style == NSPersonNameComponentsFormatterStyleAbbreviated && script == USCRIPT_ARABIC)
        style = NSPersonNameComponentsFormatterStyleShort;
    NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] initWithString:@""] autorelease];
    if (style == NSPersonNameComponentsFormatterStyleAbbreviated)
    {
        if (script == USCRIPT_HAN && [family length])
            appendPart(result, family, NSPersonNameComponentFamilyName, @"");
        else if (script == USCRIPT_HANGUL)
            appendPart(result, [given length] ? given : family,
                [given length] ? NSPersonNameComponentGivenName : NSPersonNameComponentFamilyName, @"");
        else if (script == USCRIPT_LATIN || script == USCRIPT_GREEK || script == USCRIPT_CYRILLIC || script == USCRIPT_COMMON)
        {
            appendPart(result, initial(given), NSPersonNameComponentGivenName, @"");
            appendPart(result, initial(family), NSPersonNameComponentFamilyName, @"");
        }
        else
            appendPart(result, initial([given length] ? given : family),
                [given length] ? NSPersonNameComponentGivenName : NSPersonNameComponentFamilyName, @"");
    }
    else if (style == NSPersonNameComponentsFormatterStyleShort)
    {
        if ([nickname length]) appendPart(result, nickname, NSPersonNameComponentNickname, @"");
        else appendPart(result, [given length] ? given : family,
            [given length] ? NSPersonNameComponentGivenName : NSPersonNameComponentFamilyName, @"");
    }
    else
    {
        NSString *separator = cjk ? @"" : @" ";
        if (style == NSPersonNameComponentsFormatterStyleLong)
            appendPart(result, namePart([components namePrefix]), NSPersonNameComponentPrefix, separator);
        if (cjk) appendPart(result, family, NSPersonNameComponentFamilyName, separator);
        appendPart(result, given, NSPersonNameComponentGivenName, separator);
        if (style == NSPersonNameComponentsFormatterStyleLong)
            appendPart(result, namePart([components middleName]), NSPersonNameComponentMiddleName, separator);
        if (!cjk) appendPart(result, family, NSPersonNameComponentFamilyName, separator);
        if (style == NSPersonNameComponentsFormatterStyleLong)
            appendPart(result, namePart([components nameSuffix]), NSPersonNameComponentSuffix, separator);
        if (![result length]) appendPart(result, nickname, NSPersonNameComponentNickname, @"");
    }
    return [[result copy] autorelease];
}

- (NSString *)stringFromPersonNameComponents:(NSPersonNameComponents *)components
{
    return [[self annotatedStringFromPersonNameComponents:components] string];
}

- (NSString *)stringForObjectValue:(id)object
{
    return [object isKindOfClass:[NSPersonNameComponents class]] ? [self stringFromPersonNameComponents:object] : nil;
}

- (NSPersonNameComponents *)personNameComponentsFromString:(NSString *)string
{
    if (![string isKindOfClass:[NSString class]]) return nil;
    // Keep name punctuation, but treat other symbols as token boundaries.
    NSMutableString *clean = [NSMutableString string];
    NSUInteger nesting = 0;
    for (NSUInteger i = 0; i < [string length];)
    {
        NSUInteger width;
        UChar32 c = nameCharacter(string, i, &width);
        NSRange range = NSMakeRange(i, width);
        i += width;
        if (c == '(' || c == '[')
        {
            if (!nesting) [clean appendString:@" "];
            ++nesting;
            continue;
        }
        if (c == ')' || c == ']') { if (nesting) --nesting; continue; }
        if (nesting) continue;
        int8_t type = u_charType(c);
        if (u_isalpha(c) || type == U_NON_SPACING_MARK || type == U_COMBINING_SPACING_MARK
            || type == U_ENCLOSING_MARK || type == U_DASH_PUNCTUATION
            || c == '\'' || c == 0x2019 || c == '.')
            [clean appendString:[string substringWithRange:range]];
        else if (c == ',') [clean appendString:@", "];
        else [clean appendString:@" "];
    }
    NSMutableArray *words = [NSMutableArray array];
    NSUInteger comma = NSNotFound;
    for (NSString *token in [clean componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]])
    {
        BOOL delimiter = [token hasSuffix:@","];
        NSString *word = delimiter ? [token substringToIndex:[token length] - 1] : token;
        BOOL hasLetter = NO;
        for (NSUInteger i = 0; i < [word length];)
        {
            NSUInteger width;
            UChar32 c = nameCharacter(word, i, &width);
            i += width;
            if (u_isalpha(c)) { hasLetter = YES; break; }
        }
        if (hasLetter) [words addObject:word];
        if (delimiter && comma == NSNotFound && [words count]) comma = [words count] - 1;
    }
    if (![words count]) return nil;
    NSPersonNameComponents *result = [[[NSPersonNameComponents alloc] init] autorelease];
    NSString *first = [words objectAtIndex:0];
    NSArray *prefixes = @[@"dr.", @"mr.", @"mrs.", @"ms.", @"prof."];
    if ([prefixes containsObject:[first lowercaseString]])
    {
        result.namePrefix = first;
        [words removeObjectAtIndex:0];
        if (comma != NSNotFound) comma = comma ? comma - 1 : NSNotFound;
    }
    if (![words count]) return result;
    NSString *last = [words lastObject];
    NSArray *suffixes = @[@"jr.", @"sr.", @"ii", @"iii", @"iv", @"esq.", @"phd", @"ph.d."];
    if ([suffixes containsObject:[last lowercaseString]])
    {
        result.nameSuffix = last;
        [words removeLastObject];
    }
    if (![words count]) return result;
    first = [words objectAtIndex:0];
    last = [words lastObject];
    UScriptCode script = nameScript(first, last);
    if (script == USCRIPT_HAN || script == USCRIPT_HANGUL)
    {
        // An unsegmented name needs a surname lexicon; avoid guessing its boundary.
        if ([words count] < 2) return nil;
        result.familyName = first;
        result.givenName = [[words subarrayWithRange:NSMakeRange(1, [words count] - 1)] componentsJoinedByString:@""];
    }
    else
    {
        if (comma != NSNotFound && comma + 1 < [words count])
        {
            result.familyName = [[words subarrayWithRange:NSMakeRange(0, comma + 1)] componentsJoinedByString:@" "];
            [words removeObjectsInRange:NSMakeRange(0, comma + 1)];
            result.givenName = [words objectAtIndex:0];
            if ([words count] > 1)
                result.middleName = [[words subarrayWithRange:NSMakeRange(1, [words count] - 1)] componentsJoinedByString:@" "];
        }
        else
        {
            result.givenName = first;
            if ([words count] > 1)
            {
                NSUInteger familyStart = [words count] - 1;
                // The documented Latin grammar includes compound surnames led by de.
                for (NSUInteger i = 1; i < familyStart; ++i)
                    if ([[[words objectAtIndex:i] lowercaseString] isEqual:@"de"])
                    {
                        familyStart = i;
                        break;
                    }
                result.familyName = [[words subarrayWithRange:NSMakeRange(familyStart,
                    [words count] - familyStart)] componentsJoinedByString:@" "];
                if (familyStart > 1)
                    result.middleName = [[words subarrayWithRange:NSMakeRange(1, familyStart - 1)] componentsJoinedByString:@" "];
            }
        }
    }
    return result;
}

- (BOOL)getObjectValue:(out id *)object forString:(NSString *)string errorDescription:(out NSString **)error
{
    NSPersonNameComponents *result = [self personNameComponentsFromString:string];
    if (object) *object = result;
    if (!result && error) *error = @"The string does not contain a recognizable person name.";
    return result != nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSPersonNameComponentsFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy.style = _style;
    copy.phonetic = _phonetic;
    copy.locale = _locale;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    if ([coder allowsKeyedCoding])
    {
        [coder encodeInteger:_style forKey:@"style"];
        [coder encodeBool:_phonetic forKey:@"phonetic"];
        [coder encodeObject:_locale forKey:@"locale"];
    }
    else
    {
        [coder encodeValueOfObjCType:@encode(NSPersonNameComponentsFormatterStyle) at:&_style];
        [coder encodeValueOfObjCType:@encode(BOOL) at:&_phonetic];
        [coder encodeObject:_locale];
    }
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
    {
        if ([coder allowsKeyedCoding])
        {
            _style = [coder decodeIntegerForKey:@"style"];
            _phonetic = [coder decodeBoolForKey:@"phonetic"];
            _locale = [[coder decodeObjectOfClass:[NSLocale class] forKey:@"locale"] copy];
        }
        else
        {
            [coder decodeValueOfObjCType:@encode(NSPersonNameComponentsFormatterStyle) at:&_style];
            [coder decodeValueOfObjCType:@encode(BOOL) at:&_phonetic];
            _locale = [[coder decodeObject] copy];
        }
        if (!_locale) _locale = [[NSLocale autoupdatingCurrentLocale] copy];
    }
    return self;
}
@end
