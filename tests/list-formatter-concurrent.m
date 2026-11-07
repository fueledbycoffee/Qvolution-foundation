#import <Foundation/Foundation.h>
#include <pthread.h>
#include <assert.h>
#include <stdio.h>

static NSListFormatter *shared;
static NSString *expected;
static pthread_mutex_t gate = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t condition = PTHREAD_COND_INITIALIZER;
static int waiting, started, changeLocale, errors;
static void *worker(void *argument)
{
    @autoreleasepool {
        pthread_mutex_lock(&gate);
        waiting++;
        pthread_cond_broadcast(&condition);
        while (!started) pthread_cond_wait(&condition, &gate);
        pthread_mutex_unlock(&gate);
        for (int i = 0; i < 200; i++) {
            if (changeLocale && (long)argument == 0) {
                NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:i % 2 ? @"fr_FR" : @"en_US_POSIX"];
                shared.locale = locale;
#if !__has_feature(objc_arc)
                [locale release];
#endif
            } else {
                NSString *text = [shared stringFromItems:@[@"a", @"b", @"c"]];
                if (![text isEqualToString:expected] &&
                    !(changeLocale && [text isEqualToString:@"a, b et c"]))
                    __sync_fetch_and_add(&errors, 1);
            }
        }
    }
    return NULL;
}
int main(void)
{
    @autoreleasepool {
        NSString *locales[] = {@"en_US_POSIX", @"fr_FR", @"ja_JP", @"en_US_POSIX"};
        NSString *outputs[] = {@"a, b, and c", @"a, b et c", @"a、b、c", @"a, b, and c"};
        for (int pass = 0; pass < 4; pass++) {
            shared = [NSListFormatter new];
            NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:locales[pass]];
            shared.locale = locale;
#if !__has_feature(objc_arc)
            [locale release];
#endif
            expected = outputs[pass];
            waiting = started = errors = 0;
            changeLocale = pass == 3;
            pthread_t threads[8];
            for (long i = 0; i < 8; i++) assert(!pthread_create(&threads[i], NULL, worker, (void *)i));
            pthread_mutex_lock(&gate);
            while (waiting < 8) pthread_cond_wait(&condition, &gate);
            started = 1;
            pthread_cond_broadcast(&condition);
            pthread_mutex_unlock(&gate);
            for (int i = 0; i < 8; i++) assert(!pthread_join(threads[i], NULL));
            printf("NSListFormatter.concurrent(%d): %s\n", pass, errors ? "FAIL" : "PASS");
            assert(!errors);
#if !__has_feature(objc_arc)
            [shared release];
#endif
        }
    }
    return 0;
}
