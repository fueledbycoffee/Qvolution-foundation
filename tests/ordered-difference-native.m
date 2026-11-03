#ifdef BASELINE
int main(void) {
    if (![NSOrderedSet instancesRespondToSelector:@selector(differenceFromOrderedSet:)]) {
        puts("FAIL baseline: NSOrderedSet lacks differenceFromOrderedSet:"); return 1;
    }
    return 0;
}
#else
static BOOL same(NSArray *a, NSArray *b) {
    if([a count]!=[b count])return NO;
    for(NSUInteger i=0;i<[a count];i++)if(![[a objectAtIndex:i]isEqual:[b objectAtIndex:i]])return NO;
    return YES;
}
static void check(NSArray *a, NSArray *b, NSArray *removed, NSArray *inserted) {
    NSOrderedSet *old=[NSOrderedSet orderedSetWithArray:a], *new=[NSOrderedSet orderedSetWithArray:b];
    NSOrderedCollectionDifference *d=[new differenceFromOrderedSet:old];
    assert([d hasChanges]==([removed count]+[inserted count]!=0));
    assert([[d removals]count]==[removed count]&&[[d insertions]count]==[inserted count]);
    for(NSUInteger side=0;side<2;side++){
        NSArray *changes=side?[d removals]:[d insertions], *expected=side?removed:inserted;
        for(NSUInteger i=0;i<[changes count];i++){
            NSOrderedCollectionChange *c=[changes objectAtIndex:i];
            assert([c changeType]==side&&[c associatedIndex]==NSNotFound);
            assert([[c object]isEqual:[expected objectAtIndex:i]]);
            assert([[side?a:b objectAtIndex:[c index]]isEqual:[c object]]);
        }
    }
    assert(same([[old orderedSetByApplyingDifference:d]array],b));
    assert(same([[new orderedSetByApplyingDifference:[d inverseDifference]]array],a));
    NSOrderedCollectionDifference *moves=[new differenceFromOrderedSet:old withOptions:NSOrderedCollectionDifferenceCalculationInferMoves];
    assert(same([[old orderedSetByApplyingDifference:moves]array],b));
    for(NSOrderedCollectionChange *c in [moves removals]) if([c associatedIndex]!=NSNotFound){
        NSOrderedCollectionChange *partner=changeAtIndex([moves insertions],[c associatedIndex]);
        assert(partner&&[partner associatedIndex]==[c index]&&[[partner object]isEqual:[c object]]);
    }
    NSUInteger total=0, previous=NSNotFound;BOOL inserting=NO;
    for(NSOrderedCollectionChange *c in d){
        if([c changeType]==NSCollectionChangeInsert){if(!inserting){previous=0;inserting=YES;}assert([c index]>=previous);}
        else {assert(!inserting&&[c index]<previous);}
        previous=[c index];total++;
    }
    assert(total==[removed count]+[inserted count]);
}
#define THROWS(...) do{BOOL caught=NO;@try{__VA_ARGS__;}@catch(id e){caught=YES;}assert(caught);}while(0)
static int duplicateInsertion(void) {
    NSOrderedSet *original=[NSOrderedSet orderedSetWithArray:@[@"a",@"b"]];
    NSOrderedCollectionChange *insert=[NSOrderedCollectionChange changeWithObject:@"b" type:NSCollectionChangeInsert index:1];
    NSOrderedCollectionDifference *difference=[[[NSOrderedCollectionDifference alloc]initWithChanges:@[insert]]autorelease];
    NSOrderedSet *result=[original orderedSetByApplyingDifference:difference];
    if (!result || !same([result array],@[@"a",@"b"]) || !same([original array],@[@"a",@"b"])) {
        puts("FAIL: applying a duplicate insertion must return the deduplicated ordered set");
        return 1;
    }
    puts("PASS: duplicate insertion preserves ordered elements and the receiver");
    return 0;
}
static int nilTransformation(void) {
    NSOrderedCollectionChange *remove=[NSOrderedCollectionChange changeWithObject:@"x" type:NSCollectionChangeRemove index:0];
    NSOrderedCollectionDifference *difference=[[[NSOrderedCollectionDifference alloc]initWithChanges:@[remove]]autorelease];
    BOOL omit=[difference hasChanges];
    id (^transform)(NSOrderedCollectionChange *)=^id(NSOrderedCollectionChange *change) { return omit ? nil : change; };
    @try {
        [difference differenceByTransformingChangesWithBlock:transform];
    } @catch (NSException *exception) {
        if ([[exception name]isEqual:NSInvalidArgumentException] && [difference hasChanges]) {
            puts("PASS: nil transformed change raises NSInvalidArgumentException");
            return 0;
        }
    }
    puts("FAIL: nil transformed change must raise NSInvalidArgumentException");
    return 1;
}
int main(int argc, const char **argv) {
    if (argc>1 && !strcmp(argv[1],"duplicate-insertion")) return duplicateInsertion();
    if (argc>1 && !strcmp(argv[1],"nil-transformation")) return nilTransformation();
    assert(duplicateInsertion()==0);
    assert(nilTransformation()==0);
    check(@[],@[],@[],@[]);
    check(@[],@[@"a"],@[],@[@"a"]);
    check(@[@"a"],@[],@[@"a"],@[]);
    check(@[@"a"],@[@"a"],@[],@[]);
    check(@[@"a",@"b"],@[@"b",@"a"],@[@"a"],@[@"a"]);
    check(@[@"a",@"b",@"c"],@[@"a",@"c",@"d"],@[@"b"],@[@"d"]);
    check(@[@"é",@"😀"],@[@"😀",@"x",@"é"],@[@"é"],@[@"x",@"é"]);
    check(@[@"a",@"b",@"c"],@[@"c",@"b",@"a"],@[@"a",@"b"],@[@"b",@"a"]);
    NSOrderedSet *a=[NSOrderedSet orderedSetWithArray:@[@"a",@"b"]],*b=[NSOrderedSet orderedSetWithArray:@[@"b",@"c"]];
    NSOrderedCollectionDifference *omitted=[b differenceFromOrderedSet:a withOptions:NSOrderedCollectionDifferenceCalculationOmitInsertedObjects|NSOrderedCollectionDifferenceCalculationOmitRemovedObjects];
    assert(![[[omitted insertions]objectAtIndex:0]object]&&![[[omitted removals]objectAtIndex:0]object]);
    NSOrderedCollectionDifference *custom=[b differenceFromOrderedSet:a withOptions:0 usingEquivalenceTest:^BOOL(id x,id y){return YES;}];
    assert(![custom hasChanges]);
    custom=[b differenceFromOrderedSet:a withOptions:0 usingEquivalenceTest:^BOOL(id x,id y){return [x isEqual:y];}];
    assert(same([[a orderedSetByApplyingDifference:custom]array],[b array]));
    THROWS([b differenceFromOrderedSet:a withOptions:NSOrderedCollectionDifferenceCalculationInferMoves usingEquivalenceTest:^BOOL(id x,id y){return YES;}]);
    NSOrderedCollectionChange *ins=[NSOrderedCollectionChange changeWithObject:@"c" type:NSCollectionChangeInsert index:1];
    THROWS([[NSOrderedCollectionDifference alloc]initWithChanges:@[ins,ins]]);
    NSOrderedCollectionChange *broken=[NSOrderedCollectionChange changeWithObject:@"a" type:NSCollectionChangeRemove index:0 associatedIndex:1];
    THROWS([[NSOrderedCollectionDifference alloc]initWithChanges:@[broken,ins]]);
    THROWS([[NSOrderedCollectionChange alloc]initWithObject:nil type:3 index:0]);
    NSOrderedCollectionDifference *manual=[[[NSOrderedCollectionDifference alloc]initWithInsertIndexes:[NSIndexSet indexSetWithIndex:1] insertedObjects:@[@"c"] removeIndexes:[NSIndexSet indexSetWithIndex:0] removedObjects:nil]autorelease];
    assert(same([[a orderedSetByApplyingDifference:manual]array],[b array]));
    NSOrderedCollectionDifference *mapped=[manual differenceByTransformingChangesWithBlock:^id(NSOrderedCollectionChange *c){return [NSOrderedCollectionChange changeWithObject:[c changeType]==NSCollectionChangeInsert?@"d":[c object] type:[c changeType] index:[c index]];}];
    assert(same([[a orderedSetByApplyingDifference:mapped]array],@[@"b",@"d"]));
    NSOrderedCollectionDifference *bad=[[[NSOrderedCollectionDifference alloc]initWithChanges:@[[NSOrderedCollectionChange changeWithObject:@"x" type:NSCollectionChangeInsert index:99]]]autorelease];
    assert([a orderedSetByApplyingDifference:bad]==nil);
    /* Exhaustive unique subsets/permutations validate the default and custom paths. */
    id pool[]={@"a",@"b",@"c",@"d"};
    NSMutableArray *sets=[NSMutableArray array];
    for(unsigned mask=0;mask<256;mask++){
        NSMutableArray *v=[NSMutableArray array];unsigned x=mask;BOOL seen[4]={0};
        for(unsigned i=0;i<4;i++,x>>=2){unsigned k=x&3;if(!seen[k]){[v addObject:pool[k]];seen[k]=YES;}}
        [sets addObject:[NSOrderedSet orderedSetWithArray:v]];
    }
    for(NSOrderedSet *old in sets)for(NSOrderedSet *new in sets){
        NSOrderedCollectionDifference *d=[new differenceFromOrderedSet:old];
        assert(same([[old orderedSetByApplyingDifference:d]array],[new array]));
        assert(same([[new orderedSetByApplyingDifference:[d inverseDifference]]array],[old array]));
    }
    puts("PASS: eight macOS cases, inverse, moves, options, custom equivalence, constructors, validation, transforms, 65536 round trips");
    return 0;
}
#endif
