// qv-diff check: change signals from NSUserDefaults for registration, set and removal: the
// did-change notification and KVO on the defaults object. Before the fix -registerDefaults: gave
// neither. Expected (macOS 12.7.6): notes>0 1 for every call; kvo 1 when the value changes, 0 when not.
#import <Foundation/Foundation.h>
@interface QVObs : NSObject @property NSInteger hits; @property BOOL lastNewNil; @end
@implementation QVObs
- (void)observeValueForKeyPath:(NSString *)kp ofObject:(id)o change:(NSDictionary *)c context:(void *)x {
    self.hits++; self.lastNewNil = c[NSKeyValueChangeNewKey] == nil || c[NSKeyValueChangeNewKey] == [NSNull null];
}
@end
static NSInteger notes;
int main(void) { @autoreleasepool {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *k = [NSString stringWithFormat:@"QVDS%d_K", getpid()];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:nil
        usingBlock:^(NSNotification *n) { notes++; }];
    QVObs *o = [QVObs new];
    [d addObserver:o forKeyPath:k options:NSKeyValueObservingOptionNew context:NULL];
    notes = 0; [d registerDefaults:@{k: @"A"}];
    printf("registerNew.notes>0: %d kvo: %ld newNil: %d\n", notes > 0, (long) o.hits, o.lastNewNil); o.hits = 0;
    notes = 0; [d registerDefaults:@{k: @"B"}];
    printf("registerChange.notes>0: %d kvo: %ld value=B: %d\n", notes > 0, (long) o.hits, [[d objectForKey:k] isEqual:@"B"]); o.hits = 0;
    notes = 0; [d registerDefaults:@{k: @"B"}];
    printf("registerSame.notes>0: %d kvo: %ld\n", notes > 0, (long) o.hits); o.hits = 0;
    notes = 0; [d setObject:@"C" forKey:k];
    printf("set.notes>0: %d kvo: %ld\n", notes > 0, (long) o.hits); o.hits = 0;
    notes = 0; [d removeObjectForKey:k];
    printf("remove.notes>0: %d kvo: %ld value=B: %d\n", notes > 0, (long) o.hits, [[d objectForKey:k] isEqual:@"B"]); o.hits = 0;
    [d removeObserver:o forKeyPath:k];
    // Shadowed keys: an application-domain value wins over any registration, equal or not.
    NSString *s1 = [k stringByAppendingString:@"_S1"], *s2 = [k stringByAppendingString:@"_S2"];
    [d registerDefaults:@{s1: @"A", s2: @"A"}];
    [d setObject:@"A" forKey:s1];
    [d setObject:@"Z" forKey:s2];
    [d addObserver:o forKeyPath:s1 options:NSKeyValueObservingOptionNew context:NULL];
    [d addObserver:o forKeyPath:s2 options:NSKeyValueObservingOptionNew context:NULL];
    o.hits = 0; notes = 0; [d registerDefaults:@{s1: @"B", s2: @"B"}];
    printf("shadowed.notes>0: %d kvo: %ld s1=A: %d s2=Z: %d\n", notes > 0, (long) o.hits,
           [[d objectForKey:s1] isEqual:@"A"], [[d objectForKey:s2] isEqual:@"Z"]);
    [d removeObserver:o forKeyPath:s1]; [d removeObserver:o forKeyPath:s2];
    [d removeObjectForKey:s1]; [d removeObjectForKey:s2];
} return 0; }
