#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned decodedDeaths;
@interface QVArchiveLifetimeToken:NSObject <NSCoding>{BOOL decoded;}
@end
@implementation QVArchiveLifetimeToken
- (void)encodeWithCoder:(NSCoder *)coder {int v=73;[coder encodeValueOfObjCType:@encode(int) at:&v];}
- (id)initWithCoder:(NSCoder *)coder {self=[super init];if(self){int v=0;[coder decodeValueOfObjCType:@encode(int) at:&v];if(v!=73)abort();decoded=YES;}return self;}
- (void)dealloc {if(decoded)decodedDeaths++;[super dealloc];}
@end
int main(int argc,char **argv){
 if(argc!=2)return 2;BOOL array=strcmp(argv[1],"array")==0;if(!array&&strcmp(argv[1],"dictionary")!=0)return 2;
 id held=nil;
 @autoreleasepool {
  QVArchiveLifetimeToken *token=[QVArchiveLifetimeToken new];
  id input=array?(id)[NSArray arrayWithObject:token]:(id)[NSDictionary dictionaryWithObject:token forKey:@"token"];
  fprintf(stderr,"PHASE archive begin %s\n",argv[1]);fflush(stderr);
  NSData *data=[NSArchiver archivedDataWithRootObject:input];
  fprintf(stderr,"PHASE archive end; decode begin\n");fflush(stderr);
  held=[[NSUnarchiver unarchiveObjectWithData:data] retain];
  fprintf(stderr,"PHASE decode end; held=%d decodedDeaths=%u; drain begin\n",held!=nil,decodedDeaths);fflush(stderr);
  [token release];
 }
 fprintf(stderr,"PHASE drain end held=%d decodedDeaths=%u\n",held!=nil,decodedDeaths);fflush(stderr);
 // If the child died while its container is owned, do not touch the dangling graph.
 if(!held||decodedDeaths){fprintf(stderr,"FAIL decoded child died while decoded container remains owned\n");fflush(stderr);_Exit(1);}
 [held release];
 if(decodedDeaths!=1){fprintf(stderr,"FAIL expected exactly one decoded child destruction, got %u\n",decodedDeaths);return 1;}
 puts("PASS decoded container owns child through pool drain and releases it once");return 0;
}
