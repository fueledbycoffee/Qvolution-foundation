// Internal file operations report conversion failure through their normal error path.
// Public NSString/NSFileManager conversion methods retain their exception contract.
#import <CoreFoundation/CFString.h>
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#include <errno.h>
#include <stdlib.h>

static const char *NSFileSystemRepresentation(NSString *path)
{
    if (path == nil || [path length] == 0)
    {
        errno = ENOENT;
        return NULL;
    }
    CFIndex capacity = CFStringGetMaximumSizeOfFileSystemRepresentation((CFStringRef)path);
    if (capacity <= 0)
    {
        errno = EILSEQ;
        return NULL;
    }
    char *buffer = malloc(capacity);
    if (buffer == NULL)
    {
        errno = ENOMEM;
        return NULL;
    }
    if (!CFStringGetFileSystemRepresentation((CFStringRef)path, buffer, capacity))
    {
        free(buffer);
        errno = EILSEQ;
        return NULL;
    }
    return [[NSData dataWithBytesNoCopy:buffer length:capacity] bytes];
}
