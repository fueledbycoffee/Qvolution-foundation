// Supplemental public-API check; the original two differential checks are unchanged.
// Rung 2: CFAttributedString.h copying, replacement, and longest-range contracts.
// Rung 3: Apple NSAttributedString longest-range and enumeration documentation.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdint.h>

static void limits(void) {
    NSAttributedString *s=[[NSAttributedString alloc] initWithString:@"a" attributes:@{@"k":@1}];
    NSRange ranges[]={NSMakeRange(0,2),NSMakeRange(2,0),NSMakeRange(1,1),NSMakeRange((NSUInteger)-1,2),NSMakeRange(1,(NSUInteger)-1),NSMakeRange(0,1),NSMakeRange(0,0),NSMakeRange(1,0)};
    for(unsigned selector=0;selector<2;selector++) for(unsigned output=0;output<2;output++) for(unsigned i=0;i<8;i++) {
        const char *answer="OK";
        @try {
            NSRange r;
            if(selector)(void)[s attribute:@"k" atIndex:0 longestEffectiveRange:output?&r:NULL inRange:ranges[i]];
            else (void)[s attributesAtIndex:0 longestEffectiveRange:output?&r:NULL inRange:ranges[i]];
        } @catch(NSException *e) { answer=[e.name UTF8String]; }
        printf("NSAttributedString.review.limit(%u,%u,%u): %s\n",selector,output,i,answer);
    }
}
static void mutation(void) {
    for(unsigned reverse=0;reverse<2;reverse++) for(unsigned selector=0;selector<2;selector++) for(unsigned shortRanges=0;shortRanges<2;shortRanges++) for(unsigned insertion=0;insertion<2;insertion++) {
        @try {
            NSMutableAttributedString *s=[[NSMutableAttributedString alloc] initWithString:@"LabcR"];
            for(NSUInteger i=0;i<5;i++)[s addAttribute:@"k" value:@(i) range:NSMakeRange(i,1)];
            NSMutableArray *visited=[NSMutableArray array];
            void (^block)(id,NSRange,BOOL *)=^(id value,NSRange r,BOOL *stop) {
                id v=selector?value:[value objectForKey:@"k"];
                [visited addObject:[NSString stringWithFormat:@"%lu,%lu,%@",(unsigned long)r.location,(unsigned long)r.length,v]];
                if(insertion)[s replaceCharactersInRange:r withString:@"zz"];
                else [s deleteCharactersInRange:r];
            };
            NSUInteger opts=(reverse?NSAttributedStringEnumerationReverse:0)|(shortRanges?NSAttributedStringEnumerationLongestEffectiveRangeNotRequired:0);
            if(selector)[s enumerateAttribute:@"k" inRange:NSMakeRange(1,3) options:opts usingBlock:block];
            else [s enumerateAttributesInRange:NSMakeRange(1,3) options:opts usingBlock:block];
            printf("NSAttributedString.review.mutation(%u,%u,%u,%u): %s;%s\n",reverse,selector,shortRanges,insertion,[[visited componentsJoinedByString:@";"] UTF8String],[s.string UTF8String]);
        } @catch(NSException *e) { printf("NSAttributedString.review.mutation(%u,%u,%u,%u): %s\n",reverse,selector,shortRanges,insertion,[e.name UTF8String]); }
    }
}
static void copiesAndArchives(void) {
    @try {
        NSMutableAttributedString *s=[[NSMutableAttributedString alloc] initWithString:@"ab" attributes:@{@"k":@1}];
        [s addAttribute:@"k" value:@2 range:NSMakeRange(1,1)];
        NSAttributedString *snapshot=[s copy];
        NSMutableAttributedString *editable=[s mutableCopy];
        NSString *text=[s.string copy];
        [s appendAttributedString:s];
        [editable replaceCharactersInRange:NSMakeRange(0,1) withString:@"z"];
        [editable addAttribute:@"k" value:@3 range:NSMakeRange(0,1)];
        BOOL isolated=[text isEqualToString:@"ab"]&&[snapshot.string isEqualToString:@"ab"]&&[[snapshot attribute:@"k" atIndex:0 effectiveRange:NULL] isEqual:@1]&&[editable.string isEqualToString:@"zb"]&&[s.string isEqualToString:@"abab"];
        BOOL runs=YES;for(NSUInteger i=0;i<4;i++)runs&=[[s attribute:@"k" atIndex:i effectiveRange:NULL] isEqual:@(i%2+1)];
        printf("NSAttributedString.review.copyIsolation(): %d\n",isolated&&runs);
        for(unsigned mutable=0;mutable<2;mutable++) {
            NSAttributedString *input=mutable?editable:snapshot;
            NSData *data=[NSKeyedArchiver archivedDataWithRootObject:input];
            NSAttributedString *decoded=[NSKeyedUnarchiver unarchiveObjectWithData:data];
            printf("NSAttributedString.review.archive(%u): equal=%d,mutable=%d\n",mutable,[decoded isEqualToAttributedString:input],[decoded isKindOfClass:[NSMutableAttributedString class]]);
        }
    } @catch(NSException *e) { printf("NSAttributedString.review.copyArchive(): %s\n",[e.name UTF8String]); }
}
static void appends(void) {
    for(unsigned alternating=0;alternating<2;alternating++) {
        @try {
            NSAttributedString *a=[[NSAttributedString alloc] initWithString:@"a" attributes:@{@"k":@1}];
            NSAttributedString *b=[[NSAttributedString alloc] initWithString:@"b" attributes:@{@"k":@2}];
            NSMutableAttributedString *s=[[NSMutableAttributedString alloc] initWithString:@""];
            const NSUInteger n=32768;
            for(NSUInteger i=0;i<n;i++)[s appendAttributedString:alternating&&(i&1)?b:a];
            BOOL valid=s.length==n;
            for(NSUInteger i=0;i<n;i++)valid&=[s.string characterAtIndex:i]==(alternating&&(i&1)?'b':'a')&&[[s attribute:@"k" atIndex:i effectiveRange:NULL] isEqual:@(alternating&&(i&1)?2:1)];
            __block NSUInteger runs=0;
            [s enumerateAttribute:@"k" inRange:NSMakeRange(0,n) options:0 usingBlock:^(id v,NSRange r,BOOL *stop){runs++;}];
            printf("NSAttributedString.review.appends(%u): valid=%d,runs=%lu\n",alternating,valid,(unsigned long)runs);
        } @catch(NSException *e) { printf("NSAttributedString.review.appends(%u): %s\n",alternating,[e.name UTF8String]); }
    }
}
int main(void) { @autoreleasepool { limits();mutation();copiesAndArchives();appends(); } return 0; }
