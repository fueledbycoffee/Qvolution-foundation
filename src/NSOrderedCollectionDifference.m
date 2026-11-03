#import <Foundation/NSOrderedCollectionDifference.h>
#import <Foundation/NSOrderedSet.h>
#import <Foundation/NSIndexSet.h>
#import <Foundation/NSException.h>
#include <stdint.h>
#include <stdlib.h>

@implementation NSOrderedCollectionChange
@synthesize object = _object, changeType = _changeType, index = _index, associatedIndex = _associatedIndex;
+ (instancetype)changeWithObject:(id)object type:(NSCollectionChangeType)type index:(NSUInteger)index {
    return [[[self alloc] initWithObject:object type:type index:index] autorelease];
}
+ (instancetype)changeWithObject:(id)object type:(NSCollectionChangeType)type index:(NSUInteger)index associatedIndex:(NSUInteger)associatedIndex {
    return [[[self alloc] initWithObject:object type:type index:index associatedIndex:associatedIndex] autorelease];
}
- (instancetype)initWithObject:(id)object type:(NSCollectionChangeType)type index:(NSUInteger)index {
    return [self initWithObject:object type:type index:index associatedIndex:NSNotFound];
}
- (instancetype)initWithObject:(id)object type:(NSCollectionChangeType)type index:(NSUInteger)index associatedIndex:(NSUInteger)associatedIndex {
    if ((self = [super init])) {
        if ((type != NSCollectionChangeInsert && type != NSCollectionChangeRemove) || index == NSNotFound) {
            [self release];
            [NSException raise:NSInvalidArgumentException format:@"Invalid ordered collection change"];
        }
        _object = [object retain];
        _changeType = type;
        _index = index;
        _associatedIndex = associatedIndex;
    }
    return self;
}
- (void)dealloc {
    [_object release];
    [super dealloc];
}
@end

static NSOrderedCollectionChange *changeAtIndex(NSArray *changes, NSUInteger index) {
    NSUInteger lo = 0, hi = [changes count];
    while (lo < hi) {
        NSUInteger mid = lo + (hi - lo) / 2;
        NSOrderedCollectionChange *change = [changes objectAtIndex:mid];
        if ([change index] < index) lo = mid + 1;
        else hi = mid;
    }
    if (lo < [changes count] && [[changes objectAtIndex:lo] index] == index)
        return [changes objectAtIndex:lo];
    return nil;
}

