// Differential check (qv-diff): NSIndexSet neighbour queries on small sets built with addIndex:/addIndexesInRange:.
// Results are printed as numbers, NSNotFound as "NF". One fact per line.   qv-diff <lane> indexset-neighbours.m -fno-objc-arc
#import <Foundation/Foundation.h>

static const char *v(NSUInteger x) {
    static char buf[8][32]; static int slot;
    char *b = buf[slot++ & 7];
    if (x == NSNotFound) snprintf(b, 32, "NF"); else snprintf(b, 32, "%lu", (unsigned long)x);
    return b;
}

static void probe(const char *name, NSIndexSet *s) {
    printf("NSIndexSet(%s).count: %lu first=%s last=%s\n", name, (unsigned long)[s count], v([s firstIndex]), v([s lastIndex]));
    NSUInteger qs[] = {0, 1, 3, 4, 5, 6, 12, 20, 27, 28, 63, 64, NSNotFound};
    for (int i = 0; i < 13; i++) {
        NSUInteger q = qs[i];
        printf("NSIndexSet(%s).neighbours(%s): lt=%s le=%s gt=%s ge=%s contains=%d\n", name, v(q),
               v([s indexLessThanIndex: q]), v([s indexLessThanOrEqualToIndex: q]),
               v([s indexGreaterThanIndex: q]), v([s indexGreaterThanOrEqualToIndex: q]), [s containsIndex: q]);
    }
}

int main(void) {
    @autoreleasepool {
        NSMutableIndexSet *one = [NSMutableIndexSet new];
        [one addIndex: 12];
        probe("{12}", one);
        NSMutableIndexSet *zero = [NSMutableIndexSet new];
        [zero addIndex: 0];
        probe("{0}", zero);
        NSMutableIndexSet *two = [NSMutableIndexSet new];
        [two addIndex: 4]; [two addIndex: 28];
        probe("{4,28}", two);
        NSMutableIndexSet *range = [NSMutableIndexSet new];
        [range addIndexesInRange: NSMakeRange(3, 3)]; [range addIndex: 20];
        probe("{3-5,20}", range);
        NSMutableIndexSet *empty = [NSMutableIndexSet new];
        probe("{}", empty);
        NSIndexSet *made = [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(6, 1)];
        probe("[6]", made);
        NSMutableIndexSet *removed = [NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange(0, 64)];
        [removed removeIndexesInRange: NSMakeRange(1, 62)];
        probe("{0,63}", removed);
        printf("NSIndexSet.indexesPassingTest.count: %lu\n", (unsigned long)[[two indexesPassingTest: ^BOOL(NSUInteger i, BOOL *stop) { return i > 10; }] count]);
        __block NSMutableString *order = [NSMutableString string];
        [range enumerateIndexesWithOptions: NSEnumerationReverse usingBlock: ^(NSUInteger i, BOOL *stop) { [order appendFormat: @"%lu,", (unsigned long)i]; }];
        printf("NSIndexSet.enumerateReverse: %s\n", [order UTF8String]);
        NSUInteger buffer[8];
        struct { NSUInteger loc, len, max; } cases[] = {{0, 30, 8}, {0, 30, 2}, {4, 2, 8}, {30, 10, 8}, {0, 6, 3}, {6, 14, 8}};
        for (int c = 0; c < 6; c++) {
            NSRange r = NSMakeRange(cases[c].loc, cases[c].len);
            NSUInteger n = [range getIndexes: buffer maxCount: cases[c].max inIndexRange: &r];
            printf("NSIndexSet({3-5,20}).getIndexes(range %lu+%lu, max %lu): n=%lu first=%s last=%s rangeAfter=%lu,%lu\n",
                   (unsigned long)cases[c].loc, (unsigned long)cases[c].len, (unsigned long)cases[c].max, (unsigned long)n,
                   n ? v(buffer[0]) : "-", n ? v(buffer[n - 1]) : "-", (unsigned long)r.location, (unsigned long)r.length);
        }
        NSUInteger n = [two getIndexes: buffer maxCount: 8 inIndexRange: NULL];
        printf("NSIndexSet({4,28}).getIndexes(NULL range): n=%lu\n", (unsigned long)n);
    }
    return 0;
}
