// Linux libobjc doubles for unedited production methods. This does not test
// Foundation localization, CF normalization or container runtime integration.
#include <objc/runtime.h>
#include <objc/message.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdint.h>
#include <limits.h>
#include <math.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/mman.h>
#define MIN(a,b) ((a)<(b)?(a):(b))
#define UNLIKELY(x) (x)
#define reallocf realloc
#define NSDataReadingMappedIfSafe 1
#define NSDataWritingAtomic 1
#define NSDataWritingWithoutOverwriting 2
#define NSFileReadNoPermissionError 257
typedef unsigned long NSDataReadingOptions, NSDataWritingOptions;
static int OSAtomicIncrement32(int *p) { return ++*p; }
typedef unsigned long NSUInteger;
typedef long NSInteger;
#define NSNotFound LONG_MAX
#define NS_ENUM(T,N) T N; enum
#define NS_OPTIONS(T,N) T N; enum
#define NSFormattingContextMiddleOfSentence 5
#define NSFormattingContextUnknown 0
#define NSNumberFormatterDecimalStyle 1
#define NSNumberFormatterBehavior10_4 1040
#define NSNumberFormatterRoundUp 3
#define NSFileNoSuchFileError 4
typedef long dispatch_once_t;
void *_NSConcreteGlobalBlock[32];
static void dispatch_once(long *once, void (^block)(void)) { if (!*once) { *once=1; block(); } }
__attribute__((objc_root_class)) @interface NSObject { Class isa; }
+ (id)alloc; + (id)new; + (Class)class; - (id)init; - (id)retain; - (id)autorelease; - (void)release;
@end
@implementation NSObject
+ (id)alloc {return class_createInstance(self,0);}
+ (Class)class {return self;}
+ (id)new {return [[self alloc] init];}
- (id)init {return self;} - (id)retain {return self;} - (id)autorelease {return self;} - (void)release {}
@end
static int pathRepresentationCalls;
@interface NSString : NSObject
+ (id)stringWithFormat:(NSString *)fmt,...;
+ (id)from:(const char *)s;
- (const char *)UTF8String;
- (NSUInteger)length;
- (BOOL)isNSString__;
- (id)stringByAppendingFormat:(NSString *)fmt,...;
- (const char *)fileSystemRepresentation;
- (id)stringByAppendingString:(NSString *)s;
@end
@interface FixtureString : NSString { @public const char *bytes; unsigned length; }
@end
@implementation NSString
+ (id)from:(const char *)s {FixtureString *o=[FixtureString new];o->bytes=strdup(s);o->length=strlen(s);return o;}
+ (id)stringWithFormat:(NSString *)fmt,... {
 char output[2048]={0},*p=output;const char *f=[fmt UTF8String];va_list ap;va_start(ap,fmt);
 while(*f) {
  if(f[0]=='%'&&f[1]=='@') {id obj=va_arg(ap,id);const char *s=obj?[obj UTF8String]:"(null)";size_t n=strlen(s);memcpy(p,s,n);p+=n;f+=2;}
  else if(!strncmp(f,"%llu",4)){p+=sprintf(p,"%llu",va_arg(ap,unsigned long long));f+=4;}
  else {*p++=*f++;}
 }
 *p=0;va_end(ap);return [self from:output];
}
- (const char *)UTF8String {return "";}
- (NSUInteger)length {return strlen([self UTF8String]);}
- (BOOL)isNSString__ {return YES;}
- (id)stringByAppendingFormat:(NSString *)fmt,... { va_list ap;va_start(ap,fmt);char buf[2048];snprintf(buf,sizeof buf,"%s.tmp%d",[self UTF8String],va_arg(ap,int));va_end(ap);return [NSString from:buf];}
- (const char *)fileSystemRepresentation {pathRepresentationCalls++;if(![self length]){fputs("FAIL empty public string conversion called by file I/O\n",stderr);abort();}return [self UTF8String];}
- (id)stringByAppendingString:(NSString *)s {return [NSString stringWithFormat:@"%@%@",self,s];}
@end
@implementation FixtureString
- (const char *)UTF8String {return bytes;}
@end
@interface Path : FixtureString { @public const char *filesystem; }
@end
@implementation Path
- (const char *)fileSystemRepresentation {pathRepresentationCalls++;return filesystem;}
@end
@interface NSArray : NSObject { id items[12]; NSUInteger n; }
- (id)initWithObjects:(id)first,...; - (id)objectAtIndex:(NSUInteger)i; - (NSUInteger)count;
@end
@implementation NSArray
- (id)initWithObjects:(id)first,... {va_list ap;va_start(ap,first);for(id x=first;x;x=va_arg(ap,id))items[n++]=x;va_end(ap);return self;}
- (id)objectAtIndex:(NSUInteger)i {assert(i<n);return items[i];}
- (NSUInteger)count {return n;}
@end
@interface NSNumber : NSObject { @public long long integer; double value; BOOL floating; }
+ (id)numberWithLongLong:(long long)x; + (id)numberWithUnsignedLongLong:(unsigned long long)x; + (id)numberWithDouble:(double)x;
@end
@implementation NSNumber
+ (id)numberWithLongLong:(long long)x {NSNumber *o=[self new];o->integer=x;o->value=x;return o;}
+ (id)numberWithUnsignedLongLong:(unsigned long long)x {return [self numberWithLongLong:x];}
+ (id)numberWithDouble:(double)x {NSNumber *o=[self new];o->value=x;o->floating=YES;return o;}
@end
@interface NSLocale : NSObject + (id)currentLocale; @end
@implementation NSLocale + (id)currentLocale {return nil;} @end
@interface NSNumberFormatter : NSObject { NSUInteger minimum,maximum,minSig,maxSig; BOOL significant; }
- (void)setLocale:(id)x; - (void)setNumberStyle:(NSUInteger)x; - (void)setUsesGroupingSeparator:(BOOL)x;
- (void)setMaximumFractionDigits:(NSUInteger)x; - (void)setMinimumFractionDigits:(NSUInteger)x;
- (void)setUsesSignificantDigits:(BOOL)x; - (void)setMaximumSignificantDigits:(NSUInteger)x; - (void)setMinimumSignificantDigits:(NSUInteger)x;
- (void)setFormatterBehavior:(NSUInteger)x; - (void)setRoundingMode:(NSUInteger)x; - (void)setGroupingSize:(NSUInteger)x;
- (NSString *)stringFromNumber:(NSNumber *)x;
@end
@implementation NSNumberFormatter
- (void)setLocale:(id)x {} - (void)setNumberStyle:(NSUInteger)x {} - (void)setUsesGroupingSeparator:(BOOL)x {}
- (void)setMaximumFractionDigits:(NSUInteger)x {maximum=x;} - (void)setMinimumFractionDigits:(NSUInteger)x {minimum=x;}
- (void)setUsesSignificantDigits:(BOOL)x {significant=x;} - (void)setMaximumSignificantDigits:(NSUInteger)x {maxSig=x;} - (void)setMinimumSignificantDigits:(NSUInteger)x {minSig=x;}
- (void)setFormatterBehavior:(NSUInteger)x {} - (void)setRoundingMode:(NSUInteger)x {} - (void)setGroupingSize:(NSUInteger)x {}
- (NSString *)stringFromNumber:(NSNumber *)x {
 char b[128];
 if (!x->floating) snprintf(b,sizeof b,"%lld",x->integer);
 else if(significant) {
  snprintf(b,sizeof b,"%.*g",(int)maxSig,x->value);
  if(minSig>1&&x->value!=0) {int digits=(int)floor(log10(fabs(x->value)))+1;int decimals=(int)minSig-digits;if(decimals<0)decimals=0;snprintf(b,sizeof b,"%.*f",decimals,x->value);}
 } else {
  snprintf(b,sizeof b,"%.*f",(int)maximum,x->value);
  if(maximum>minimum) {char *end=b+strlen(b);for(NSUInteger i=maximum;i>minimum&&end[-1]=='0';i--)*--end=0;if(end[-1]=='.')*--end=0;}
 }
 return [NSString from:b];
}
@end
@interface NSDictionary : NSObject { @public id keys[8],values[8]; NSUInteger count; }
+ (id)dictionaryWithObjects:(const id *)objects forKeys:(const id *)keys count:(NSUInteger)n;
- (id)objectForKey:(id)key;
@end
@implementation NSDictionary
+ (id)dictionaryWithObjects:(const id *)objects forKeys:(const id *)k count:(NSUInteger)n {NSDictionary *d=[self new];d->count=n;for(NSUInteger i=0;i<n;i++){d->keys[i]=k[i];d->values[i]=objects[i];}return d;}
- (id)objectForKey:(id)key {for(NSUInteger i=0;i<count;i++)if(!strcmp([key UTF8String],[keys[i] UTF8String]))return values[i];return nil;}
@end
static NSString *NSLocalizedDescriptionKey=@"NSLocalizedDescriptionKey";
static NSString *NSPOSIXErrorDomain=@"NSPOSIXErrorDomain",*NSCocoaErrorDomain=@"NSCocoaErrorDomain",*NSUnderlyingErrorKey=@"NSUnderlyingErrorKey",*NSFilePathErrorKey=@"NSFilePathErrorKey";
@interface NSError : NSObject { @public NSString *domain; NSInteger code; NSDictionary *info; }
+ (id)errorWithDomain:(NSString *)d code:(NSInteger)c userInfo:(NSDictionary *)i;
@end
@implementation NSError
+ (id)errorWithDomain:(NSString *)d code:(NSInteger)c userInfo:(NSDictionary *)i {NSError *e=[self new];e->domain=d;e->code=c;e->info=i;return e;}
@end
@interface NSData : NSObject { void *storage; NSUInteger size; }
+ (id)dataWithBytesNoCopy:(void *)bytes length:(NSUInteger)n;
- (void *)bytes; - (NSUInteger)length;
@end
@implementation NSData
+ (id)dataWithBytesNoCopy:(void *)bytes length:(NSUInteger)n {NSData *o=[self new];o->storage=bytes;o->size=n;return o;}
- (void *)bytes {return storage;} - (NSUInteger)length {return size;}
@end
typedef NSString *CFStringRef;
typedef long CFIndex;
static const char *fixtureFileBytes(NSString *s) {return object_getClass(s)==[Path class] ? ((Path *)s)->filesystem : [s UTF8String];}
static CFIndex CFStringGetMaximumSizeOfFileSystemRepresentation(CFStringRef s) {const char *b=fixtureFileBytes(s);return b ? strlen(b)+1 : 2;}
static BOOL CFStringGetFileSystemRepresentation(CFStringRef s,char *b,CFIndex n) {const char *p=fixtureFileBytes(s);if(!p||strlen(p)>=(size_t)n)return NO;strcpy(b,p);return YES;}
PATH_HELPER
static NSError *NSFileReadError(int code,NSString *path) {return [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];}
READ_METHOD
WRITE_METHOD
BYTE_ENUMS
@interface NSByteCountFormatter : NSObject { @public NSByteCountFormatterUnits _allowedUnits; NSInteger _countStyle,_formattingContext; BOOL _adaptive,_allowsNonnumericFormatting,_includesUnit,_includesCount,_includesActualByteCount,_zeroPadsFractionDigits; }
- (NSString *)stringFromByteCount:(long long)byteCount;
@end
static NSArray *_NSByteCountFormatterUnits;
@implementation NSByteCountFormatter
BYTE_METHOD
@end
COMPARE_HELPERS
@interface NSFileManager : NSObject
- (const char *)fileSystemRepresentationWithPath:(NSString *)path;
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory;
- (BOOL)contentsEqualAtPath:(NSString *)path1 andPath:(NSString *)path2;
@end
@implementation NSFileManager
- (const char *)fileSystemRepresentationWithPath:(NSString *)path { if(!path||![path length]) {fputs("FAIL throwing public conversion used for empty file operation\n",stderr);abort();} return [path fileSystemRepresentation]; }
EXISTS_METHOD
COMPARE_METHOD
@end
@interface NSFilesystemItemRemoveOperation : NSObject
+ (NSError *)_errorWithErrno:(int)err atPath:(NSString *)path;
@end
@implementation NSFilesystemItemRemoveOperation
ERROR_METHOD
@end
static void expect(NSString *got,const char *wanted) {if(!got||strcmp([got UTF8String],wanted)){fprintf(stderr,"got %s, expected %s\n",got?[got UTF8String]:"nil",wanted);exit(1);}}
int main(int argc,char **argv) {
 assert(argc==2);
 if(!strcmp(argv[1],"byte")) {
  _NSByteCountFormatterUnits=[[NSArray alloc]initWithObjects:@"bytes",@"KB",@"MB",@"GB",@"TB",@"PB",@"EB",@"ZB",@"YB",nil];
  NSByteCountFormatter *f=[NSByteCountFormatter new];f->_includesCount=YES;f->_allowedUnits=NSByteCountFormatterUseBytes;
  long long values[]={-12,-1,0,1,2,42,999,LLONG_MIN,LLONG_MAX};
  for(int style=0;style<4;style++)for(int flags=0;flags<4;flags++) {
   f->_countStyle=style;f->_adaptive=flags&1;f->_zeroPadsFractionDigits=(flags&2)!=0;
   for(unsigned i=0;i<sizeof(values)/sizeof(values[0]);i++){char expected[40];snprintf(expected,sizeof expected,"%lld",values[i]);expect([f stringFromByteCount:values[i]],expected);}
  }
  f->_includesUnit=YES;expect([f stringFromByteCount:1],"1 byte");expect([f stringFromByteCount:-1],"-1 byte");
  f->_countStyle=NSByteCountFormatterCountStyleDecimal;f->_adaptive=YES;f->_zeroPadsFractionDigits=NO;f->_allowedUnits=NSByteCountFormatterUseKB;
  expect([f stringFromByteCount:12000],"12 KB");expect([f stringFromByteCount:-12000],"-12 KB");
  f->_allowedUnits=NSByteCountFormatterUseMB;expect([f stringFromByteCount:1250000],"1.2 MB");
  f->_zeroPadsFractionDigits=YES;expect([f stringFromByteCount:1000000],"1.0 MB");
  f->_allowedUnits=NSByteCountFormatterUseKB|NSByteCountFormatterUseGB;expect([f stringFromByteCount:1000000],"1000 KB");
  f->_adaptive=NO;f->_zeroPadsFractionDigits=NO;f->_allowedUnits=NSByteCountFormatterUseKB;
  expect([f stringFromByteCount:12345000],"12345 KB");expect([f stringFromByteCount:-12345000],"-12345 KB");
  expect([f stringFromByteCount:12345],"12.3 KB");f->_zeroPadsFractionDigits=YES;expect([f stringFromByteCount:12000],"12.0 KB");
  f->_allowedUnits=NSByteCountFormatterUseBytes;f->_includesActualByteCount=YES;expect([f stringFromByteCount:42],"42 bytes");
  f->_includesCount=NO;expect([f stringFromByteCount:42],"bytes");f->_includesUnit=NO;expect([f stringFromByteCount:42],"");
  puts("PASS byte: 144 signed/exact byte cases, units, scale, precision and output flags (numeric formatter double)");
 } else if(!strcmp(argv[1],"compare")) {
  if(!class_getInstanceMethod([NSFileManager class],@selector(contentsEqualAtPath:andPath:))){puts("FAIL missing contentsEqualAtPath:andPath:");return 1;}
  char left[]="/tmp/qv-compare-left-XXXXXX",right[]="/tmp/qv-compare-right-XXXXXX";
  int a=mkstemp(left),b=mkstemp(right);assert(a>=0&&b>=0&&close(a)==0&&close(b)==0);
  NSFileManager *fm=[NSFileManager new];
  assert([fm contentsEqualAtPath:[NSString from:left] andPath:[NSString from:right]]);
  assert(unlink(left)==0&&unlink(right)==0);puts("PASS production contentsEqualAtPath dispatch, equal empty files");
 } else if(!strcmp(argv[1],"path")) {
  char directory[]="/tmp/qv-path-XXXXXX";assert(mkdtemp(directory));
  char fs[1024],utf8[1024];snprintf(fs,sizeof fs,"%s/e\xcc\x81",directory);snprintf(utf8,sizeof utf8,"%s/\xc3\xa9",directory);
  assert(mkdir(fs,0700)==0);Path *p=[Path new];p->bytes=utf8;p->filesystem=fs;
  NSFileManager *fm=[NSFileManager new];BOOL isDir=NO;
  if(![fm fileExistsAtPath:p isDirectory:&isDir]||!isDir){assert(rmdir(fs)==0&&rmdir(directory)==0);puts("FAIL existence used UTF8String instead of filesystem representation");return 1;}
  assert([fm contentsEqualAtPath:p andPath:p]);assert(![fm contentsEqualAtPath:nil andPath:p]);
  assert(rmdir(fs)==0&&rmdir(directory)==0);puts("PASS filesystem representation: production existence and contents-comparison methods");
 } else if(!strcmp(argv[1],"empty")) {
  NSFileManager *fm=[NSFileManager new];BOOL isDir=YES;
  assert(![fm fileExistsAtPath:@"" isDirectory:&isDir]);
  assert(![fm fileExistsAtPath:nil isDirectory:NULL]);
  assert(![fm contentsEqualAtPath:@"" andPath:@""]);
  assert(![fm contentsEqualAtPath:@"." andPath:@""]);
  assert(![fm contentsEqualAtPath:nil andPath:@"."]);
  Path *invalid=[Path new];invalid->bytes="invalid";invalid->filesystem=NULL;
  assert(![fm fileExistsAtPath:invalid isDirectory:NULL]);
  assert(![fm contentsEqualAtPath:invalid andPath:@"."]);
  puts("PASS empty/nil/unrepresentable paths return NO without calling throwing conversion");
 } else if(!strcmp(argv[1],"io")) {
  char file[]="/tmp/qv-path-io-XXXXXX";int fd=mkstemp(file);assert(fd>=0);assert(write(fd,"abc",3)==3);close(fd);
  Path *p=[Path new];p->bytes="/missing/utf8-spelling";p->filesystem=file;
  NSUInteger n=99;BOOL vm=NO;NSError *error=nil;
  void *bytes=_NSReadBytesFromFile(p,0,&n,&vm,&error);assert(bytes&&n==3&&!memcmp(bytes,"abc",3));free(bytes);
  NSData *data=[NSData dataWithBytesNoCopy:strdup("def") length:3];
  assert(_NSWriteBytesToFile(data,p,0,&error));
  bytes=_NSReadBytesFromFile(p,0,&n,&vm,&error);assert(bytes&&n==3&&!memcmp(bytes,"def",3));free(bytes);
  assert(!_NSReadBytesFromFile(@"",0,&n,&vm,&error)&&n==0&&error);
  assert(!_NSReadBytesFromFile(nil,0,&n,&vm,&error));
  assert(!_NSWriteBytesToFile(data,@"",NSDataWritingAtomic,&error));
  assert(pathRepresentationCalls==0);
  assert(unlink(file)==0);
  puts("PASS NSData read/write filesystem encoding and empty failures without defaultManager bootstrap");
 } else if(!strcmp(argv[1],"error")) {
  NSError *e=[NSFilesystemItemRemoveOperation _errorWithErrno:ENOENT atPath:@"missing"];
  expect(e->domain,"NSCocoaErrorDomain");assert(e->code==4);NSError *under=[e->info objectForKey:NSUnderlyingErrorKey];assert(under&&under->code==ENOENT);expect(under->domain,"NSPOSIXErrorDomain");
  expect([e->info objectForKey:NSFilePathErrorKey],"missing");
  e=[NSFilesystemItemRemoveOperation _errorWithErrno:ENOENT atPath:nil];assert(e->code==4);
  e=[NSFilesystemItemRemoveOperation _errorWithErrno:EACCES atPath:@"denied"];assert(e->code==EACCES);expect(e->domain,"NSPOSIXErrorDomain");
  puts("PASS removal error: Cocoa/4, underlying POSIX/ENOENT, path and nil path, unchanged other errors");
 } else return 2;
 return 0;
}
