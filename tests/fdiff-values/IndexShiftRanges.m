#import <Foundation/Foundation.h>
#include <stdio.h>

static NSUInteger additions;
@interface CountedIndexSet : NSMutableIndexSet @end
@implementation CountedIndexSet
- (void)addIndex:(NSUInteger)index { additions++; [super addIndex:index]; }
@end

static void dense(NSUInteger length)
{
    CountedIndexSet *set = [[CountedIndexSet alloc] init];
    [set addIndexesInRange:NSMakeRange(0, length)];
    [set addIndexesInRange:NSMakeRange(2 * length, length)];
    (void)[set count]; // Populate any lazy cache before mutation.
    additions = 0;
    [set shiftIndexesStartingAtIndex:0 by:1];
    __block NSUInteger ordinal = 0;
    __block BOOL correct = YES;
    [set enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
        correct &= ordinal < 2 && range.location == 2 * length * ordinal + 1 && range.length == length;
        ordinal++;
    }];
    printf("Shift.dense(%lu).correct: %d\n", (unsigned long)length,
           correct && ordinal == 2 && [set count] == 2 * length);
    printf("Shift.dense(%lu).individualAdditions: %lu\n", (unsigned long)length, (unsigned long)additions);
}

int main(void)
{
    @autoreleasepool {
        dense(10000);
        dense(1000000000);
        CountedIndexSet *set = [[CountedIndexSet alloc] init];
        for (NSUInteger i = 0; i < 4096; i++) [set addIndex:3 * i];
        (void)[set count];
        additions = 0;
        [set shiftIndexesStartingAtIndex:0 by:1];
        __block NSUInteger ordinal = 0;
        __block BOOL correct = YES;
        [set enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
            correct &= range.location == 3 * ordinal + 1 && range.length == 1;
            ordinal++;
        }];
        printf("Shift.fragmented.correct: %d\n", correct && ordinal == 4096 && [set count] == 4096);
        printf("Shift.fragmented.individualAdditions: %lu\n", (unsigned long)additions);
        [set shiftIndexesStartingAtIndex:0 by:-1];
        printf("Shift.fragmented.roundtrip: %d\n", [set firstIndex] == 0 && [set lastIndex] == 3 * 4095 && [set count] == 4096);
        [set removeAllIndexes];
        [set addIndexesInRange:NSMakeRange(1, 3)];
        [set addIndexesInRange:NSMakeRange(7, 2)];
        (void)[set count];
        [set shiftIndexesStartingAtIndex:7 by:-3];
        printf("Shift.merge.single: %d\n", [set isEqualToIndexSet:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 5)]] && [set count] == 5);
        [set shiftIndexesStartingAtIndex:0 by:-20];
        printf("Shift.empty.count: %lu\n", (unsigned long)[set count]);
    }
    return 0;
}
