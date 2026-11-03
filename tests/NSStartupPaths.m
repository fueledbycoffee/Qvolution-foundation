// Authored public-API boundary checks. No app binaries or app output used.
// Rung 3: Apple JSON URLs in ../REFERENCES.md; rung 4 pending qv-diff.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

static NSString *yes(BOOL b) { return b ? @"YES" : @"NO"; }
static void emit(NSString *key, NSString *value) {
    printf("%s: %s\n",[key UTF8String],[value UTF8String]); fflush(stdout);
}
#define F(key,...) do { @try { emit((key),(__VA_ARGS__)); } @catch(NSException *e) { emit((key),[@"EXCEPTION " stringByAppendingString:e.name]); } } while(0)
static NSString *key(NSString *api,NSString *kind) { return [NSString stringWithFormat:@"%@( %@ )",api,kind]; }
static NSString *hex(const char *p) {
    if (!p) return @"NULL";
    NSMutableString *s=[NSMutableString string];
    for (const unsigned char *b=(const unsigned char *)p;*b;b++) [s appendFormat:@"%02x",*b];
    return s;
}
static void conversion(NSFileManager *m,NSString *kind,NSString *path,BOOL showBytes) {
    F(key(@"NSString.fileSystemRepresentation",kind),showBytes?hex([path fileSystemRepresentation]):yes([path fileSystemRepresentation]!=NULL));
    F(key(@"NSFileManager.fileSystemRepresentationWithPath",kind),showBytes?hex([m fileSystemRepresentationWithPath:path]):yes([m fileSystemRepresentationWithPath:path]!=NULL));
    for (NSUInteger n=showBytes?0:4096;n<=(showBytes?16:4096);n++) {
        char buffer[4096]; memset(buffer,0x5a,sizeof buffer);
        F(key([NSString stringWithFormat:@"NSString.getFileSystemRepresentation.max%lu",(unsigned long)n],kind),yes([path getFileSystemRepresentation:buffer maxLength:n]));
    }
}
static void operations(NSFileManager *m,NSString *kind,NSString *p) {
    NSData *data=[@"chess resource payload" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *a=[p stringByAppendingPathComponent:@"é.txt"],*b=[p stringByAppendingPathComponent:@"copy.txt"],*c=[p stringByAppendingPathComponent:@"moved.txt"],*l=[p stringByAppendingPathComponent:@"link"];
    F(key(@"NSFileManager.createDirectoryAtPath",kind),yes([m createDirectoryAtPath:p withIntermediateDirectories:NO attributes:nil error:NULL]));
    F(key(@"NSFileManager.fileExistsAtPath.isDirectory",kind),(^NSString *{BOOL d=NO;BOOL ok=[m fileExistsAtPath:p isDirectory:&d];return [NSString stringWithFormat:@"%@,directory=%@",yes(ok),yes(d)];}()));
    F(key(@"NSFileManager.createFileAtPath",kind),yes([m createFileAtPath:a contents:data attributes:nil]));
    F(key(@"NSData.writeToFile.atomic",kind),yes([data writeToFile:a options:NSDataWritingAtomic error:NULL]));
    F(key(@"NSData.initWithContentsOfFile",kind),yes([[[NSData alloc] initWithContentsOfFile:a options:0 error:NULL] isEqualToData:data]));
    F(key(@"NSFileManager.contentsAtPath",kind),yes([[m contentsAtPath:a] isEqualToData:data]));
    F(key(@"NSFileManager.attributesOfItemAtPath",kind),yes([m attributesOfItemAtPath:a error:NULL]!=nil));
    F(key(@"NSFileManager.fileAttributesAtPath.traverseYES",kind),yes([m fileAttributesAtPath:a traverseLink:YES]!=nil));
    F(key(@"NSFileManager.fileAttributesAtPath.traverseNO",kind),yes([m fileAttributesAtPath:a traverseLink:NO]!=nil));
    F(key(@"NSFileManager.copyItemAtPath",kind),yes([m copyItemAtPath:a toPath:b error:NULL]));
    F(key(@"NSFileManager.contentsEqualAtPath.copy",kind),yes([m contentsEqualAtPath:a andPath:b]));
    F(key(@"NSFileManager.moveItemAtPath",kind),yes([m moveItemAtPath:b toPath:c error:NULL]));
    F(key(@"NSFileManager.createSymbolicLinkAtPath",kind),yes([m createSymbolicLinkAtPath:l withDestinationPath:@"é.txt" error:NULL]));
    F(key(@"NSFileManager.destinationOfSymbolicLinkAtPath",kind),yes([[[m destinationOfSymbolicLinkAtPath:l error:NULL] decomposedStringWithCanonicalMapping] isEqualToString:[@"é.txt" decomposedStringWithCanonicalMapping]]));
    F(key(@"NSFileManager.contentsOfDirectoryAtPath",kind),[NSString stringWithFormat:@"%lu",(unsigned long)[[m contentsOfDirectoryAtPath:p error:NULL] count]]);
    F(key(@"NSFileManager.contentsOfDirectoryAtURL",kind),[NSString stringWithFormat:@"%lu",(unsigned long)[[m contentsOfDirectoryAtURL:[NSURL fileURLWithPath:p] includingPropertiesForKeys:@[NSURLIsRegularFileKey] options:0 error:NULL] count]]);
    F(key(@"NSFileManager.createDirectoryAtURL",kind),yes([m createDirectoryAtURL:[NSURL fileURLWithPath:[p stringByAppendingPathComponent:@"nested"]] withIntermediateDirectories:NO attributes:nil error:NULL]));
    F(key(@"NSFileManager.removeItemAtPath",kind),yes([m removeItemAtPath:l error:NULL]));
}
static void invalidOperations(NSFileManager *m,NSString *kind,NSString *p,NSString *valid) {
    NSData *data=[@"x" dataUsingEncoding:NSUTF8StringEncoding];
    F(key(@"NSFileManager.fileExistsAtPath",kind),yes([m fileExistsAtPath:p]));
    F(key(@"NSFileManager.attributesOfItemAtPath",kind),[m attributesOfItemAtPath:p error:NULL]?@"value":@"nil");
    F(key(@"NSFileManager.fileAttributesAtPath",kind),[m fileAttributesAtPath:p traverseLink:NO]?@"value":@"nil");
    F(key(@"NSFileManager.contentsEqualAtPath.self",kind),yes([m contentsEqualAtPath:p andPath:p]));
    F(key(@"NSFileManager.contentsEqualAtPath.left",kind),yes([m contentsEqualAtPath:p andPath:valid]));
    F(key(@"NSFileManager.contentsEqualAtPath.right",kind),yes([m contentsEqualAtPath:valid andPath:p]));
    F(key(@"NSData.initWithContentsOfFile",kind),[[NSData alloc] initWithContentsOfFile:p options:0 error:NULL]?@"value":@"nil");
    F(key(@"NSData.writeToFile",kind),yes([data writeToFile:p options:0 error:NULL]));
    F(key(@"NSData.writeToFile.atomic",kind),yes([data writeToFile:p options:NSDataWritingAtomic error:NULL]));
    F(key(@"NSFileManager.contentsAtPath",kind),[m contentsAtPath:p]?@"value":@"nil");
    F(key(@"NSFileManager.destinationOfSymbolicLinkAtPath",kind),[m destinationOfSymbolicLinkAtPath:p error:NULL]?@"value":@"nil");
    F(key(@"NSFileManager.contentsOfDirectoryAtPath",kind),[m contentsOfDirectoryAtPath:p error:NULL]?@"value":@"nil");
    F(key(@"NSFileManager.copyItemAtPath.source",kind),yes([m copyItemAtPath:p toPath:@"bad-copy" error:NULL]));
    F(key(@"NSFileManager.copyItemAtPath.destination",kind),yes([m copyItemAtPath:valid toPath:p error:NULL]));
    F(key(@"NSFileManager.moveItemAtPath.source",kind),yes([m moveItemAtPath:p toPath:@"bad-move" error:NULL]));
    F(key(@"NSFileManager.moveItemAtPath.destination",kind),yes([m moveItemAtPath:valid toPath:p error:NULL]));
    F(key(@"NSFileManager.createSymbolicLinkAtPath",kind),yes([m createSymbolicLinkAtPath:p withDestinationPath:@"target" error:NULL]));
    F(key(@"NSFileManager.createSymbolicLinkAtPath.destination",kind),yes([m createSymbolicLinkAtPath:@"invalid-link" withDestinationPath:p error:NULL]));
    [m removeItemAtPath:@"invalid-link" error:NULL];
    F(key(@"NSFileManager.createDirectoryAtPath",kind),yes([m createDirectoryAtPath:p withIntermediateDirectories:NO attributes:nil error:NULL]));
}
int main(void) { @autoreleasepool {
    // First Foundation file read deliberately precedes NSFileManager/NSBundle use.
    char first[]="/tmp/qv-bootstrap-XXXXXX";int fd=mkstemp(first);if(fd<0)return 2;
    if(write(fd,"boot",4)!=4)return 2;close(fd);
    F(@"NSData.bootstrap.beforeDefaultManager",yes([[[NSData alloc] initWithContentsOfFile:[NSString stringWithUTF8String:first]] isEqualToData:[@"boot" dataUsingEncoding:NSUTF8StringEncoding]]));
    unlink(first);
    NSFileManager *m=[NSFileManager defaultManager];
    conversion(m,@"ascii",@"/tmp/Chess.app/Contents/Resources/default.plist",YES);
    conversion(m,@"spaces",@"/tmp/Chess Test.app/Contents/Resources/default.plist",YES);
    conversion(m,@"NFC",@"/tmp/é",YES);conversion(m,@"NFD",@"/tmp/e\u0301",YES);
    conversion(m,@"relative",@"../Resources/./a b",YES);conversion(m,@"empty",@"",YES);
    conversion(m,@"nil",nil,YES);
    const char latin[]={ '/', 't','m','p','/',(char)0xe9 };
    NSString *legacy=[[NSString alloc] initWithBytes:latin length:sizeof latin encoding:NSISOLatin1StringEncoding];
    conversion(m,@"Latin1CString",legacy,YES);
    unichar bad=0xd800;NSString *unpaired=[[NSString alloc] initWithCharacters:&bad length:1];
    conversion(m,@"unpairedSurrogate",unpaired,YES);
    unichar zero[]={'a',0,'b'};NSString *nul=[[NSString alloc] initWithCharacters:zero length:3];
    conversion(m,@"embeddedNUL",nul,YES);
    conversion(m,@"overlong",[@"x" stringByPaddingToLength:5000 withString:@"x" startingAtIndex:0],NO);
    conversion(m,@"supplementaryUnicode",@"/tmp/棋♞😀",YES);
    conversion(m,@"bundleResourcePath",[[NSBundle mainBundle] resourcePath],NO);
    conversion(m,@"preferences",[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/test.plist"],NO);
    conversion(m,@"temporary",NSTemporaryDirectory(),NO);
    conversion(m,@"caches",[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) firstObject],NO);
    char template[]="/tmp/qv-startup-paths-XXXXXX";char *dir=mkdtemp(template);if(!dir)return 2;
    NSString *root=[m stringWithFileSystemRepresentation:dir length:strlen(dir)],*cwd=[m currentDirectoryPath];
    if(![m changeCurrentDirectoryPath:root])return 2;
    @try {
        for(NSString *name in @[@"ascii",@"with spaces",@"é",@"e\u0301",@"棋♞😀",@"Bundle Test.app/Contents/Resources",@"Library/Preferences",@"Library/Caches",@"tmp"]){
            NSString *parent=[name stringByDeletingLastPathComponent];
            if(parent.length)[m createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:NULL];
            // Distinct NFC/NFD names can refer to the same directory on macOS.
            [m removeItemAtPath:name error:NULL];operations(m,name,name);
        }
        NSString *valid=@"valid";[@"payload" writeToFile:valid atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        invalidOperations(m,@"empty",@"",valid);invalidOperations(m,@"nil",nil,valid);
        invalidOperations(m,@"unpairedSurrogate",unpaired,valid);
        invalidOperations(m,@"overlong",[@"x" stringByPaddingToLength:5000 withString:@"x" startingAtIndex:0],valid);
        F(@"NSFileManager.contentsEqualAtPath.missing",yes([m contentsEqualAtPath:@"missing" andPath:@"missing"]));
        [m createSymbolicLinkAtPath:@"dangling-a" withDestinationPath:@"missing" error:NULL];
        [m createSymbolicLinkAtPath:@"dangling-b" withDestinationPath:@"missing" error:NULL];
        F(@"NSFileManager.contentsEqualAtPath.dangling",yes([m contentsEqualAtPath:@"dangling-a" andPath:@"dangling-b"]));
        F(@"NSFileManager.contentsEqualAtPath.directorySelf",yes([m contentsEqualAtPath:@"ascii" andPath:@"ascii"]));
        F(@"NSFileManager.contentsEqualAtPath.directories",yes([m contentsEqualAtPath:@"ascii" andPath:@"with spaces"]));
        [@"different" writeToFile:@"with spaces/moved.txt" atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        F(@"NSFileManager.contentsEqualAtPath.directoriesDifferent",yes([m contentsEqualAtPath:@"ascii" andPath:@"with spaces"]));
    } @finally {
        if(![m changeCurrentDirectoryPath:cwd]||![m removeItemAtPath:root error:NULL])return 3;
    }
} return 0; }
