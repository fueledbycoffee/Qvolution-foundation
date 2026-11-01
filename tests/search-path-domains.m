#import <Foundation/Foundation.h>
#include <stdio.h>

// R2-F1: compare both Foundation entry points to the existing Libc enumerator.
extern unsigned int NSStartSearchPathEnumeration(NSSearchPathDirectory, NSSearchPathDomainMask);
extern unsigned int NSGetNextSearchPathEnumeration(unsigned int, char *);

int main(void)
{
    @autoreleasepool {
        NSSearchPathDomainMask masks[] = { NSUserDomainMask, NSLocalDomainMask,
            NSNetworkDomainMask, NSSystemDomainMask,
            NSUserDomainMask | NSLocalDomainMask | NSNetworkDomainMask | NSSystemDomainMask };
        const char *names[] = { "user", "local", "network", "system", "combined" };
        int failures = 0;
        for (int i = 0; i < 5; i++) {
            NSMutableArray *expected = [NSMutableArray array];
            unsigned int state = NSStartSearchPathEnumeration(NSLibraryDirectory, masks[i]);
            char path[4096];
            while ((state = NSGetNextSearchPathEnumeration(state, path))) {
                NSString *p = [NSString stringWithUTF8String:path];
                [expected addObject:[p stringByExpandingTildeInPath]];
            }
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, masks[i], YES);
            NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:masks[i]];
            NSMutableArray *urlPaths = [NSMutableArray array];
            for (NSURL *url in urls) [urlPaths addObject:[url path]];
            BOOL ok = [expected count] > 0 && [paths isEqual:expected] && [urlPaths isEqual:expected];
            printf("%s %s expected=%lu paths=%lu urls=%lu\n", ok ? "ok" : "FAIL", names[i],
                (unsigned long)[expected count], (unsigned long)[paths count], (unsigned long)[urls count]);
            failures += !ok;
        }
        printf("HARNESS done: 5 checks, %d failed\n", failures);
        return failures != 0;
    }
}
