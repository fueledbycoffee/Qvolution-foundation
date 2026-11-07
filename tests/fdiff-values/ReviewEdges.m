#import <Foundation/Foundation.h>
#include <stdio.h>
static NSUInteger additions;
@interface ReviewIndexSet: NSMutableIndexSet @end
@implementation ReviewIndexSet
- (void)addIndex:(NSUInteger)i { additions++; [super addIndex:i]; }
@end
int main(void) { @autoreleasepool {
 for (NSString *s in @[@"====", @"A===", @"AA======", @"AAAA====", @"AA==", @"AAA=", @"AAAA"] ) {
  NSData *d=[[NSData alloc] initWithBase64EncodedString:s options:0];
  printf("Base64(%s): %s/%lu\n",s.UTF8String,d?"data":"nil",(unsigned long)d.length);
 }
 ReviewIndexSet *s=[[ReviewIndexSet alloc] init];
 [s addIndexesInRange:NSMakeRange(0,10000)]; [s addIndexesInRange:NSMakeRange(20000,10000)];
 additions=0; [s shiftIndexesStartingAtIndex:0 by:1];
 printf("Shift.count: %lu\n",(unsigned long)s.count);
 printf("Shift.individualAdditions: %lu\n",(unsigned long)additions);
 } return 0; }
