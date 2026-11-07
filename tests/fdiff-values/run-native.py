#!/usr/bin/env python3
"""Compile verbatim production regions against explicit storage/API doubles.
Run once before and once after each fix. Full runtime/lifetime checks use qv-diff.
"""
import argparse, pathlib, subprocess
P=pathlib.Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--foundation',default='HEAD');a.add_argument('--corefoundation',default='HEAD');a.add_argument('--output',type=pathlib.Path,required=True);a.add_argument('--expect-failure',action='store_true');a.add_argument('--sections',nargs='+',default=['json','error','decimal','kvc','regex','value','formatter','data','predicate','number','identity','index','join','number2']);o=a.parse_args();o.output.mkdir(parents=True,exist_ok=True)
def source(repo,revision,name):
 if revision=='WORKTREE':return (repo/name).read_text()
 return subprocess.check_output(['git','-C',str(repo),'show',revision+':'+name],text=True)
def region(s,start,end):
 b=s.index(start);return s[b:s.index(end,b)]
s=source(P,o.foundation,'src/NSJSONSerialization.m')
reader=region(s,'@implementation _NSJSONReader','static inline BOOL writeString(')
a=reader.index('- (id)parseStream:');b=reader.index('static inline unichar incrementBuffer',a);reader=reader[:a]+reader[b:]
# Existing parser's later-defined function gets a forward declaration for modern C.
reader=reader.replace('static inline NSDictionary *parseDictionary(_NSJSONReader *reader, unichar **buffer, NSJSONReadingOptions opts, NSUInteger depth)\n{','static inline void handleParseFailure(_NSJSONReader *reader, JSONError failure);\n\nstatic inline NSDictionary *parseDictionary(_NSJSONReader *reader, unichar **buffer, NSJSONReadingOptions opts, NSUInteger depth)\n{')
(o.output/'reader.inc').write_text(reader)
s=source(P,o.foundation,'src/NSDecimal.m');s='\n'.join(l for l in s.splitlines() if not l.startswith('#import'))
header=source(P,o.foundation,'include/Foundation/NSDecimal.h').split('FOUNDATION_EXPORT void NSDecimalCopy',1)[1]
header='void NSDecimalCopy'+header;header=header.replace('FOUNDATION_EXPORT ','')
(o.output/'decimal.inc').write_text(header+'\n'+s)
s=source(P,o.foundation,'src/NSDecimalNumber.m')
methods=region(s,'- (NSString *)description\n','\n@end')
# Placeholder initializer only.
part=s[s.index('@implementation NSDecimalNumberPlaceholder'):]
methods+='\n'+region(part,'- (id)initWithString:(NSString *)numberValue locale:locale','- (id)initWithString:(NSString *)numberValue\n')
methods+='\n'+region(s,'- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)decimalNumber withBehavior:', '- (NSDecimalNumber *)decimalNumberBySubtracting:')
(o.output/'decimal-number.inc').write_text(methods)
s=source(P.parent/'corefoundation',o.corefoundation,'NSError.m').split('@implementation __NSCFError')[0]
methods=''
if '- (BOOL)isEqual:(id)other' in s:methods=region(s,'- (BOOL)isEqual:(id)other','- (id)copyWithZone:')
(o.output/'error.inc').write_text(methods)
s=source(P,o.foundation,'src/NSArray.m')
methods=region(s,'- (id)valueForKey:(id)key','- (id)valueForKeyPath:')
(o.output/'array-kvc.inc').write_text(methods)
s=source(P,o.foundation,'src/NSSet.m')
(o.output/'set-kvc.inc').write_text(region(s,'- (id)_distinctUnionOfSetsForKeyPath:','- (id)_distinctUnionOfArraysForKeyPath:'))
s=source(P,o.foundation,'src/NSRegularExpression.m')
s='\n'.join(l for l in s.splitlines() if not l.startswith('#import'))
(o.output/'regex.inc').write_text(s)
s=source(P,o.foundation,'include/Foundation/NSRegularExpression.h')
s='\n'.join(l for l in s.splitlines() if not l.startswith('#import'))
s=s[:s.index('@interface NSDataDetector')]
s=s.replace('typedef NS_OPTIONS(NSUInteger, ', 'enum ').replace(') {',' {')
for name in ['NSRegularExpressionOptions','NSMatchingOptions','NSMatchingFlags']:
 s='typedef NSUInteger '+name+';\n'+s
