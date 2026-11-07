#!/usr/bin/env python3
import pathlib,re,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
lane=root.parent/'native-round3'
lane.mkdir(exist_ok=True)
import argparse
args=argparse.ArgumentParser();args.add_argument('--baseline',action='store_true');args.add_argument('--source-ref');args.add_argument('--cache-contract',action='store_true');opt=args.parse_args()
label=('baseline' if opt.baseline else opt.source_ref or 'candidate')+('-cache' if opt.cache_contract else '')
def production(name):
    if opt.source_ref:
        return subprocess.check_output(['git','-C',str(root),'show',opt.source_ref+':'+name],text=True)
    if opt.baseline:
        return subprocess.check_output(['git','-C',str(root),'show','131b123:'+name],text=True)
    return (root/name).read_text()

prefix=(root/'tests/measurement-native.m').read_text().split('PRODUCTION_HEADERS')[0]
prefix=prefix.replace('NSString { const char *bytes;', 'NSString { @public const char *bytes;')
prefix=prefix.replace('NSNumber : NSObject { double value;', 'NSNumber : NSObject { @public double value;')
models=['NSUnit','NSUnitConverter','NSUnitConverterLinear','NSDimension','NSUnitLength','NSUnitTemperature','NSMeasurement']
clean=lambda s:re.sub(r'^#import[^\n]*','',s,flags=re.M)
prefix+='\n'+clean('\n'.join((root/'include/Foundation'/f'{n}.h').read_text() for n in models))
prefix+='\n'+clean('\n'.join((root/'src'/f'{n}.m').read_text() for n in models))
extra=r'''
#include <unicode/ustring.h>
#include <unicode/unum.h>
#include "NSMeasurementFormatting.h"
typedef struct { NSUInteger location,length; } NSRange;
static NSRange NSMakeRange(NSUInteger a,NSUInteger b){return (NSRange){a,b};}
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define NS_OPTIONS(T,N) T N; enum
#define NSUTF8StringEncoding 4
#define NSNumberFormatterDecimalStyle 1
typedef int NSFormattingUnitStyle;
#define NSFormattingUnitStyleShort 1
#define NSFormattingUnitStyleMedium 2
#define NSFormattingUnitStyleLong 3
static NSString *NSInternalInconsistencyException=@"internal";
static NSString *NSLocaleCountryCode=@"country",*NSLocaleUsesMetricSystem=@"metric";
@interface NSFormatter : NSObject @end
@implementation NSFormatter @end
@interface NSString (Review)
- (id)initWithCharacters:(const UChar *)s length:(NSUInteger)n;
- (id)substringWithRange:(NSRange)r;
- (id)stringByReplacingCharactersInRange:(NSRange)r withString:(NSString *)s;
- (id)stringByAppendingString:(NSString *)s;
+ (id)stringWithFormat:(NSString *)f,...;
@end
static NSString *str(const char *s){FixtureString *o=[FixtureString alloc];o->bytes=strdup(s);o->length=strlen(s);return o;}
@implementation NSString (Review)
- (id)initWithCharacters:(const UChar *)s length:(NSUInteger)n {
 char b[2048];UErrorCode status=U_ZERO_ERROR;u_strToUTF8(b,sizeof b,NULL,s,n,&status);assert(U_SUCCESS(status));return str(b);
}
- (id)substringWithRange:(NSRange)r {char b[2048];memcpy(b,[self UTF8String]+r.location,r.length);b[r.length]=0;return str(b);}
- (id)stringByReplacingCharactersInRange:(NSRange)r withString:(NSString *)s {
 char b[2048];snprintf(b,sizeof b,"%.*s%s%s",(int)r.location,[self UTF8String],[s UTF8String],[self UTF8String]+r.location+r.length);return str(b);
}
- (id)stringByAppendingString:(NSString *)s {char b[2048];snprintf(b,sizeof b,"%s%s",[self UTF8String],[s UTF8String]);return str(b);}
+ (id)stringWithFormat:(NSString *)f,... {abort();}
@end
static const char *fixtureLocale="en_US";
@interface NSLocale : NSObject
+ (id)currentLocale; - (id)localeIdentifier; - (id)objectForKey:(id)key;
@end
@implementation NSLocale
+ (id)currentLocale {return [self alloc];}
- (id)copyWithZone:(NSZone *)zone {return self;}
- (id)localeIdentifier {return str(fixtureLocale);}
- (id)objectForKey:(id)key {return @"US";}
@end
@interface NSNumber (Review)
- (BOOL)boolValue;
@end
@implementation NSNumber (Review)
- (BOOL)boolValue {return value!=0;}
@end
@interface NSNumberFormatter : NSObject { @public UNumberFormat *nf; }
- (void)setNumberStyle:(int)x; - (void)setLocale:(id)x;
- (NSString *)stringFromNumber:(NSNumber *)n;
- (const UNumberFormat *)_measurementNumberFormat;
@end
@implementation NSNumberFormatter
- (id)init {UErrorCode e=U_ZERO_ERROR;nf=unum_open(UNUM_DECIMAL,NULL,0,fixtureLocale,NULL,&e);assert(U_SUCCESS(e));return self;}
- (void)setNumberStyle:(int)x {} - (void)setLocale:(id)x {}
- (const UNumberFormat *)_measurementNumberFormat {return nf;}
- (NSString *)stringFromNumber:(NSNumber *)n {UChar wide[200];char text[800];UErrorCode e=U_ZERO_ERROR;int len=unum_formatDouble(nf,n->value,wide,200,NULL,&e);u_strToUTF8(text,800,NULL,wide,len,&e);assert(U_SUCCESS(e));return str(text);}
@end
'''
s=prefix+'\n'+extra+'\n'+clean((root/'include/Foundation/NSMeasurementFormatter.h').read_text())+'\n'
s+=clean((root/'src/NSUnitFormatterInternal.h').read_text())+'\n'+clean(production('src/NSMeasurementFormatter.m'))
s+=r'''
// Darwin auto-synthesizes these accessors; GCC runtime requires fixture accessors.
@implementation NSMeasurementFormatter (FixtureAccessors)
- (void)setUnitOptions:(NSMeasurementFormatterUnitOptions)x {_unitOptions=x;}
- (void)setUnitStyle:(NSFormattingUnitStyle)x {_unitStyle=x;}
@end
static int failures;
static void check(const char *locale,double value,int minimum,int maximum,const char *expected) {
 fixtureLocale=locale;
 NSMeasurementFormatter *f=[[NSMeasurementFormatter alloc]init];
 [f setUnitOptions:NSMeasurementFormatterUnitOptionsProvidedUnit];[f setUnitStyle:NSFormattingUnitStyleLong];
 NSNumberFormatter *n=[f numberFormatter];
 unum_setAttribute(n->nf,UNUM_MIN_FRACTION_DIGITS,minimum);
 unum_setAttribute(n->nf,UNUM_MAX_FRACTION_DIGITS,maximum);
 NSMeasurement *m=[[NSMeasurement alloc]initWithDoubleValue:value unit:[NSUnitLength meters]];
 const char *got=[[f stringFromMeasurement:m]UTF8String];
 printf("%s value=%g fraction=%d..%d: %s (expected %s)\n",locale,value,minimum,maximum,got,expected);
 if(strcmp(got,expected))failures++;
}
int main(void){
 check("en_US",1.1,0,0,"1 meter");
 check("en_US",1.6,0,0,"2 meters");
 check("en_US",1,1,1,"1.0 meters");
 check("en_US",1.04,2,2,"1.04 meters");
 check("en_US",0.99,0,0,"1 meter");
 check("en_US",-1.1,0,0,"-1 meter");
 check("ru_RU",1.1,0,0,"1 метр");
 check("ru_RU",2.1,0,0,"2 метра");
 check("ru_RU",5.1,0,0,"5 метров");
 check("ru_RU",1,1,1,"1,0 метра");
 check("fr_FR",1.1,0,0,"1 mètre");
 printf("%d production measurement rounding failures\n",failures);
 return failures?1:0;
}
'''
if not opt.baseline:
    start=s.index('// Darwin auto-synthesizes these accessors;')
    end=s.index('static int failures;',start)
    s=s[:start]+s[end:]
