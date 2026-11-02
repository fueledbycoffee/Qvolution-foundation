//
//  NSNotification.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSNotification.h>
#import "NSNotificationInternal.h"
#import <Foundation/NSCoder.h>
#import <Foundation/NSPortCoder.h>
#import <Foundation/NSDictionary.h>
#import "NSObjectInternal.h"
#import <Foundation/NSSet.h>
#import <libkern/OSAtomic.h>

@implementation NSNotification

static NSString * const NSNameKey = @"NS.name";
static NSString * const NSObjectKey = @"NS.object";
static NSString * const NSUserInfoKey = @"NS.userinfo";

+ (id)allocWithZone:(NSZone *)zone
{
    if (self == [NSConcreteNotification class])
    {
        return [super allocWithZone:zone];
    }
    else
    {
        return [NSConcreteNotification allocWithZone:zone];
    }
}

- (id)initWithName:(NSString *)name object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    NSRequestConcreteImplementation();
    [self release];
    return nil;
}

- (NSString *)name
{
    NSRequestConcreteImplementation();
    return nil;
}

- (id)object
{
    NSRequestConcreteImplementation();
    return nil;
}

- (NSDictionary *)userInfo
{
    NSRequestConcreteImplementation();
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    NSString *name = [self name];
    id object = [self object];
    NSDictionary *userInfo = [self userInfo];

    if ([aCoder allowsKeyedCoding])
    {
        [aCoder encodeObject:name forKey:NSNameKey];
        [aCoder encodeObject:object forKey:NSObjectKey];
        [aCoder encodeObject:userInfo forKey:NSUserInfoKey];
    }
    else
    {
        [aCoder encodeObject:name];
        [aCoder encodeObject:object];
        [aCoder encodeObject:userInfo];
    }
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *name = nil;
    id object = nil;
    NSDictionary *userInfo = nil;

    if ([aDecoder allowsKeyedCoding])
    {
        name = [aDecoder decodeObjectForKey:NSNameKey];
        object = [aDecoder decodeObjectForKey:NSObjectKey];
        userInfo = [aDecoder decodeObjectForKey:NSUserInfoKey];
    }
    else
    {
        name = [aDecoder decodeObject];
        object = [aDecoder decodeObject];
        userInfo = [aDecoder decodeObject];
    }

    return [self initWithName:name object:object userInfo:userInfo];
}

- (Class)classForCoder
{
    return [NSNotification self];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[NSNotification alloc] initWithName:[self name] object:[self object] userInfo:[self userInfo]];
}

@end

@implementation NSNotification (NSNotificationCreation)

+ (id)notificationWithName:(NSString *)aName object:(id)anObject
{
    return [[[self alloc] initWithName:aName object:anObject userInfo:nil] autorelease];
}

+ (id)notificationWithName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    return [[[self alloc] initWithName:aName object:anObject userInfo:aUserInfo] autorelease];
}

@end

@implementation NSConcreteNotification

// Formerly a pool: recycle cleared name/object/userInfo and handed the same object to the
// next post even while an observer still held it, so a retained notification changed or
// emptied under its holder. NSNotification objects are immutable (Apple, NSNotification);
// these two remain only as allocation helpers for internal callers.
+ (id)newTempNotificationWithName:(NSString *)name object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    return [[NSConcreteNotification alloc] initWithName:name object:anObject userInfo:aUserInfo];
}

- (id)initWithName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    self = [super init];
    if (self)
    {
        if (aName == nil)
        {
            [self release];
            return nil;
        }
        name = [aName copy];
        object = [anObject retain];
        userInfo = [aUserInfo retain]; // Tests show that this is retained not copied! Bug?
    }
    return self;
}

- (void)dealloc
{
    [name release];
    [object release];
    [userInfo release];
    [super dealloc];
}

- (NSString *)name
{
    return name;
}

- (id)object
{
    return object;
}

- (NSDictionary *)userInfo
{
    return userInfo;
}

- (void)recycle
{
    [self release];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ {name: %@, object: %@, userInfo: %@}", [super description], name, object, userInfo];
}

@end

@implementation NSNotification (NSNotificationPortCoding)

- (id) replacementObjectForPortCoder: (NSPortCoder *) coder {
    return self;
}

@end
