/* Execute verbatim production methods with controlled CF/dispatch/notification
 * dependencies. This is a native reentry regression, not a full Foundation run. */
#include <objc/runtime.h>
#include <assert.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
- (id)init;
- (void)release;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self, 0); }
- (id)init { return self; }
- (void)release { object_dispose(self); }
@end
__attribute__((objc_root_class))
@interface NSString { Class isa; const char *text; unsigned int length; }
- (BOOL)isEqualToString:(NSString *)other;
@end
@implementation NSString
- (BOOL)isEqualToString:(NSString *)other { return other && !strcmp(text, other->text); }
@end
@class NSArray;
@interface NSLocale : NSObject
+ (NSArray *)preferredLanguages;
+ (id)systemLocale;
- (NSString *)languageCode;
@end
@implementation NSLocale
+ (NSArray *)preferredLanguages { return (NSArray *)@"preferred-languages"; }
+ (id)systemLocale { static NSLocale *locale; if (!locale) locale = [self alloc]; return locale; }
- (NSString *)languageCode { return @"en"; }
@end

static pthread_mutex_t defaultsLock = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t storageLock = PTHREAD_MUTEX_INITIALIZER;
static _Thread_local int queueDepth, changeDepth, inSetter, nested;
static int synchronizeQueue;
static void dispatch_sync(int queue, void (^block)(void)) {
    (void)queue;
    assert(!queueDepth);
    pthread_mutex_lock(&storageLock);
    ++queueDepth;
    block();
    --queueDepth;
    pthread_mutex_unlock(&storageLock);
}
typedef NSString *CFStringRef;
typedef id CFTypeRef;
static CFStringRef kCFPreferencesCurrentApplication = @"application";
static NSString *keys[16];
static id values[16];
static unsigned keyCount;
static void CFPreferencesSetAppValue(CFStringRef key, CFTypeRef value, CFStringRef app) {
    assert(queueDepth == 1 && app == kCFPreferencesCurrentApplication);
    unsigned i = 0;
    while (i < keyCount && ![keys[i] isEqualToString:key]) ++i;
    assert(i < 16);
    if (i == keyCount) keys[keyCount++] = key;
    values[i] = value;
}
static id storedValue(NSString *key) {
    __block id value = nil;
    dispatch_sync(synchronizeQueue, ^{
        for (unsigned i = 0; i < keyCount; ++i)
            if ([keys[i] isEqualToString:key]) value = values[i];
    });
    return value;
}
static BOOL NSIsPlistType(id value) { return YES; }
#define NSLog(...) abort()
#define APP_NAME (self->_suiteName != nil ? (CFStringRef)self->_suiteName : kCFPreferencesCurrentApplication)

@interface NSUserDefaults : NSObject { @public NSString *_suiteName; }
+ (id)standardUserDefaults;
+ (void)resetStandardUserDefaults;
- (void)setObject:(id)value forKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;
- (id)objectForKey:(NSString *)key;
- (void)willChangeValueForKey:(NSString *)key;
- (void)didChangeValueForKey:(NSString *)key;
@end
static NSUserDefaults *standardDefaults;
static NSString *NSUserDefaultsDidChangeNotification = @"defaults-changed";
static void changed(NSUserDefaults *sender);
@interface NSNotificationCenter : NSObject
+ (id)defaultCenter;
- (void)postNotificationName:(NSString *)name object:(id)sender userInfo:(id)info;
@end
@implementation NSNotificationCenter
+ (id)defaultCenter { static id center; if (!center) center = [self alloc]; return center; }
- (void)postNotificationName:(NSString *)name object:(id)sender userInfo:(id)info {
    assert(name == NSUserDefaultsDidChangeNotification && info == nil);
    changed(sender);
}
@end
@implementation NSUserDefaults
#include "defaults-init-methods.inc"
- (id)objectForKey:(NSString *)key { return storedValue(key); }
- (void)willChangeValueForKey:(NSString *)key { ++changeDepth; }
- (void)didChangeValueForKey:(NSString *)key { assert(changeDepth > 0); --changeDepth; }
@end

