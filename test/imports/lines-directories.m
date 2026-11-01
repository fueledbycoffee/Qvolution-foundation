#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

static void require(BOOL condition, const char *check) {
    if (!condition) { fprintf(stderr, "FAIL %s\n", check); exit(1); }
}

static void checkLines(NSString *string, NSArray *expected) {
    NSMutableArray *lines = [NSMutableArray array];
    [string enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        [lines addObject:line];
    }];
    require([lines isEqual:expected], "line contents exclude terminators");
}

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    checkLines(@"éclair\r\nlast", @[@"éclair", @"last"]);
    checkLines(@"two words\r\nlast", @[@"two words", @"last"]);
    checkLines(@"", @[]);
    checkLines(@"\n\r\n\r", @[@"", @"", @""]);
    checkLines(@"a\u0085b\u2028c\u2029d", @[@"a", @"b", @"c", @"d"]);
    NSMutableArray *reverse = [NSMutableArray array];
    [@"a\r\nb\r\n" enumerateSubstringsInRange:NSMakeRange(0, 6)
        options:NSStringEnumerationByLines | NSStringEnumerationReverse
        usingBlock:^(NSString *line, NSRange substring, NSRange enclosing, BOOL *stop) {
            [reverse addObject:line];
        }];
    require([reverse isEqual:@[@"b", @"a"]], "reverse lines exclude terminators");
    __block NSUInteger clipped = 0;
    [@"ab\r\ncd" enumerateSubstringsInRange:NSMakeRange(1, 4)
        options:NSStringEnumerationByLines | NSStringEnumerationSubstringNotRequired
        usingBlock:^(NSString *line, NSRange substring, NSRange enclosing, BOOL *stop) {
            require(line == nil, "substring not required");
            require(substring.location == (clipped ? 4 : 1) && substring.length == 1, "clipped substring range");
            require(enclosing.location == substring.location && enclosing.length == (clipped ? 1 : 3), "clipped enclosing range");
            ++clipped;
        }];
    require(clipped == 2, "clipped line count");
    __block NSUInteger count = 0;
    [@"éclair\r\nlast" enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        require([line isEqual:@"éclair"], "original Swift client first line");
        ++count;
        *stop = YES;
    }];
    require(count == 1, "stop after first line");
    NSUInteger start = 0, end = 0, contents = 0;
    [@"last" getLineStart:&start end:&end contentsEnd:&contents forRange:NSMakeRange(4, 0)];
    require(start == 0 && end == 4 && contents == 4, "bounds at end of unterminated line");
    NSArray *applications = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES);
    require([applications count] > 0 && [[applications objectAtIndex:0] isEqual:@"/Applications"], "local application search");
    NSArray *support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    require([support count] > 0 && [[support objectAtIndex:0] hasSuffix:@"/Library/Application Support"], "user support search");
    require([NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, 0, YES) count] == 0, "empty domain search");
    [pool drain];
    puts("lines-directories: passed");
    return 0;
}
