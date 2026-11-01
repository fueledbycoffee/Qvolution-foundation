#import <Foundation/NSURLSession.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>

@implementation NSURLSessionWebSocketMessage
@synthesize type = _type, data = _data, string = _string;
- (instancetype)init
{
    [self release];
    [NSException raise:NSInvalidArgumentException format:@"Use initWithData: or initWithString:"];
    return nil;
}
- (instancetype)initWithData:(NSData *)data
{
    if (!data) { [self release]; [NSException raise:NSInvalidArgumentException format:@"WebSocket data is nil"]; return nil; }
    if ((self = [super init])) { _type = NSURLSessionWebSocketMessageTypeData; _data = [data copy]; }
    return self;
}
- (instancetype)initWithString:(NSString *)string
{
    if (!string) { [self release]; [NSException raise:NSInvalidArgumentException format:@"WebSocket string is nil"]; return nil; }
    if ((self = [super init])) { _type = NSURLSessionWebSocketMessageTypeString; _string = [string copy]; }
    return self;
}
- (void)dealloc { [_data release]; [_string release]; [super dealloc]; }
@end