static int observing, setup, notifications, checkValue, writeNested;
static pthread_t settingThread;
static NSString *expectedKey;
static id expectedValue;
static void changed(NSUserDefaults *sender) {
    if (!observing) return;
    ++notifications;
    /* The reviewer reproducer: this must return even on first access/reset. */
    assert([NSUserDefaults standardUserDefaults] == sender);
    assert(!setup && !queueDepth && !changeDepth);
    assert(inSetter && pthread_equal(pthread_self(), settingThread));
    assert(pthread_mutex_trylock(&defaultsLock) == 0);
    pthread_mutex_unlock(&defaultsLock);
    if (checkValue && !nested) assert([sender objectForKey:expectedKey] == expectedValue);
    if (writeNested && !nested) {
        nested = 1;
        [sender setObject:@"nested-value" forKey:@"nested-key"];
        nested = 0;
        assert([[sender objectForKey:@"nested-key"] isEqualToString:@"nested-value"]);
    }
}
static void watchdog(int sig) {
    static const char message[] = "FAIL: singleton observer reentry did not return\n";
    (void)sig;
    write(STDERR_FILENO, message, sizeof(message) - 1);
    _exit(124);
}
static void checkSeeds(NSUserDefaults *defaults) {
    assert(defaults != nil);
    assert([defaults objectForKey:@"AppleLanguages"] == (id)[NSLocale preferredLanguages]);
    assert([defaults objectForKey:@"AppleLocale"] == [[NSLocale systemLocale] languageCode]);
}
static void initialization(BOOL reset) {
    if (reset) {
        checkSeeds([NSUserDefaults standardUserDefaults]);
        [NSUserDefaults resetStandardUserDefaults];
    }
    observing = setup = 1;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    setup = 0;
    checkSeeds(defaults);
    assert(notifications == 0);
    assert([NSUserDefaults standardUserDefaults] == defaults);
    puts("PASS: setup has no callbacks; initialized singleton and seeds are available");
}
static void setValue(NSUserDefaults *defaults, NSString *key, id value) {
    expectedKey = key;
    expectedValue = value;
    int before = notifications;
    inSetter = 1;
    if (value) [defaults setObject:value forKey:key];
    else [defaults removeObjectForKey:key];
    inSetter = 0;
    assert(notifications == before + (writeNested ? 2 : 1));
    assert([defaults objectForKey:key] == value);
}
static void *ordinaryChanges(void *context) {
    NSUserDefaults *defaults = context;
    settingThread = pthread_self();
    observing = checkValue = 1;
    /* Original defaults-change-thread.m setter scenarios, then removal. */
    setValue(defaults, @"QVLiveA", @"one");
    setValue(defaults, @"QVLiveA", @"two");
    setValue(defaults, @"QVLiveA", @"two");
    setValue(defaults, @"QVLiveB", @"other");
    setValue(defaults, @"QVLiveB", nil);
    writeNested = 1;
    setValue(defaults, @"QVLiveA", @"reentry");
    return NULL;
}
int main(int argc, char **argv) {
    assert(argc == 2);
    signal(SIGALRM, watchdog);
    alarm(3);
    if (!strcmp(argv[1], "initial")) initialization(NO);
    else if (!strcmp(argv[1], "reset")) initialization(YES);
    else {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (!strcmp(argv[1], "main")) ordinaryChanges(defaults);
        else {
            assert(!strcmp(argv[1], "background"));
            pthread_t thread;
            assert(pthread_create(&thread, NULL, ordinaryChanges, defaults) == 0);
            assert(pthread_join(thread, NULL) == 0);
        }
        assert(notifications == 7);
        puts("PASS: setters/removal notify synchronously on setting thread after storage/KVO; observer reads/writes reenter");
    }
    alarm(0);
    return 0;
}
