#include <objc/runtime.h>
#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unicode/ucal.h>
typedef long NSInteger;
typedef unsigned long NSUInteger;
typedef double NSTimeInterval;
typedef NSUInteger NSCalendarUnit;
#define NSDateComponentUndefined LONG_MAX
/*UNITS*/
__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc; - (id)init; - (id)autorelease; - (void)release; - (id)copy; - (id)retain;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self,0); }
- (id)init { return self; }
- (id)autorelease { return self; }
- (void)release {}
- (id)copy { return self; }
- (id)retain { return self; }
@end
@interface NSString : NSObject @end
@implementation NSString @end
static id NSInvalidArgumentException;
@interface NSException : NSObject
+ (void)raise:(id)name format:(id)format;
@end
@implementation NSException
+ (void)raise:(id)name format:(id)format { @throw [self alloc]; }
@end
@interface NSDate : NSObject { @public double seconds; }
+ (id)at:(double)t;
@end
@implementation NSDate
+ (id)at:(double)t { NSDate *d=[self alloc];d->seconds=t;return d; }
@end
@class NSCalendar;
#define NSTimeZone NSObject
/*STORAGE*/
@interface NSDateComponents : NSObject
/*PROPS*/
- (NSCalendar *)calendar; - (void)setCalendar:(NSCalendar *)c;
- (id)timeZone; - (void)setTimeZone:(id)z;
- (NSInteger)valueForComponent:(NSCalendarUnit)u;
- (void)setValue:(NSInteger)v forComponent:(NSCalendarUnit)u;
- (BOOL)isValidDate; - (BOOL)isValidDateInCalendar:(NSCalendar *)c;
@end
@implementation NSDateComponents
+ (id)alloc { return class_createInstance(self,sizeof(NSDateComponentParts)); }
/*INIT*/
/*PROPS_IMPL*/

