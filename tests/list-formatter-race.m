/* Adapted from rev-g11-b/run-list-race.py: schedule calls at our ICU boundary.
 * Linker wrapping observes lock attempts so a protected cache needs no timeout. */
#include <pthread.h>
#include <unicode/ulistformatter.h>
static UListFormatter *(*realOpen)(const char *, UErrorCode *) = ulistfmt_open;
static void (*realClose)(UListFormatter *) = ulistfmt_close;
static int32_t (*realFormat)(const UListFormatter *, const UChar *const[], const int32_t[], int32_t, UChar *, int32_t, UErrorCode *) = ulistfmt_format;
static pthread_mutex_t raceLock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t raceCond = PTHREAD_COND_INITIALIZER;
static int ready, secondOpen, secondLockAttempt, active, closedWhileActive, mutation;
static const UListFormatter *activeFormatter;
static __thread int raceThread;
int __real_objc_sync_enter(id object);
int __wrap_objc_sync_enter(id object)
{
    pthread_mutex_lock(&raceLock);
    if (raceThread == 2 && ready) {
        secondLockAttempt = 1;
        pthread_cond_broadcast(&raceCond);
    }
    pthread_mutex_unlock(&raceLock);
    return __real_objc_sync_enter(object);
}
static UListFormatter *raceOpen(const char *locale, UErrorCode *status)
{
    UListFormatter *result = realOpen(locale, status);
    pthread_mutex_lock(&raceLock);
    if (raceThread == 1 && !mutation) {
        ready = 1;
        pthread_cond_broadcast(&raceCond);
        while (!secondOpen && !secondLockAttempt) pthread_cond_wait(&raceCond, &raceLock);
    } else if (raceThread == 2 && !mutation) {
        secondOpen = 1;
        pthread_cond_broadcast(&raceCond);
        while (!active) pthread_cond_wait(&raceCond, &raceLock);
    }
    pthread_mutex_unlock(&raceLock);
    return result;
}
static void raceClose(UListFormatter *formatter)
{
    pthread_mutex_lock(&raceLock);
    if (formatter && formatter == activeFormatter && active) {
        closedWhileActive++;
        pthread_cond_broadcast(&raceCond);
        // Record the invalid close without deliberately dereferencing freed ICU data.
        pthread_mutex_unlock(&raceLock);
        return;
    }
    pthread_mutex_unlock(&raceLock);
    realClose(formatter);
}
static int32_t raceFormat(const UListFormatter *formatter, const UChar *const strings[],
                         const int32_t lengths[], int32_t count, UChar *result,
                         int32_t capacity, UErrorCode *status)
{
    if (raceThread == 1) {
        pthread_mutex_lock(&raceLock);
        activeFormatter = formatter;
        active = ready = 1;
        pthread_cond_broadcast(&raceCond);
        while (!closedWhileActive && !secondLockAttempt) pthread_cond_wait(&raceCond, &raceLock);
        active = 0;
        int invalid = closedWhileActive;
        pthread_mutex_unlock(&raceLock);
        if (invalid) { *status = U_ILLEGAL_ARGUMENT_ERROR; return 0; }
    }
    return realFormat(formatter, strings, lengths, count, result, capacity, status);
}
#undef ulistfmt_open
#undef ulistfmt_close
#undef ulistfmt_format
#define ulistfmt_open raceOpen
#define ulistfmt_close raceClose
#define ulistfmt_format raceFormat
