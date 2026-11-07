static NSListFormatter *shared;
static NSArray *items;
static int badResults;
static void *raceWorker(void *index)
{
    raceThread = (int)(long)index;
    if (raceThread == 2 && mutation) {
        shared.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"fr_FR"];
    } else {
        NSString *result = [shared stringFromItems:items];
        if (![result isEqualToString:@"a and b"]) __sync_fetch_and_add(&badResults, 1);
    }
    return NULL;
}
int main(void)
{
    items = @[@"a", @"b"];
    int failures = 0;
    for (mutation = 0; mutation < 2; ++mutation) {
        ready = secondOpen = secondLockAttempt = active = closedWhileActive = badResults = 0;
        activeFormatter = NULL;
        shared = [NSListFormatter new];
        shared.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        if (mutation) assert([[shared stringFromItems:items] isEqualToString:@"a and b"]);
        pthread_t a, b;
        assert(!pthread_create(&a, NULL, raceWorker, (void *)1));
        pthread_mutex_lock(&raceLock);
        while (!ready) pthread_cond_wait(&raceCond, &raceLock);
        pthread_mutex_unlock(&raceLock);
        assert(!pthread_create(&b, NULL, raceWorker, (void *)2));
        assert(!pthread_join(a, NULL));
        assert(!pthread_join(b, NULL));
        if (mutation && ![[shared stringFromItems:items] isEqualToString:@"a et b"]) badResults++;
        printf("%s: closedWhileActive=%d badResults=%d\n",
               mutation ? "locale invalidation" : "cold cache publication", closedWhileActive, badResults);
        failures += closedWhileActive + badResults;
        [shared dealloc];
    }
    return failures ? 1 : 0;
}
