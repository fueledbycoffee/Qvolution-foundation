#import <Foundation/NSArray.h>
#import <Foundation/NSOrderedCollectionChange.h>

@class NSIndexSet;

typedef NS_OPTIONS(NSUInteger, NSOrderedCollectionDifferenceCalculationOptions) {
    NSOrderedCollectionDifferenceCalculationOmitInsertedObjects = 1 << 0,
    NSOrderedCollectionDifferenceCalculationOmitRemovedObjects = 1 << 1,
    NSOrderedCollectionDifferenceCalculationInferMoves = 1 << 2,
};

@interface NSOrderedCollectionDifference<__covariant ObjectType> : NSObject <NSFastEnumeration> {
@private
    NSArray *_insertions;
    NSArray *_removals;
    NSArray *_changes;
}
@property (readonly) BOOL hasChanges;
@property (readonly, strong) NSArray<NSOrderedCollectionChange<ObjectType> *> *insertions;
@property (readonly, strong) NSArray<NSOrderedCollectionChange<ObjectType> *> *removals;
- (instancetype)initWithChanges:(NSArray<NSOrderedCollectionChange<ObjectType> *> *)changes;
- (instancetype)initWithInsertIndexes:(NSIndexSet *)inserts insertedObjects:(nullable NSArray<ObjectType> *)insertedObjects removeIndexes:(NSIndexSet *)removes removedObjects:(nullable NSArray<ObjectType> *)removedObjects;
- (instancetype)initWithInsertIndexes:(NSIndexSet *)inserts insertedObjects:(nullable NSArray<ObjectType> *)insertedObjects removeIndexes:(NSIndexSet *)removes removedObjects:(nullable NSArray<ObjectType> *)removedObjects additionalChanges:(NSArray<NSOrderedCollectionChange<ObjectType> *> *)changes;
- (instancetype)inverseDifference;
- (NSOrderedCollectionDifference *)differenceByTransformingChangesWithBlock:(NSOrderedCollectionChange *(^)(NSOrderedCollectionChange *))block;
@end
