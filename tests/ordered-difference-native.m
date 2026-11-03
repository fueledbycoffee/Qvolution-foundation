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
static NSUInteger equivalenceCalls;
static int customScaling(BOOL memoryOnly) {
    for (NSUInteger n=128;n<=512;n*=2) {
        NSMutableArray *values=[NSMutableArray array];
        for (NSUInteger i=0;i<n;i++) [values addObject:[NSObject new]];
        NSOrderedSet *set=[NSOrderedSet orderedSetWithArray:values];
        NSOrderedSet *other=[NSOrderedSet orderedSetWithArray:values];
        equivalenceCalls=0;fixtureDifferenceBytes=0;
        NSOrderedCollectionDifference *d=[set differenceFromOrderedSet:other withOptions:0 usingEquivalenceTest:^BOOL(id a,id b) {
            equivalenceCalls++;return memoryOnly ? NO : [a isEqual:b];
        }];
        assert([d hasChanges]==memoryOnly);
        printf("custom diff n=%lu calls=%lu allocatedBytes=%zu\n",n,equivalenceCalls,fixtureDifferenceBytes);
        if ((!memoryOnly && equivalenceCalls>2*n) || fixtureDifferenceBytes>32*(n+1)) {
            puts("FAIL: custom equivalence exceeds linear unchanged work or linear allocation bound");return 1;
        }
    }
    puts(memoryOnly ? "PASS: linear custom-equivalence storage for unrelated inputs" : "PASS: linear custom-equivalence storage and unchanged work");return 0;
}
static int applyScaling(void) {
    NSMutableArray *values=[NSMutableArray array], *expected=[NSMutableArray array], *changes=[NSMutableArray array];
    for (NSUInteger i=0;i<512;i++) {
        id object=[NSObject new];[values addObject:object];
        if (i%2) [expected addObject:object];
        else [changes addObject:[NSOrderedCollectionChange changeWithObject:nil type:NSCollectionChangeRemove index:i]];
    }
    for (NSUInteger i=0;i<256;i++) {
        id object=[NSObject new];
        [changes addObject:[NSOrderedCollectionChange changeWithObject:object type:NSCollectionChangeInsert index:256+i]];
        [expected addObject:object];
    }
    NSOrderedSet *set=[NSOrderedSet orderedSetWithArray:values];
    NSOrderedCollectionDifference *difference=[[[NSOrderedCollectionDifference alloc]initWithChanges:changes]autorelease];
    fixtureShiftedElements=0;
    NSOrderedSet *result=[set orderedSetByApplyingDifference:difference];
    assert(same([result array],expected));assert(same([set array],values));
    printf("apply sorted mixed edits shiftedElements=%lu\n",fixtureShiftedElements);
    if (fixtureShiftedElements) { puts("FAIL: applying sorted edits shifts array elements");return 1; }
    changes=[NSMutableArray array];expected=[NSMutableArray array];
    for (NSUInteger i=0;i<256;i++) {
        id object=[NSObject new];
        [changes addObject:[NSOrderedCollectionChange changeWithObject:object type:NSCollectionChangeInsert index:i]];
        [expected addObject:object];
    }
    [expected addObjectsFromArray:values];
    difference=[[[NSOrderedCollectionDifference alloc]initWithChanges:changes]autorelease];
    fixtureShiftedElements=0;result=[set orderedSetByApplyingDifference:difference];
    assert(same([result array],expected));
    printf("apply leading insertions shiftedElements=%lu\n",fixtureShiftedElements);
    if (fixtureShiftedElements) { puts("FAIL: applying insertions shifts array elements");return 1; }
    puts("PASS: apply merges sorted changes without shifting");return 0;
}
static void manualApplications(void) {
    NSUInteger cases=0;
    for (NSUInteger count=0;count<=4;count++) {
        NSMutableArray *values=[NSMutableArray array];
        for (NSUInteger i=0;i<count;i++) [values addObject:[NSObject new]];
        NSOrderedSet *source=[NSOrderedSet orderedSetWithArray:values];
        for (NSUInteger mask=0;mask<(1UL<<(count+1));mask++)
        for (NSUInteger first=0;first<=count+1;first++)
        for (NSUInteger second=first+1;second<=count+2;second++) {
            NSMutableArray *changes=[NSMutableArray array], *reference=[values mutableCopy];
            BOOL valid=YES;
            for (NSUInteger i=count+1;i>0;i--)if (mask&(1UL<<(i-1))) {
                [changes addObject:[NSOrderedCollectionChange changeWithObject:nil type:NSCollectionChangeRemove index:i-1]];
                if (i-1>=[reference count])valid=NO;
                else [reference removeObjectAtIndex:i-1];
            }
            id objects[]={[NSObject new],count?[values objectAtIndex:0]:[NSObject new]};
            NSUInteger indexes[]={first,second};
            for (NSUInteger i=0;i<2;i++) {
                [changes addObject:[NSOrderedCollectionChange changeWithObject:objects[i] type:NSCollectionChangeInsert index:indexes[i]]];
                if (indexes[i]>[reference count])valid=NO;
                else [reference insertObject:objects[i] atIndex:indexes[i]];
            }
            NSOrderedCollectionDifference *d=[[[NSOrderedCollectionDifference alloc]initWithChanges:changes]autorelease];
            NSOrderedSet *result=[source orderedSetByApplyingDifference:d];
            assert(valid ? same([result array],[[NSOrderedSet orderedSetWithArray:reference]array]) : result==nil);
            assert(same([source array],values));cases++;
        }
    }
    printf("PASS: %lu manual applications preserve sequential edit semantics, invalid bounds and deduplication\n",cases);
}
static id predicateOld[3], predicateNew[3];
static unsigned predicateMask;
static BOOL predicate(id a,id b) {
    for (unsigned i=0;i<3;i++)for (unsigned j=0;j<3;j++)
        if (a==predicateOld[i] && b==predicateNew[j])return (predicateMask>>(3*i+j))&1;
    assert(0);return NO;
}
static void arbitraryEquivalence(void) {
    for (unsigned i=0;i<3;i++) { predicateOld[i]=[NSObject new];predicateNew[i]=[NSObject new]; }
    NSOrderedSet *old=[NSOrderedSet orderedSetWithArray:[NSArray arrayWithObjects:predicateOld count:3]];
    NSOrderedSet *new=[NSOrderedSet orderedSetWithArray:[NSArray arrayWithObjects:predicateNew count:3]];
    for (predicateMask=0;predicateMask<512;predicateMask++) {
        unsigned lengths[4][4]={{0}};
        for (unsigned i=1;i<=3;i++)for (unsigned j=1;j<=3;j++)
            lengths[i][j]=predicate(predicateOld[i-1],predicateNew[j-1])?1+lengths[i-1][j-1]:
                (lengths[i-1][j]>lengths[i][j-1]?lengths[i-1][j]:lengths[i][j-1]);
        unsigned mask=predicateMask;
        NSOrderedCollectionDifference *d=[new differenceFromOrderedSet:old withOptions:0 usingEquivalenceTest:^BOOL(id a,id b){return mask==predicateMask && predicate(a,b);}];
        assert([[d removals]count]==3-lengths[3][3]);assert([[d insertions]count]==3-lengths[3][3]);
        NSUInteger i=0,j=0;
        while (i<3 && j<3) {
            if (changeAtIndex([d removals],i)) { i++;continue; }
            if (changeAtIndex([d insertions],j)) { j++;continue; }
            assert(predicate(predicateOld[i++],predicateNew[j++]));
        }
    }
    puts("PASS: all 512 arbitrary 3x3 equivalence matrices produce minimal valid matches");
}
int main(int argc, const char **argv) {
    if (argc>1 && !strcmp(argv[1],"duplicate-insertion")) return duplicateInsertion();
    if (argc>1 && !strcmp(argv[1],"nil-transformation")) return nilTransformation();
    if (argc>1 && !strcmp(argv[1],"custom-scaling")) return customScaling(NO);
    if (argc>1 && !strcmp(argv[1],"custom-memory")) return customScaling(YES);
    if (argc>1 && !strcmp(argv[1],"apply-scaling")) return applyScaling();
    assert(customScaling(NO)==0);assert(customScaling(YES)==0);assert(applyScaling()==0);
    arbitraryEquivalence();manualApplications();
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