@implementation NSOrderedCollectionDifference
@synthesize insertions = _insertions, removals = _removals;
- (instancetype)init { return [self initWithChanges:[NSArray array]]; }
- (instancetype)initWithChanges:(NSArray *)changes {
    if (!(self = [super init])) return nil;
    @try {
        NSMutableArray *insertions = [NSMutableArray array], *removals = [NSMutableArray array];
        for (NSOrderedCollectionChange *change in changes) {
            if (![change isKindOfClass:[NSOrderedCollectionChange class]])
                [NSException raise:NSInvalidArgumentException format:@"Expected an ordered collection change"];
            [[change changeType] == NSCollectionChangeInsert ? insertions : removals addObject:change];
        }
        NSComparator byIndex = ^NSComparisonResult(NSOrderedCollectionChange *a, NSOrderedCollectionChange *b) {
            return [a index] < [b index] ? NSOrderedAscending : [a index] > [b index] ? NSOrderedDescending : NSOrderedSame;
        };
        _insertions = [[insertions sortedArrayUsingComparator:byIndex] copy];
        _removals = [[removals sortedArrayUsingComparator:byIndex] copy];
        for (NSUInteger type = 0; type < 2; type++) {
            NSArray *side = type == 0 ? _insertions : _removals;
            NSArray *opposite = type == 0 ? _removals : _insertions;
            NSUInteger previous = NSNotFound;
            for (NSOrderedCollectionChange *change in side) {
                if ([change index] == previous)
                    [NSException raise:NSInvalidArgumentException format:@"Duplicate change index"];
                previous = [change index];
                if ([change associatedIndex] != NSNotFound) {
                    NSOrderedCollectionChange *partner = changeAtIndex(opposite, [change associatedIndex]);
                    if (!partner || [partner associatedIndex] != [change index])
                        [NSException raise:NSInvalidArgumentException format:@"Nonreciprocal move association"];
                }
            }
        }
        NSMutableArray *ordered = [NSMutableArray array];
        for (NSUInteger i = [_removals count]; i > 0; i--) [ordered addObject:[_removals objectAtIndex:i - 1]];
        [ordered addObjectsFromArray:_insertions];
        _changes = [ordered copy];
    } @catch (id exception) {
        [self release];
        @throw;
    }
    return self;
}
- (instancetype)initWithInsertIndexes:(NSIndexSet *)inserts insertedObjects:(NSArray *)insertedObjects removeIndexes:(NSIndexSet *)removes removedObjects:(NSArray *)removedObjects {
    return [self initWithInsertIndexes:inserts insertedObjects:insertedObjects removeIndexes:removes removedObjects:removedObjects additionalChanges:[NSArray array]];
}
- (instancetype)initWithInsertIndexes:(NSIndexSet *)inserts insertedObjects:(NSArray *)insertedObjects removeIndexes:(NSIndexSet *)removes removedObjects:(NSArray *)removedObjects additionalChanges:(NSArray *)changes {
    if ((insertedObjects && [insertedObjects count] != [inserts count]) || (removedObjects && [removedObjects count] != [removes count])) {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"Object and index counts differ"];
    }
    NSMutableArray *all = [NSMutableArray arrayWithArray:changes];
    for (NSUInteger type = 0; type < 2; type++) {
        NSIndexSet *indexes = type == 0 ? inserts : removes;
        NSArray *objects = type == 0 ? insertedObjects : removedObjects;
        NSUInteger position = 0;
        for (NSUInteger i = indexes ? [indexes firstIndex] : NSNotFound; i != NSNotFound; i = [indexes indexGreaterThanIndex:i]) {
            [all addObject:[NSOrderedCollectionChange changeWithObject:objects ? [objects objectAtIndex:position] : nil type:type index:i]];
            position++;
        }
    }
    return [self initWithChanges:all];
}
- (BOOL)hasChanges { return [_changes count] != 0; }
- (instancetype)inverseDifference {
    NSMutableArray *changes = [NSMutableArray array];
    for (NSOrderedCollectionChange *change in _changes)
        [changes addObject:[NSOrderedCollectionChange changeWithObject:[change object] type:[change changeType] == NSCollectionChangeInsert ? NSCollectionChangeRemove : NSCollectionChangeInsert index:[change index] associatedIndex:[change associatedIndex]]];
    return [[[[self class] alloc] initWithChanges:changes] autorelease];
}
- (NSOrderedCollectionDifference *)differenceByTransformingChangesWithBlock:(NSOrderedCollectionChange *(^)(NSOrderedCollectionChange *))block {
    if (!block) [NSException raise:NSInvalidArgumentException format:@"Missing change transformation"];
    NSMutableArray *changes = [NSMutableArray array];
    for (NSOrderedCollectionChange *change in _changes) {
        NSOrderedCollectionChange *mapped = block(change);
        if (mapped) [changes addObject:mapped];
    }
    return [[[NSOrderedCollectionDifference alloc] initWithChanges:changes] autorelease];
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)buffer count:(NSUInteger)count {
    return [_changes countByEnumeratingWithState:state objects:buffer count:count];
}
- (void)dealloc {
    [_insertions release];
    [_removals release];
    [_changes release];
    [super dealloc];
}
@end

static void *differenceBuffer(NSUInteger count, size_t size) {
    void *buffer = count <= SIZE_MAX / size ? calloc(count ? count : 1, size) : NULL;
    if (!buffer) [NSException raise:NSMallocException format:@"Ordered collection difference is too large"];
    return buffer;
}

