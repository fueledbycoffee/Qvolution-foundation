#import <Foundation/NSObject.h>

typedef NS_ENUM(NSInteger, NSCollectionChangeType) {
    NSCollectionChangeInsert = 0,
    NSCollectionChangeRemove = 1,
};

@interface NSOrderedCollectionChange<__covariant ObjectType> : NSObject {
@private
    id _object;
    NSCollectionChangeType _changeType;
    NSUInteger _index;
    NSUInteger _associatedIndex;
}
@property (readonly, strong, nullable) ObjectType object;
@property (readonly) NSCollectionChangeType changeType;
@property (readonly) NSUInteger index;
@property (readonly) NSUInteger associatedIndex;
+ (instancetype)changeWithObject:(nullable ObjectType)object type:(NSCollectionChangeType)type index:(NSUInteger)index;
+ (instancetype)changeWithObject:(nullable ObjectType)object type:(NSCollectionChangeType)type index:(NSUInteger)index associatedIndex:(NSUInteger)associatedIndex;
- (instancetype)initWithObject:(nullable ObjectType)object type:(NSCollectionChangeType)type index:(NSUInteger)index;
- (instancetype)initWithObject:(nullable ObjectType)object type:(NSCollectionChangeType)type index:(NSUInteger)index associatedIndex:(NSUInteger)associatedIndex;
@end