s=s.replace('<NSCopying, NSCoding>','').replace('#if NS_BLOCKS_AVAILABLE','#if 1')
(o.output/'regex-declarations.inc').write_text('@class NSTextCheckingResult;\n'+s)
s=source(P,o.foundation,'src/NSValue.m');methods=''
if '- (void)getValue:(void *)value size:' in s:methods=region(s,'- (void)getValue:(void *)value size:', '- (const char *)objCType\n')
(o.output/'value.inc').write_text(methods)
s=source(P,o.foundation,'src/NSNumberFormatter.m')
(o.output/'formatter.inc').write_text(region(s,'- (NSNumber *)numberFromString:','- (NSNumberFormatterStyle)numberStyle').replace('_attributes[@"parseIntegersOnly"]','[_attributes objectForKey:@"parseIntegersOnly"]'))
s=source(P,o.foundation,'src/NSData.m')
lookup=region(s,'#define xx 65','- (id)initWithBase64EncodedData:')
method=region(s,'- (id)initWithBase64EncodedData:','#undef xx')
(o.output/'data.inc').write_text(lookup+method+'\n#undef xx\n#undef EQ\n')
s=source(P,o.foundation,'src/NSVariableExpression.m')
(o.output/'variable.inc').write_text(region(s,'- (NSExpression *)_expressionWithSubstitutionVariables:','- (id)expressionValueWithObject:'))
s=source(P.parent/'corefoundation',o.corefoundation,'NSNumber.m')
part=region(s,'- (NSComparisonResult)compare:(id)other','- (NSComparisonResult)_reverseCompare:')
part+='\n'+region(s,'#define GET_VALUE(', '- (float)floatValue')
part+='\n'+region(s,'- (id)stringValue\n','- (id)description\n')
(o.output/'cf-number.inc').write_text(part)
for file,cls,name in [('NSArray.m','__NSCFArray','array'),('NSDictionary.m','__NSCFDictionary','dictionary'),('NSString.m','__NSCFString','string')]:
 s=source(P.parent/'corefoundation',o.corefoundation,file);part=s.split('@implementation '+cls+'\n',1)[1].split('\n@end',1)[0]
 methods=''
 if '- (BOOL)isKindOfClass:(Class)cls' in part:
  methods=region(part,'- (BOOL)isKindOfClass:(Class)cls','\n}').rstrip()+'\n}\n'
 (o.output/('cf-'+name+'-kind.inc')).write_text(methods)
s=source(P.parent/'corefoundation',o.corefoundation,'NSArray.m')
(o.output/'array-constructor.inc').write_text(region(s,'+ (instancetype)arrayWithObject:(id)obj','+ (instancetype)arrayWithObjects:'))
s=source(P,o.foundation,'src/NSIndexSet.m')
macros=region(s,'typedef struct RangeList {','@implementation NSIndexSet')
header=source(P,o.foundation,'include/Foundation/NSIndexSet.h')
declaration=region(header,'@interface NSIndexSet :','+ (instancetype)indexSet;').replace('<NSCopying, NSMutableCopying, NSCoding>','').replace('@package','@public')
declaration+='- (void)enumerateRangesUsingBlock:(void (^)(NSRange,BOOL *))block;\n- (RangeList *)_pointerToRangeBeforeOrContainingIndex:(NSUInteger)i;\n@end\n@interface NSMutableIndexSet : NSIndexSet\n- (void)addIndexesInRange:(NSRange)r; - (void)removeIndexesInRange:(NSRange)r; - (void)removeAllIndexes; - (void)addIndex:(NSUInteger)i; - (void)addIndexes:(NSIndexSet *)s; - (void)shiftIndexesStartingAtIndex:(NSUInteger)i by:(NSInteger)d;\n@end\n'
(o.output/'index-declarations.inc').write_text(macros+declaration)
start='// Shift a range, possibly truncating at 0' if '// Shift a range, possibly truncating at 0' in s else '- (void)shiftIndexesStartingAtIndex:'
(o.output/'index-shift.inc').write_text(region(s,start,'\n@end'))
(o.output/'index-add.inc').write_text(region(s,'static inline void addIndexesInRange(', 'static inline CFComparisonResult NSIndexSetCompareEntry'))
(o.output/'index-remove.inc').write_text(region(s,'- (void)removeIndexesInRange:', start))
(o.output/'index-merge.inc').write_text(region(s,'- (void)_mergeOverlappingRangesStartingAtIndex:', '- (void)_setContentToContentFromIndexSet:'))
(o.output/'index-add-set.inc').write_text(region(s,'- (void)addIndexes:(NSIndexSet *)indexSet', '- (void)removeIndexes:(NSIndexSet *)indexSet'))
(o.output/'index-clear.inc').write_text(region(s,'- (void)removeAllIndexes', '- (void)addIndex:'))
s=source(P.parent/'corefoundation',o.corefoundation,'NSArray.m')
(o.output/'array-join.inc').write_text(region(s,'- (NSString *)componentsJoinedByString:', '- (BOOL)containsObject:'))
command=['/usr/bin/clang','-g','-O0','-fblocks','-Xclang','-fobjc-subscripting-legacy-runtime','-fobjc-exceptions','-fexceptions','-fconstant-string-class=NSConstantString','-Wno-objc-method-access','-Wno-incompatible-pointer-types','-Wno-protocol','-Wno-incomplete-implementation','-Wno-int-conversion','-I'+str(P/'src'),'-I'+str(o.output),'-I'+subprocess.check_output(['gcc','-print-file-name=include'],text=True).strip(),str(P/'tests/fdiff-values/native.m'),'-l:libobjc.so.4','-lm','-licui18n','-licuuc','-o',str(o.output/'fixture')]
r=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(o.output/'build.log').write_bytes(r.stdout)
if r.returncode:print(r.stdout.decode()[-8000:]);raise SystemExit(r.returncode)
for section in o.sections:
 r=subprocess.run([str(o.output/'fixture'),section],stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(o.output/(section+'.log')).write_bytes(r.stdout);print(section,r.returncode,r.stdout.decode().strip())
 assert r.returncode == (1 if o.expect_failure else 0),section