@end
@interface NSCalendar : NSObject { @public UCalendar *icu; id zone; BOOL fail; NSUInteger lastOptions; }
- (void)setTimeZone:(id)z;
- (BOOL)rangeOfUnit:(NSCalendarUnit)unit startDate:(NSDate **)start interval:(NSTimeInterval *)duration forDate:(NSDate *)date;
- (NSDate *)dateByAddingComponents:(NSDateComponents *)c toDate:(NSDate *)date options:(NSUInteger)opts;
- (NSDate *)dateFromComponents:(NSDateComponents *)c;
- (NSDateComponents *)components:(NSUInteger)flags fromDate:(NSDate *)date;
- (NSDate *)startOfDayForDate:(NSDate *)date;
- (NSDate *)dateByAddingUnit:(NSCalendarUnit)unit value:(NSInteger)value toDate:(NSDate *)date options:(NSUInteger)opts;
@end
static const UCalendarDateFields fields[]={UCAL_ERA,UCAL_YEAR,UCAL_MONTH,UCAL_DATE,UCAL_HOUR_OF_DAY,UCAL_MINUTE,UCAL_SECOND,UCAL_DAY_OF_WEEK,UCAL_DAY_OF_WEEK_IN_MONTH,UCAL_MONTH,UCAL_WEEK_OF_MONTH,UCAL_WEEK_OF_YEAR,UCAL_YEAR_WOY,UCAL_MILLISECOND};
@implementation NSCalendar
- (id)init { UErrorCode e=U_ZERO_ERROR;UChar utc[]={'G','M','T',0};icu=ucal_open(utc,3,"en_US_POSIX",UCAL_GREGORIAN,&e);assert(U_SUCCESS(e));return self; }
- (id)copy { NSCalendar *c=[[NSCalendar alloc]init];UErrorCode e=U_ZERO_ERROR;ucal_close(c->icu);c->icu=ucal_clone(icu,&e);c->zone=zone;c->fail=fail;return c; }
- (void)setTimeZone:(id)z { zone=z;UErrorCode e=U_ZERO_ERROR;UChar tz[]={'G','M','T','+','0','2',0};ucal_setTimeZone(icu,tz,6,&e);assert(U_SUCCESS(e)); }
- (BOOL)rangeOfUnit:(NSCalendarUnit)unit startDate:(NSDate **)start interval:(NSTimeInterval *)duration forDate:(NSDate *)date {
 assert(unit==NSCalendarUnitDay);if(fail)return NO;
 UErrorCode e=U_ZERO_ERROR;ucal_setMillis(icu,date->seconds*1000,&e);
 ucal_set(icu,UCAL_HOUR_OF_DAY,0);ucal_set(icu,UCAL_MINUTE,0);ucal_set(icu,UCAL_SECOND,0);ucal_set(icu,UCAL_MILLISECOND,0);
 *start=[NSDate at:ucal_getMillis(icu,&e)/1000];*duration=86400;return U_SUCCESS(e);
}
- (NSDate *)dateByAddingComponents:(NSDateComponents *)c toDate:(NSDate *)date options:(NSUInteger)opts {
 lastOptions=opts;if(fail||!date)return nil;UErrorCode e=U_ZERO_ERROR;ucal_setMillis(icu,date->seconds*1000,&e);
 for(int i=0;i<14;i++)if([c valueForComponent:1UL<<i]!=NSDateComponentUndefined){if(opts&1)ucal_roll(icu,fields[i],[c valueForComponent:1UL<<i],&e);else ucal_add(icu,fields[i],[c valueForComponent:1UL<<i],&e);}
 return [NSDate at:ucal_getMillis(icu,&e)/1000];
}
- (NSDate *)dateFromComponents:(NSDateComponents *)c {
 if(fail)return nil;ucal_clear(icu);ucal_setDateTime(icu,1,0,1,0,0,0,&(UErrorCode){U_ZERO_ERROR});UErrorCode e=U_ZERO_ERROR;
 for(int i=0;i<14;i++)if([c valueForComponent:1UL<<i]!=NSDateComponentUndefined)ucal_set(icu,fields[i],[c valueForComponent:1UL<<i]-(i==2?1:0));
 return [NSDate at:ucal_getMillis(icu,&e)/1000];
}
- (NSDateComponents *)components:(NSUInteger)flags fromDate:(NSDate *)date {
 UErrorCode e=U_ZERO_ERROR;ucal_setMillis(icu,date->seconds*1000,&e);NSDateComponents *c=[[NSDateComponents alloc]init];
 for(int i=0;i<14;i++)if(flags&(1UL<<i))[c setValue:ucal_get(icu,fields[i],&e)+(i==2?1:0) forComponent:1UL<<i];return c;
}
@end
@implementation NSCalendar (Production)
/*CAL_METHODS*/
@end
@implementation NSDateComponents (Production)
/*COMP_METHODS*/
@end
// These doubles verify the wrapper's backend choice and argument ownership.
static void *expected;static id pathToken,queryToken,fragmentToken,stringToken,lastValue;static BOOL accept=YES;
typedef void *CFStringRef;
#define BACKEND_GET(N,T) static id _CFURLComponentsCopy##N(void *c){assert(c==expected);return T;}
BACKEND_GET(PercentEncodedPath,pathToken)
BACKEND_GET(Query,queryToken)
BACKEND_GET(Fragment,fragmentToken)
BACKEND_GET(String,stringToken)
#define BACKEND_SET(N) static BOOL _CFURLComponentsSet##N(void *c,CFStringRef v){assert(c==expected);lastValue=(id)v;return accept;}
BACKEND_SET(PercentEncodedPath)
BACKEND_SET(Query)
BACKEND_SET(Fragment)
@interface NSURLComponents : NSObject { @public void *_components; }
- (id)percentEncodedPath; - (void)setPercentEncodedPath:(id)p;
- (id)query; - (void)setQuery:(id)p; - (id)fragment; - (void)setFragment:(id)p; - (id)string;
@end
@implementation NSURLComponents
/*URL_METHODS*/
@end
int main(int argc,char **argv) {
 assert(argc==2);
 if(!strcmp(argv[1],"url")) {
  assert(class_getInstanceMethod(objc_getClass("NSURLComponents"),sel_registerName("string")));
  NSURLComponents *c=[NSURLComponents alloc];c->_components=expected=&expected;
  pathToken=[NSString alloc];queryToken=[NSString alloc];fragmentToken=[NSString alloc];stringToken=[NSString alloc];
  assert([c percentEncodedPath]==pathToken&&[c query]==queryToken&&[c fragment]==fragmentToken&&[c string]==stringToken);
  [c setPercentEncodedPath:pathToken];assert(lastValue==pathToken);[c setQuery:queryToken];assert(lastValue==queryToken);[c setFragment:nil];assert(!lastValue);
  queryToken=nil;fragmentToken=nil;stringToken=nil;assert(![c query]&&![c fragment]&&![c string]);
  accept=NO;BOOL raised=NO;@try{[c setPercentEncodedPath:pathToken];}@catch(id e){raised=YES;}assert(raised);
  accept=YES;[c setQuery:nil];assert(!lastValue);[c setFragment:nil];assert(!lastValue);
 } else if(!strcmp(argv[1],"calendar")) {
  assert(class_getInstanceMethod(objc_getClass("NSCalendar"),sel_registerName("startOfDayForDate:")));
  NSCalendar *c=[[NSCalendar alloc]init];
  double in[]={-2208988800,-1,0,951782400,1609459200,1640995200,2147483647};
  double day[]={-2208988800,-86400,0,951782400,1609459200,1640995200,2147472000};
  double month[]={-2206310400,2678399,2678400,954288000,1612137600,1643673600,2150162047};
  for(int i=0;i<7;i++){assert([c startOfDayForDate:[NSDate at:in[i]]]->seconds==day[i]);assert([c dateByAddingUnit:NSCalendarUnitMonth value:1 toDate:[NSDate at:in[i]] options:0]->seconds==month[i]);}
  assert([c dateByAddingUnit:NSCalendarUnitMonth value:-1 toDate:[NSDate at:0] options:0]->seconds==-2678400);
  [c dateByAddingUnit:NSCalendarUnitMonth value:1 toDate:[NSDate at:0] options:1];assert(c->lastOptions==1);
  assert([c dateByAddingUnit:NSCalendarUnitMonth value:1 toDate:[NSDate at:1612094400] options:0]->seconds==1614513600);
  UChar ny[]={'A','m','e','r','i','c','a','/','N','e','w','_','Y','o','r','k',0};UErrorCode error=U_ZERO_ERROR;
  ucal_setTimeZone(c->icu,ny,16,&error);assert(U_SUCCESS(error));
  double dst[]={1615654800,1636214400},lengths[]={23*3600,25*3600};
  for(int i=0;i<2;i++)assert([c dateByAddingUnit:NSCalendarUnitDay value:1 toDate:[NSDate at:dst[i]] options:0]->seconds-dst[i]==lengths[i]);
  c->fail=YES;assert(![c startOfDayForDate:[NSDate at:0]]);assert(![c dateByAddingUnit:NSCalendarUnitMonth value:1 toDate:[NSDate at:0] options:0]);
 } else {
  assert(class_getInstanceMethod(objc_getClass("NSDateComponents"),sel_registerName("isValidDate")));
  NSCalendar *cal=[[NSCalendar alloc]init];NSDateComponents *c=[[NSDateComponents alloc]init];
  for(int i=0;i<14;i++){assert([c valueForComponent:1UL<<i]==NSDateComponentUndefined);[c setValue:2 forComponent:1UL<<i];assert([c valueForComponent:1UL<<i]==2);[c setValue:NSDateComponentUndefined forComponent:1UL<<i];assert([c valueForComponent:1UL<<i]==NSDateComponentUndefined);}
  assert(![c isValidDate]);[c setCalendar:cal];
  int cases[][4]={{2000,2,29,1},{1900,2,29,0},{2020,2,30,0},{2021,13,1,0},{2021,0,1,0},{2021,1,-1,0},{2020,2,29,1}};
  for(int i=0;i<7;i++){[c setYear:cases[i][0]];[c setMonth:cases[i][1]];[c setDay:cases[i][2]];assert([c isValidDate]==cases[i][3]);}
  [c setNanosecond:INT_MAX];assert([c valueForComponent:NSCalendarUnitNanosecond]==INT_MAX);assert(![c isValidDate]);
  [c setValue:NSDateComponentUndefined forComponent:NSCalendarUnitDay];assert([c day]==NSDateComponentUndefined);
  [c setDay:NSDateComponentUndefined];assert([c valueForComponent:NSCalendarUnitDay]==NSDateComponentUndefined);
  [c setDay:INT_MAX];assert([c valueForComponent:NSCalendarUnitDay]==INT_MAX);
  [c setValue:INT_MAX forComponent:NSCalendarUnitDay];assert([c day]==INT_MAX);
  [c setDay:29];
  [c setNanosecond:999999999];assert([c isValidDate]&&[c nanosecond]==999999999);
  [c setNanosecond:1000000000];assert(![c isValidDate]);[c setNanosecond:-1];assert(![c isValidDate]);[c setNanosecond:0];
  [c setHour:24];assert(![c isValidDate]);[c setHour:0];[c setTimeZone:[NSObject alloc]];assert([c isValidDate]&&!cal->zone);
  cal->fail=YES;assert(![c isValidDate]);assert(![c isValidDateInCalendar:nil]);
 }
 puts("PASS native production-method regression");return 0;
}