@implementation NSOrderedSet (NSOrderedCollectionDifference)
- (NSOrderedCollectionDifference *)differenceFromOrderedSet:(NSOrderedSet *)other {
    return [self differenceFromOrderedSet:other withOptions:0];
}
- (NSOrderedCollectionDifference *)differenceFromOrderedSet:(NSOrderedSet *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options {
    return [self differenceFromOrderedSet:other withOptions:options usingEquivalenceTest:nil];
}
- (NSOrderedCollectionDifference *)differenceFromOrderedSet:(NSOrderedSet *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options usingEquivalenceTest:(BOOL (^)(id, id))block {
    if (block && (options & NSOrderedCollectionDifferenceCalculationInferMoves))
        [NSException raise:NSInvalidArgumentException format:@"Move inference cannot use custom equivalence"];
    NSUInteger n = [other count], m = [self count];
    BOOL *oldKept = NULL, *newKept = NULL;
    NSUInteger *tails = NULL, *previous = NULL, *positions = NULL, *lengths = NULL;
    @try {
        oldKept = differenceBuffer(n, sizeof(BOOL));
        newKept = differenceBuffer(m, sizeof(BOOL));
        if (!block) {
            tails = differenceBuffer(n, sizeof(NSUInteger));
            previous = differenceBuffer(n, sizeof(NSUInteger));
            positions = differenceBuffer(n, sizeof(NSUInteger));
            NSUInteger length = 0;
            for (NSUInteger i = 0; i < n; i++) {
                NSUInteger target = [self indexOfObject:[other objectAtIndex:i]];
                positions[i] = target;
                if (target == NSNotFound) continue;
                NSUInteger lo = 0, hi = length;
                while (lo < hi) {
                    NSUInteger mid = lo + (hi - lo) / 2;
                    if (positions[tails[mid]] < target) lo = mid + 1;
                    else hi = mid;
                }
                previous[i] = lo ? tails[lo - 1] : NSNotFound;
                tails[lo] = i;
                if (lo == length) length++;
            }
            for (NSUInteger i = length ? tails[length - 1] : NSNotFound; i != NSNotFound; i = previous[i]) {
                oldKept[i] = YES;
                newKept[positions[i]] = YES;
            }
        } else {
            if (n == NSUIntegerMax || m == NSUIntegerMax || n + 1 > NSUIntegerMax / (m + 1))
                [NSException raise:NSMallocException format:@"Ordered collection difference is too large"];
            NSUInteger width = m + 1;
            lengths = differenceBuffer((n + 1) * width, sizeof(NSUInteger));
            for (NSUInteger i = n; i > 0; i--) {
                for (NSUInteger j = m; j > 0; j--) {
                    NSUInteger a = lengths[i * width + j - 1], b = lengths[(i - 1) * width + j];
                    lengths[(i - 1) * width + j - 1] = block([other objectAtIndex:i - 1], [self objectAtIndex:j - 1]) ? 1 + lengths[i * width + j] : (a > b ? a : b);
                }
            }
            NSUInteger i = 0, j = 0;
            while (i < n && j < m) {
                if (block([other objectAtIndex:i], [self objectAtIndex:j])) {
                    oldKept[i++] = YES;
                    newKept[j++] = YES;
                } else if (lengths[(i + 1) * width + j] >= lengths[i * width + j + 1]) i++;
                else j++;
            }
        }
        NSMutableArray *changes = [NSMutableArray array];
        for (NSUInteger type = 0; type < 2; type++) {
            NSOrderedSet *set = type == 0 ? self : other;
            NSOrderedSet *opposite = type == 0 ? other : self;
            BOOL *kept = type == 0 ? newKept : oldKept;
            BOOL *oppositeKept = type == 0 ? oldKept : newKept;
            NSUInteger omit = type == 0 ? NSOrderedCollectionDifferenceCalculationOmitInsertedObjects : NSOrderedCollectionDifferenceCalculationOmitRemovedObjects;
            for (NSUInteger i = 0; i < [set count]; i++) {
                if (kept[i]) continue;
                id object = [set objectAtIndex:i];
                NSUInteger association = NSNotFound;
                if (options & NSOrderedCollectionDifferenceCalculationInferMoves) {
                    NSUInteger candidate = [opposite indexOfObject:object];
                    if (candidate != NSNotFound && !oppositeKept[candidate]) association = candidate;
                }
                [changes addObject:[NSOrderedCollectionChange changeWithObject:(options & omit) ? nil : object type:type index:i associatedIndex:association]];
            }
        }
        return [[[NSOrderedCollectionDifference alloc] initWithChanges:changes] autorelease];
    } @finally {
        free(oldKept); free(newKept); free(tails); free(previous); free(positions); free(lengths);
    }
}
- (NSOrderedSet *)orderedSetByApplyingDifference:(NSOrderedCollectionDifference *)difference {
    NSMutableArray *objects = [[self array] mutableCopy];
    @try {
        for (NSOrderedCollectionChange *change in [[difference removals] reverseObjectEnumerator]) {
            if ([change index] >= [objects count]) return nil;
            [objects removeObjectAtIndex:[change index]];
        }
        for (NSOrderedCollectionChange *change in [difference insertions]) {
            if ([change index] > [objects count] || ![change object]) return nil;
            [objects insertObject:[change object] atIndex:[change index]];
        }
        NSOrderedSet *result = [NSOrderedSet orderedSetWithArray:objects];
        return [result count] == [objects count] ? result : nil;
    } @finally {
        [objects release];
    }
}
@end
