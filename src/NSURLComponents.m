#import <Foundation/NSURLComponents.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSException.h>
#import <CoreFoundation/CFURLComponents.h>

@implementation NSURLComponents

- (instancetype)init
{
    self = [super init];
    if (self) {
        _components = _CFURLComponentsCreate(kCFAllocatorDefault);
        if (!_components) { [self release]; return nil; }
    }
    return self;
}

- (instancetype)initWithString:(NSString *)string
{
    self = [super init];
    if (self) {
        _components = _CFURLComponentsCreateWithString(kCFAllocatorDefault, (CFStringRef)string);
        if (!_components) { [self release]; return nil; }
    }
    return self;
}

+ (instancetype)componentsWithString:(NSString *)string
{
    return [[[self alloc] initWithString:string] autorelease];
}

- (instancetype)initWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve
{
    return [self initWithString:resolve ? [url absoluteString] : [url relativeString]];
}

+ (instancetype)componentsWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve
{
    return [[[self alloc] initWithURL:url resolvingAgainstBaseURL:resolve] autorelease];
}

- (NSString *)scheme
{
    return [(NSString *)_CFURLComponentsCopyScheme(_components) autorelease];
}

- (void)setScheme:(NSString *)scheme
{
    if (!_CFURLComponentsSetScheme(_components, (CFStringRef)scheme))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL scheme"];
}

- (NSString *)host
{
    return [(NSString *)_CFURLComponentsCopyHost(_components) autorelease];
}

- (void)setHost:(NSString *)host
{
    if (!_CFURLComponentsSetHost(_components, (CFStringRef)host))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL host"];
}

- (NSURL *)URL
{
    return [(NSURL *)_CFURLComponentsCopyURL(_components) autorelease];
}

- (NSArray *)queryItems
{
    NSArray *pairs = [(NSArray *)_CFURLComponentsCopyQueryItems(_components) autorelease];
    if (!pairs) return nil;
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[pairs count]];
    for (NSDictionary *pair in pairs) {
        [items addObject:[[[NSURLQueryItem alloc]
            initWithName:[pair objectForKey:(NSString *)_kCFURLComponentsNameKey]
            value:[pair objectForKey:(NSString *)_kCFURLComponentsValueKey]] autorelease]];
    }
    return [[items copy] autorelease];
}

- (void)setQueryItems:(NSArray *)items
{
    if (!items) {
        _CFURLComponentsSetPercentEncodedQuery(_components, NULL);
        return;
    }
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:[items count]];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:[items count]];
    for (NSURLQueryItem *item in items) {
        [names addObject:[item name]];
        [values addObject:[item value] ?: [NSNull null]];
    }
    _CFURLComponentsSetQueryItems(_components, (CFArrayRef)names, (CFArrayRef)values);
}

- (NSString *)user
{
    return [(NSString *)_CFURLComponentsCopyUser(_components) autorelease];
}

- (void)setUser:(NSString *)value
{
    _CFURLComponentsSetUser(_components, (CFStringRef)value);
}

- (NSString *)password
{
    return [(NSString *)_CFURLComponentsCopyPassword(_components) autorelease];
}

- (void)setPassword:(NSString *)value
{
    _CFURLComponentsSetPassword(_components, (CFStringRef)value);
}

- (NSString *)path
{
    return [(NSString *)_CFURLComponentsCopyPath(_components) autorelease];
}

- (void)setPath:(NSString *)value
{
    _CFURLComponentsSetPath(_components, (CFStringRef)value);
}

- (NSString *)query
{
    return [(NSString *)_CFURLComponentsCopyQuery(_components) autorelease];
}

- (void)setQuery:(NSString *)value
{
    _CFURLComponentsSetQuery(_components, (CFStringRef)value);
}

- (NSString *)fragment
{
    return [(NSString *)_CFURLComponentsCopyFragment(_components) autorelease];
}

- (void)setFragment:(NSString *)value
{
    _CFURLComponentsSetFragment(_components, (CFStringRef)value);
}

- (NSString *)percentEncodedUser
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedUser(_components) autorelease];
}

- (void)setPercentEncodedUser:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedUser(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid characters in percentEncodedUser"];
}

- (NSString *)percentEncodedPassword
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedPassword(_components) autorelease];
}

- (void)setPercentEncodedPassword:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedPassword(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid characters in percentEncodedPassword"];
}

- (NSString *)percentEncodedHost
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedHost(_components) autorelease];
}

- (void)setPercentEncodedHost:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedHost(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid characters in percentEncodedHost"];
}

- (NSString *)percentEncodedPath
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedPath(_components) autorelease];
}

- (void)setPercentEncodedPath:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedPath(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid characters in percentEncodedPath"];
}

