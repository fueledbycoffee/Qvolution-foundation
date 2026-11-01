#!/usr/bin/env python3
"""Compile an old-header client and compare fragile/nonfragile layouts and symbols.

Native source compilation only; no Foundation library or Apple binaries needed.
Optional --header can exercise a header from another revision as a negative control.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--header', type=Path, default=root / 'include/Foundation/NSArchiver.h')
args = parser.parse_args()
old = subprocess.check_output(['git', '-C', str(root), 'show',
                               'ee56002:include/Foundation/NSArchiver.h'], text=True)
prelude = '''
typedef unsigned long NSUInteger; typedef long NSInteger; typedef unsigned char uint8_t;
typedef signed char BOOL; typedef void *CFMutableDictionaryRef; typedef void *CFMutableSetRef;
typedef void NSZone;
__attribute__((objc_root_class)) @interface NSObject { Class isa; } @end
@interface NSCoder : NSObject @end
@class NSString, NSData, NSMutableData, NSMutableArray, NSNumber;
@interface NSMutableDictionary<KeyType, ValueType> : NSObject @end
'''
client = '''
@implementation NSArchiver @end
@implementation NSUnarchiver @end
@interface OldArchiverClient : NSArchiver @end
@implementation OldArchiverClient
- (NSUInteger)legacyCounters { return _nextObjectLabel + _nextClassLabel; }
- (id)legacyStrings { return _sharedStrings; }
@end
@interface OldUnarchiverClient : NSUnarchiver @end
@implementation OldUnarchiverClient
- (NSUInteger)legacyCounters { return _sharedObjectCounter + _sharedClassCounter; }
- (id)legacyVersions { return _versionByClassName; }
@end
'''
with tempfile.TemporaryDirectory(prefix='nsarchiver-abi-') as directory:
    for arch in ('i386', 'x86_64'):
        results = []
        for header in (old, args.header.read_text()):
            header = '\n'.join(line for line in header.splitlines() if not line.startswith('#import'))
            result = subprocess.check_output(['clang', '-target', arch + '-apple-macosx10.10',
                '-Wno-incomplete-implementation', '-Wno-objc-property-implementation',
                '-Wno-objc-root-class', '-S', '-emit-llvm', '-x', 'objective-c', '-', '-o', '-'],
                input=prelude + header + client, text=True)
            results.append(result)
        assert results[0] == results[1], arch + ': old-header layout/client IR changed'
        print('PASS: ' + arch + ' old-header client, class layouts and exported ivar symbols unchanged')
