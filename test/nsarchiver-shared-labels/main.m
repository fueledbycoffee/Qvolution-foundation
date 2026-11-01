// Typedstream reference labels: objects, C strings and classes are numbered from one
// sequence. The archive below holds two QVLeaf objects; the second names its class by a
// reference (label 1) and the outer object refers back to the second by label 3. Both
// labels resolve only if the class records took labels 1 and 2 of the same sequence the
// objects use (0 and 3). Shared class-name strings ("@", "QVLeaf", "NSObject") keep their
// own numbering.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static int failures;

static void expect(BOOL condition, const char *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", label);
    failures += !condition;
}

@interface QVLeaf : NSObject <NSCoding>
@property (retain) QVLeaf *child;
@property (retain) QVLeaf *sibling;
@end

@implementation QVLeaf

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_child];
    [coder encodeObject:_sibling];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
    {
        _child = [[coder decodeObject] retain];
        _sibling = [[coder decodeObject] retain];
    }
    return self;
}

- (void)dealloc
{
    [_child release];
    [_sibling release];
    [super dealloc];
}

@end

static const unsigned char archive[] = {
    0x04, 0x0b, 's', 't', 'r', 'e', 'a', 'm', 't', 'y', 'p', 'e', 'd', 0x81, 0xe8, 0x03,
    0x84, 0x01, '@',                                    // type "@" (string 0)
    0x84,                                               // new object, label 0
    0x84, 0x84, 0x06, 'Q', 'V', 'L', 'e', 'a', 'f', 0x00,  // new class QVLeaf, label 1
    0x84, 0x84, 0x08, 'N', 'S', 'O', 'b', 'j', 'e', 'c', 't', 0x00,  // new class NSObject, label 2
    0x85,                                               // NSObject has no superclass
    0x92, 0x84,                                         // child: "@", new object, label 3
    0x93,                                               // its class: reference to label 1
    0x92, 0x85, 0x92, 0x85,                             // its child and sibling: nil
    0x86,                                               // end of label 3
    0x92, 0x95,                                         // sibling: "@", reference to label 3
    0x86,                                               // end of label 0
};

int main(void)
{
    @autoreleasepool
    {
        NSData *data = [NSData dataWithBytes:archive length:sizeof(archive)];
        QVLeaf *root = nil;
        @try
        {
            root = [NSUnarchiver unarchiveObjectWithData:data];
        }
        @catch (NSException *e)
        {
            printf("exception %s\n", [[e name] UTF8String]);
        }
        expect([root isKindOfClass:[QVLeaf class]], "root decodes as QVLeaf");
        expect([root.child isKindOfClass:[QVLeaf class]], "class reference label 1 names QVLeaf");
        expect(root.child != nil && root.sibling == root.child, "object reference label 3 names the child");
        expect(root.child.child == nil && root.child.sibling == nil, "child fields decode as nil");

        QVLeaf *inner = [[QVLeaf new] autorelease];
        QVLeaf *outer = [[QVLeaf new] autorelease];
        outer.child = inner;
        outer.sibling = inner;
        NSData *written = [NSArchiver archivedDataWithRootObject:outer];
        expect(written.length == sizeof(archive) && memcmp(written.bytes, archive, sizeof(archive)) == 0,
               "NSArchiver writes the same labels");
        QVLeaf *again = [NSUnarchiver unarchiveObjectWithData:written];
        expect(again.child != nil && again.sibling == again.child, "round trip keeps the shared child");
    }
    printf("RESULT failures=%d\n", failures);
    return failures != 0;
}