- (NSString *)percentEncodedQuery
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedQuery(_components) autorelease];
}

- (void)setPercentEncodedQuery:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedQuery(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid characters in percentEncodedQuery"];
}

- (NSString *)percentEncodedFragment
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedFragment(_components) autorelease];
}

- (void)setPercentEncodedFragment:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedFragment(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid characters in percentEncodedFragment"];
}

- (NSRange)rangeOfScheme
{
    CFRange range = _CFURLComponentsGetRangeOfScheme(_components);
    return range.location == kCFNotFound ? NSMakeRange(NSNotFound, 0) : NSMakeRange(range.location, range.length);
}

- (NSRange)rangeOfUser
{
    CFRange range = _CFURLComponentsGetRangeOfUser(_components);
    return range.location == kCFNotFound ? NSMakeRange(NSNotFound, 0) : NSMakeRange(range.location, range.length);
}

- (NSRange)rangeOfPassword
{
    CFRange range = _CFURLComponentsGetRangeOfPassword(_components);
    return range.location == kCFNotFound ? NSMakeRange(NSNotFound, 0) : NSMakeRange(range.location, range.length);
}

- (NSRange)rangeOfHost
{
    CFRange range = _CFURLComponentsGetRangeOfHost(_components);
    return range.location == kCFNotFound ? NSMakeRange(NSNotFound, 0) : NSMakeRange(range.location, range.length);
}

- (NSRange)rangeOfPort
{
    CFRange range = _CFURLComponentsGetRangeOfPort(_components);
    return range.location == kCFNotFound ? NSMakeRange(NSNotFound, 0) : NSMakeRange(range.location, range.length);
}

- (NSRange)rangeOfPath
{
    CFRange range = _CFURLComponentsGetRangeOfPath(_components);
    return range.location == kCFNotFound ? NSMakeRange(NSNotFound, 0) : NSMakeRange(range.location, range.length);
}

- (NSRange)rangeOfQuery
{
    CFRange range = _CFURLComponentsGetRangeOfQuery(_components);
    return range.location == kCFNotFound ? NSMakeRange(NSNotFound, 0) : NSMakeRange(range.location, range.length);
}

- (NSRange)rangeOfFragment
{
    CFRange range = _CFURLComponentsGetRangeOfFragment(_components);
    return range.location == kCFNotFound ? NSMakeRange(NSNotFound, 0) : NSMakeRange(range.location, range.length);
}

- (NSNumber *)port
{
    return [(NSNumber *)_CFURLComponentsCopyPort(_components) autorelease];
}

- (void)setPort:(NSNumber *)port
{
    if (!_CFURLComponentsSetPort(_components, (CFNumberRef)port))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL port"];
}

- (NSString *)string
{
    return [(NSString *)_CFURLComponentsCopyString(_components) autorelease];
}

- (NSURL *)URLRelativeToURL:(NSURL *)baseURL
{
    return [(NSURL *)_CFURLComponentsCopyURLRelativeToURL(_components, (CFURLRef)baseURL) autorelease];
}

- (NSArray *)percentEncodedQueryItems
{
    NSArray *pairs = [(NSArray *)_CFURLComponentsCopyPercentEncodedQueryItems(_components) autorelease];
    if (!pairs) return nil;
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[pairs count]];
    for (NSDictionary *pair in pairs) {
        [items addObject:[[[NSURLQueryItem alloc]
            initWithName:[pair objectForKey:(NSString *)_kCFURLComponentsNameKey]
            value:[pair objectForKey:(NSString *)_kCFURLComponentsValueKey]] autorelease]];
    }
    return [[items copy] autorelease];
}

- (void)setPercentEncodedQueryItems:(NSArray *)items
{
    if (!items) {
        _CFURLComponentsSetPercentEncodedQuery(_components, NULL);
        return;
    }
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:[items count]];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:[items count]];
    for (NSURLQueryItem *item in items) {
        [names addObject:[item name]];
        [values addObject:[item value] ?: [NSNull null]];
    }
    if (!_CFURLComponentsSetPercentEncodedQueryItems(_components, (CFArrayRef)names, (CFArrayRef)values))
        [NSException raise:NSInvalidArgumentException format:@"invalid characters in percentEncodedQueryItems"];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSURLComponents *copy = [[NSURLComponents allocWithZone:zone] init];
    if (copy) {
        CFRelease(copy->_components);
        copy->_components = _CFURLComponentsCreateCopy(kCFAllocatorDefault, _components);
    }
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p> %@", [self class], self, [self string]];
}

- (void)dealloc
{
    if (_components) CFRelease(_components);
    [super dealloc];
}

@end