if opt.cache_contract:
    s=s[:s.index('int main(void){')]+r"""
static void expectFormatted(NSMeasurementFormatter *f,NSMeasurement *m,const char *expected) {
 const char *actual=[[f stringFromMeasurement:m] UTF8String];
 printf("cache: %s (expected %s)\n",actual,expected);
 if(strcmp(actual,expected))failures++;
}
int main(void){
 fixtureLocale="en_US";
 NSMeasurementFormatter *f=[[NSMeasurementFormatter alloc]init];
 [f setUnitOptions:NSMeasurementFormatterUnitOptionsProvidedUnit];
 [f setUnitStyle:NSFormattingUnitStyleLong];
 NSNumberFormatter *n=[f numberFormatter];
 unum_setAttribute(n->nf,UNUM_MAX_FRACTION_DIGITS,0);
 NSMeasurement *m=[[NSMeasurement alloc]initWithDoubleValue:1.1 unit:[NSUnitLength meters]];
 expectFormatted(f,m,"1 meter");
 unum_setAttribute(n->nf,UNUM_MIN_FRACTION_DIGITS,2);
 unum_setAttribute(n->nf,UNUM_MAX_FRACTION_DIGITS,2);
 expectFormatted(f,m,"1 meter");
 [f setUnitStyle:NSFormattingUnitStyleMedium];
 expectFormatted(f,m,"1.10 m");
 [f setUnitStyle:NSFormattingUnitStyleLong];
 expectFormatted(f,m,"1.10 meters");
 printf("%d production measurement cache failures\n",failures);
 return failures?1:0;
}
"""
src=lane/(label+'.m');src.write_text(s);exe=lane/label
inc=subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip()
helper=lane/(label+('.c' if opt.baseline else '.cpp'))
helper.write_text(production('src/NSMeasurementFormatting.'+('c' if opt.baseline else 'cpp')))
(lane/'NSMeasurementFormatting.h').write_text(production('src/NSMeasurementFormatting.h'))
obj=lane/(label+'-helper.o')
subprocess.run(['clang' if opt.baseline else 'clang++','-std=c11' if opt.baseline else '-std=c++17','-I'+str(lane),'-I'+str(root/'src'),'-fsanitize=undefined','-fno-sanitize-recover=all','-c',str(helper),'-o',str(obj)],check=True)
subprocess.run(['clang','-fobjc-runtime=gcc','-fconstant-string-class=FixtureString','-fobjc-exceptions','-fexceptions','-I'+inc,'-I'+str(lane),'-Wno-objc-method-access','-Wno-incomplete-implementation','-fsanitize=undefined','-fno-sanitize-recover=all',str(src),str(obj),'-lobjc','-licui18n','-licuuc','-lstdc++','-lm','-o',str(exe)],check=True)
r=subprocess.run([str(exe)])
assert (r.returncode != 0) if opt.baseline else (r.returncode == 0)
print('PASS: expected baseline failure' if opt.baseline else 'PASS: production formatter rounding/plurals under UBSan')
