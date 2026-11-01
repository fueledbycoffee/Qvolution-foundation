/*
Copyright (C) 2015 Frank Illenberger
Copyright (C) 2020 Lubos Dolezel

*/

#import <Foundation/NSArchiver.h>
#import <Foundation/NSRaise.h>
#import <Foundation/NSData.h>
#import <Foundation/NSMutableArray.h>
#import <Foundation/NSByteOrder.h>
#import <Foundation/NSGeometry.h>
#include <CoreFoundation/CFSet.h>
#include <string.h>
#include <dispatch/dispatch.h>
#include <objc/runtime.h>

static NSMutableDictionary<NSString*,NSString*>* globalClassNameMap;

#import "NSTypedStream.h"

//#define DEBUG_NSUNARCHIVER
#ifndef DEBUG_NSUNARCHIVER
#  define NSUDEBUG(...)
#else
#  define NSUDEBUG NSLog
#endif

static const char* uniqueString(const char* str);

@implementation NSUnarchiver

+ (id)unarchiveObjectWithFile:(NSString *)path
{
   NSData* data= [NSData dataWithContentsOfFile: path];

   if (data == nil)
      return nil;

   NSUnarchiver* unarchiver = [[[NSUnarchiver alloc] initForReadingWithData: data] autorelease];

   return [unarchiver decodeObject];
}

+ (id)unarchiveObjectWithData:(NSData *)data
{
   NSUnarchiver* unarchiver = [[[NSUnarchiver alloc] initForReadingWithData: data] autorelease];
   return [unarchiver decodeObject];
}

- (NSData *)decodeDataObject
{
   int length = 0;
   NSMutableData* data;

   [self decodeValuesOfObjCTypes: "i", &length];
   if (length < 0)
      [NSException raise:NSInvalidArgumentException format:@"NSUnarchiver decodeDataObject: negative length %d", length];

   data = [[NSMutableData alloc] initWithLength: length];

   [self decodeArrayOfObjCType: "c" count: length at: [data mutableBytes]];

   return [data autorelease];
}

-(NSZone *)objectZone
{
   return _objectZone;
}

-(NSData*)data
{
   return _data;
}

-(void)setObjectZone:(NSZone *) zone
{
   _objectZone = zone;
}

+(void)initialize
{
	globalClassNameMap = [[NSMutableDictionary alloc] init];
}

- (void)dealloc
{
    [_sharedStrings release];
    [_sharedObjects release];
    if (_sharedClasses) CFRelease(_sharedClasses);
    [_versionByClassName release];
    [_classNameMap release];
    [_data release];

    [super dealloc];
}

- (id)initForReadingWithData:(NSData*)data
{
    NSParameterAssert(data.length > 0);
    
    if(self = [super init])
    {
        _data = [data copy];
        _pos = 0;
        _sharedObjects = [[NSMutableDictionary alloc] init];
        // _sharedClasses uses NULL value callbacks because Class objects are immortal runtime singletons
        _sharedClasses = (NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
        _sharedStrings = [[NSMutableArray alloc] init];
        _versionByClassName = [[NSMutableDictionary alloc] init];
        if(![self readHeader])
            return nil;
    }
    return self;
}

- (BOOL)isAtEnd
{
    return _pos >= _data.length;
}

- (NSUInteger)pos
{
    return _pos;
}
- (Class)classForName:(NSString*)className
{
   NSParameterAssert(className);

   NSString* replacement = [self classNameDecodedForArchiveClassName: className];
   if (replacement == className)
      replacement = [NSUnarchiver classNameDecodedForArchiveClassName: className];
    
   return NSClassFromString(replacement);
}

- (BOOL)readHeader
{
    signed char streamerVersion;
    if(![self decodeChar:&streamerVersion])
        return NO;
    _streamerVersion = streamerVersion;
    NSAssert(streamerVersion == 4, nil);    // we currently only support v4
    
    NSString* header;
    if(![self decodeCharsAsString:&header])
        return NO;
    
    BOOL isBig = (NSHostByteOrder() == NS_BigEndian);
    if([header isEqualToString:@"typedstream"])
        _swap = !isBig;
    else if([header isEqualToString:@"streamtyped"])
        _swap = isBig;
    else
        return NO;
    
    if(![self decodeInt: (int*)&_systemVersion])
        return NO;
    
    return YES;
}

- (unsigned)systemVersion
{
    return _systemVersion;
}

- (BOOL)readObject:(id*)outObject
{
    NSString* string;
    *outObject = nil;

    if(![self decodeSharedString:&string])
    {
       NSUDEBUG(@"NSUnarchiver readObject: decodeSharedString failed\n");
        return NO;
    }
    if(![string isEqualToString:@"@"])
    {
       NSUDEBUG(@"NSUnarchiver readObject: unexpected type: %@\n", string);
        return NO;
    }
    
    return [self _readObject:outObject];
}

// Objects, C strings and classes take labels from one counter (see NSArchiver's _takeObjectLabel:);
// classes are kept in their own table only because Class values are not retained.
- (NSNumber*)nextSharedLabel
{
    return @(_sharedObjectCounter++);
}

- (BOOL)_readObject:(id*)outObject
{
    NSParameterAssert(outObject);

    *outObject = nil;
    
    signed char ch;
    if(![self decodeChar:&ch])
    {
       NSUDEBUG(@"NSUnarchiver _readObject: failed to decode char\n");
        return NO;
    }
    
    switch(ch)
    {
        case NullLabel:
            NSUDEBUG(@"readObject -> nil\n");
            *outObject = nil;
            return YES;
            
        case NewLabel:
        {
            NSNumber* label = [self nextSharedLabel];
            NSUDEBUG(@"NSUnarchiver _readObject: new label %@, outObject at %p\n", label, outObject);
            Class objectClass;
            if(![self readClass:&objectClass])
            {
               NSUDEBUG(@"NSUnarchiver _readObject: failed to read class!\n");
                return NO;
            }
            if (!objectClass)
            {
                *outObject = nil;
                return YES;
            }
            id object = [objectClass alloc];
            if(!object)
                return NO;
            _sharedObjects[label] = object;

            id object2 = [object initWithCoder:self];
            if (object2 != object)
               NSUDEBUG(@"NSUnarchiver: This may not work out, instance changed\n");

            if (object2 != nil)
            {
                id objectAfterAwake = [object2 awakeAfterUsingCoder:self];
                if(objectAfterAwake && objectAfterAwake != object2)
                {
                    [object2 release];
                    object2 = [objectAfterAwake retain];
                }
                
                _sharedObjects[label] = object2;
                [object2 release];
            }
            else
            {
                NSUDEBUG(@"NSUnarchiver _readObject: [%@ initWithCoder:] returned nil\n", NSStringFromClass(objectClass));
                [_sharedObjects removeObjectForKey:label];
            }

            NSUDEBUG(@"Saving %p into outObject at %p\n", object2, outObject);
            *outObject = object2;
            
            signed char endMarker;
            if(![self decodeChar:&endMarker])
            {
                return NO;
            }
            if (endMarker != EndOfObjectLabel)
            {
                NSUInteger start = (_pos >= 16) ? _pos - 16 : 0;
                NSUInteger len = ((start + 64) <= _data.length) ? 64 : (_data.length - start);
                const unsigned char *b = [_data bytes];
                NSMutableString *hex = [NSMutableString string];
                for (NSUInteger i = 0; i < len; i++) {
                    if (start + i == _pos) [hex appendString: @" ["];
                    [hex appendFormat: @"%02x ", b[start + i]];
                    if (start + i == _pos) [hex appendString: @"] "];
                }
                NSLog(@"NSUnarchiver: objectClass=%@ endMarker=0x%02x (expected 0x%02x) pos=%lu/%lu around:\n%@",
                      NSStringFromClass(objectClass), ((unsigned) endMarker) & 0xff, ((unsigned) EndOfObjectLabel) & 0xff,
                      (unsigned long)_pos, (unsigned long)_data.length, hex);
                [NSException raise:NSInvalidArgumentException format:@"End of object label not found for [%@ initWithCoder:], got 0x%02x", NSStringFromClass(objectClass), ((unsigned) endMarker) & 0xff];
                return NO;
            }
            
            return YES;
        }
            
        default:
        {
            NSUDEBUG(@"readObject -> sharedObject\n");
            int label;
            if(![self finishDecodeInt:&label withChar:ch])
            {
               NSUDEBUG(@"readObject -> sharedObject: FAILED to decode int\n");
                return NO;
            }
            label = BIAS(label);
            *outObject = _sharedObjects[@(label)];
            if (!*outObject)
            {
               NSUDEBUG(@"readObject -> sharedObject: non-existent shared obj for label %d\n", label);
               return NO;
            }
            else
                NSUDEBUG(@"sharedObject is %p\n", *outObject);
            return YES;
        }
    }
}

- (BOOL)readClass:(Class*)outClass
{
    NSParameterAssert(outClass);
    
    signed char ch;
    if(![self decodeChar:&ch])
    {
       NSUDEBUG(@"NSUnarchiver readClass: decodeChar failed\n");
        return NO;
    }
    
    switch(ch)
    {
        case NullLabel:
            *outClass = Nil;
            return YES;
            
        case NewLabel:
        {
            NSString* className;
            if(![self decodeSharedString:&className])
            {
               NSUDEBUG(@"NSUnarchiver readClass: decodeSharedString failed\n");
                return NO;
            }
            int version;
            if(![self decodeInt:&version])
            {
               NSUDEBUG(@"NSUnarchiver readClass: decodeInt failed\n");
                return NO;
            }
            
            _versionByClassName[className] = @(version);
            
            *outClass = [self classForName:className];
            NSNumber* nextLabel = [self nextSharedLabel];
            if (*outClass) {
                _sharedClasses[nextLabel] = *outClass;
            }

            Class superClass = Nil;
            if(![self readClass:&superClass])
            {
               NSUDEBUG(@"NSUnarchiver readClass: failed to read super class\n");
                return NO;
            }

            if (!*outClass)
            {
                *outClass = objc_lookUpClass(className.UTF8String);
                if (!*outClass && superClass != Nil) {
                    *outClass = objc_allocateClassPair(superClass, className.UTF8String, 0);
                    if (*outClass)
                        objc_registerClassPair(*outClass);
                    else
                        *outClass = objc_lookUpClass(className.UTF8String) ?: superClass;
                }
                if (!*outClass) {
                    NSLog(@"NSUnarchiver readClass: classForName %@ failed and cannot create from superclass\n", className);
                    return NO;
                }
                _sharedClasses[nextLabel] = *outClass;
            }
            return YES;
        }
            
        default:
        {
            int label;
            if(![self finishDecodeInt:&label withChar:ch])
            {
               NSUDEBUG(@"NSUnarchiver readClass: finishDecodeInt failed\n");
                return NO;
            }
            label = BIAS(label);
            *outClass = _sharedClasses[@(label)];
            if (!*outClass)
               return NO;
            return YES;
        }
    }
}

- (BOOL)readBytes:(void*)bytes length:(NSUInteger)length
{
    NSParameterAssert(bytes);
    
    if(_pos + length > _data.length)
        return NO;
    [_data getBytes:bytes range:NSMakeRange(_pos, length)];
    _pos += length;
    return YES;
}

- (BOOL)readData:(NSData**)outData length:(NSUInteger)length
{
    NSParameterAssert(outData);
    
    if(_pos + length > _data.length)
        return NO;
    *outData = [_data subdataWithRange:NSMakeRange(_pos, length)];
    _pos += length;
    return YES;
}

- (uint8_t)decodeByte
{
   uint8_t v = 0;
   [self decodeValuesOfObjCTypes: "c", &v];
   return v;
}

- (BOOL)decodeChar:(signed char*)outChar
{
    NSParameterAssert(outChar);
    return [self readBytes:outChar length:1];
}

- (BOOL)decodeFloat:(float*)outFloat
{
    NSParameterAssert(outFloat);
    
    signed char charValue;
    if(![self decodeChar:&charValue])
        return NO;
    if(charValue != RealLabel)
    {
        int intValue;
        if(![self finishDecodeInt:&intValue withChar:charValue])
            return NO;
        *outFloat = intValue;
        return YES;
    }
    NSSwappedFloat value;
    if(![self readBytes:&value length:sizeof(NSSwappedFloat)])
        return NO;
    
    *outFloat = [self swappedFloat:value];
    
    return YES;
}

- (BOOL)decodeDouble:(double*)outDouble
{
    NSParameterAssert(outDouble);
    
    signed char charValue;
    if(![self decodeChar:&charValue])
        return NO;
    if(charValue != RealLabel)
    {
        int intValue;
        if(![self finishDecodeInt:&intValue withChar:charValue])
            return NO;
        *outDouble = intValue;
        return YES;
    }
    NSSwappedDouble value;
    if(![self readBytes:&value length:sizeof(NSSwappedDouble)])
        return NO;
    
    *outDouble = [self swappedDouble:value];
    return YES;
}

- (BOOL)decodeCharsAsString:(NSString**)outString
{
    NSParameterAssert(outString);
    
    signed char charValue;
    if(![self decodeChar:&charValue])
        return NO;
    
    if(charValue == NullLabel)
    {
        *outString = nil;
        return YES;
    }
    
    int length;
    if(![self finishDecodeInt:&length
                     withChar:charValue])
        return NO;
    if(length < 0)
        return NO;
    
    NSData* bytes;
    if(![self readData:&bytes length:length])
        return NO;
    *outString = [[[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] autorelease];
    return *outString != nil;
}

- (BOOL)decodeString:(NSString**)outString
{
    NSParameterAssert(outString);
    
    signed char charValue;
    if(![self decodeChar:&charValue])
        return NO;

    switch(charValue)
    {
        case NullLabel:
            *outString = nil;
            return YES;
            
        case NewLabel:
            if(![self decodeSharedString:outString])
                return NO;
            NSAssert(*outString, nil);

            NSNumber* nextLabel = [self nextSharedLabel];
            NSUDEBUG(@"NSunarchiver decodeString: new label %@ for string %@\n", nextLabel, *outString);
            _sharedObjects[nextLabel] = *outString;
            return YES;
        
        default:
        {
            int label;
            if(![self finishDecodeInt:&label withChar:charValue])
                return NO;
            label = BIAS(label);
            *outString = _sharedObjects[@(label)];
            if (!*outString)
               return NO;
            return YES;
        }
    }
}

- (BOOL)decodeSharedString:(NSString**)outString
{
    NSParameterAssert(outString);

    signed char ch;
    if(![self decodeChar:&ch])
        return NO;
    if(ch == NullLabel)
    {
        *outString = nil;
        return YES;
    }
    if(ch == NewLabel)
    {
        if(![self decodeCharsAsString:outString])
            return NO;
        NSAssert(*outString, nil);
        [_sharedStrings addObject:*outString];
    }
    else
    {
        int stringIndex;
        if(![self finishDecodeInt:&stringIndex
                         withChar:ch])
            return NO;
        stringIndex = BIAS(stringIndex);
        if(stringIndex >= _sharedStrings.count)
            return NO;
        *outString = _sharedStrings[stringIndex];
    }
    return YES;
}

- (BOOL)decodeShort:(short*)outShort
{
    NSParameterAssert(outShort);
    
    signed char ch;
    if(![self decodeChar:&ch])
        return NO;
    
    if(ch != Long2Label)
    {
        *outShort = ch;
        return YES;
    }
    
    short value;
    if(![self readBytes:&value length:2])
        return NO;
    
    *outShort = [self swappedShort:value];
    
    return YES;
}

- (BOOL)decodeInt:(int*)outInt
{
    NSParameterAssert(outInt);
    signed char ch;
    if(![self decodeChar:&ch])
        return NO;
    return [self finishDecodeInt:outInt withChar:ch];
}

- (BOOL)finishDecodeInt:(int*)outInt
               withChar:(signed char)charValue
{
    NSParameterAssert(outInt);
    
    switch(charValue)
    {
        case Long2Label:
        {
            short value;
            if(![self readBytes:&value length:2])
                return NO;
            *outInt = (short)[self swappedShort:value];
            break;
        }
            
        case Long4Label:
        {
            int value;
            if(![self readBytes:&value length:4])
                return NO;
            *outInt = [self swappedInt:value];
            break;
        }
            
        default:
            *outInt = charValue;
            break;
    }
    return YES;
}

- (unsigned short)swappedShort:(unsigned short)value
{
    return _swap ? NSSwapShort(value) : value;
}

- (unsigned int)swappedInt:(unsigned int)value
{
    return _swap ? NSSwapInt(value) : value;
}

- (unsigned long long)swappedLongLong:(unsigned long long)value
{
    return _swap ? NSSwapLongLong(value) : value;
}

- (float)swappedFloat:(NSSwappedFloat)value
{
    return _swap ? NSConvertSwappedFloatToHost(NSSwapFloat(value)) : NSConvertSwappedFloatToHost(value);
}

- (double)swappedDouble:(NSSwappedDouble)value
{
    return _swap ? NSConvertSwappedDoubleToHost(NSSwapDouble(value)) : NSConvertSwappedDoubleToHost(value);
}

- (BOOL)readType:(const char*)type data:(void*)data
{
   return [self readType: type data: data outType: NULL];
}

- (BOOL)readType:(const char*)type data:(void*)data outType:(const char**)outType
{
    NSParameterAssert(type);
    NSParameterAssert(data);
    
    BOOL rv = TRUE;
    char ch = type[0];
    type++;

    switch(ch)
    {
        case 'c':
        case 'C':
        {
            signed char value;
            if(![self decodeChar:&value])
            {
                rv = NO;
                break;
            }
            *((char*)data) = (char)value;
            break;
        }
            
        case 's':
        case 'S':
        {
            short value;
            if(![self decodeShort:&value])
            {
                rv = NO;
                break;
            }
            *((short*)data) = value;
            break;
        }
            
        case 'i':
        case 'I':
        case 'l':
        case 'L':
        {
            int value;
            if(![self decodeInt:&value])
            {
                rv = NO;
                break;
            }
            *((int*)data) = value;
            break;
        }

        // long long values use the same integer encoding as int.
        case 'q':
        case 'Q':
        {
            int value;
            if(![self decodeInt:&value])
            {
                rv = NO;
                break;
            }
            if(ch == 'q')
                *((long long*)data) = value;
            else
                *((unsigned long long*)data) = (unsigned int)value;
            break;
        }

        case 'f':
        {
            float value;
            if(![self decodeFloat:&value])
            {
                rv = NO;
                break;
            }
            *((float*)data) = value;
            break;
        }
            
        case 'd':
        {
            double value;
            if(![self decodeDouble:&value])
            {
                rv = NO;
                break;
            }
            *((double*)data) = value;
            break;
        }
            
        case '@':
        {
            id obj;
            if(![self _readObject:&obj])
            {
                NSUDEBUG(@"_readObject failure reported to readType\n");
                rv = NO;
                break;
            }
            *((__strong id*)data) = obj;
            break;
        }
            
        case '*':
        {
            // A C string is a shared object (a label, then a shared string), not a bare shared string.
            NSString* string;
            if(![self decodeString:&string])
            {
                rv = NO;
                break;
            }
            *((char**)data) = string ? strdup(string.UTF8String) : NULL;
            break;
        }

        case '+':
        {
            int length;
            if(![self decodeInt:&length])
            {
                rv = NO;
                break;
            }
            if (length < 0)
            {
                rv = NO;
                break;
            }
            NSData* dataBytes;
            if(![self readData:&dataBytes length:(NSUInteger)length])
            {
                rv = NO;
                break;
            }
            if (dataBytes.length > 0)
            {
                char *buf = malloc((size_t)length + 1);
                if (buf == NULL)
                {
                    rv = NO;
                    break;
                }
                memcpy(buf, dataBytes.bytes, length);
                buf[length] = '\0';
                *((char**)data) = buf;
            }
            else
            {
                *((char**)data) = NULL;
            }
            break;
        }
        case '#':
            // a class value is a class record, as for an object's class
            rv = [self readClass:(Class*)data];
            break;

        case '%':
        case ':':
        {
            NSString* string;
            if(![self decodeSharedString:&string])
            {
                rv = NO;
                break;
            }

            const char* cString = string.UTF8String;
            if (ch == '%')
               *((const char**)data) = cString ? uniqueString(cString) : NULL;
            else
               *((SEL*) data) = cString ? sel_registerName(cString) : NULL;
            break;
        }

        case '[':
        {
            unsigned int size, align;
            unsigned int count = 0;
            const char* elemType;

            while ('0' <= *type && *type <= '9')
            {
               count = 10 * count + (*type - '0');
               type++;
            }

            elemType = type;
            type = sizeofType(elemType, &size, &align);
            NSUDEBUG(@"size and alignment of %s is %d, %d\n", elemType, size, align);

            for (unsigned int idx = 0; idx < count; idx++)
            {
               if (![self readType: elemType data:((char*) data)+((size_t)idx * size)])
               {
                  rv = NO;
                  break;
               }
            }
            if (!rv)
               break;

            ch = *type;
            type++;
            if (ch != ']')
               NSUDEBUG(@"Missing ] terminator");
            break;
        }

        case '{':
        {
           unsigned int off = 0;
           type = skipStructName(type);

           while (*type != '}')
           {
              unsigned int s, a;

              sizeofType(type, &s, &a);
              off = roundUp(off, a);
              [self readType:type data:((char*) data)+off outType:&type];
              off += s;
           }
           type++;
           break;
        }

        case '(':
        {
            unsigned int s, a;
            type = sizeofType(type - 1, &s, &a);

            for (unsigned int i = 0; i < s; i++)
               [self readType:"C" data:((char*) data) + i];
            break;
        }
            
        default:
            NSLog(@"unsupported archiving type %c", ch);
            rv = NO;
    }

    if (outType)
      *outType = type;
    return rv;
}


#pragma mark - Convenience Methods

+ (id) compatibilityUnarchiveObjectWithData:(NSData*)data
                            decodeClassName:(NSString*)archiveClassName
                                asClassName:(NSString*)className
{
    NSParameterAssert(!archiveClassName || className);
    
    if(!data)
        return nil;
    
    NSUnarchiver* unarchiver = [[[NSUnarchiver alloc] initForReadingWithData:data] autorelease];
    if(archiveClassName)
        [unarchiver decodeClassName:archiveClassName asClassName:className];
    return [unarchiver decodeObject];
}

static BOOL typesAreCompatible(const char *t1, const char *t2)
{
    if (strcmp(t1, t2) == 0)
        return YES;

    if ((strcmp(t1, "+") == 0 && strcmp(t2, "*") == 0) ||
        (strcmp(t1, "*") == 0 && strcmp(t2, "+") == 0))
        return YES;

    size_t len1 = strlen(t1);
    size_t len2 = strlen(t2);
    if (len1 == len2) {
        BOOL match = YES;
        for (size_t i = 0; i < len1; i++) {
            char c1 = t1[i];
            char c2 = t2[i];
            if (c1 == c2) continue;
            // NeXT/OpenStep typedstream compatibility: '@' (id) and '#' (Class)
            if ((c1 == '@' && c2 == '#') || (c1 == '#' && c2 == '@')) continue;
            match = NO;
            break;
        }
        if (match) return YES;
    }

    char n1[256], n2[256];
    int j = 0;
    BOOL inName = NO;
    for (int i = 0; t1[i] && j < sizeof(n1) - 1; i++) {
        if (t1[i] == '{') {
            n1[j++] = '{';
            inName = YES;
        } else if (inName) {
            if (t1[i] == '=') {
                n1[j++] = '=';
                inName = NO;
            } else if (t1[i] == '}') {
                n1[j++] = '}';
                inName = NO;
            }
        } else {
            n1[j++] = t1[i];
        }
    }
    n1[j] = '\0';

    j = 0;
    inName = NO;
    for (int i = 0; t2[i] && j < sizeof(n2) - 1; i++) {
        if (t2[i] == '{') {
            n2[j++] = '{';
            inName = YES;
        } else if (inName) {
            if (t2[i] == '=') {
                n2[j++] = '=';
                inName = NO;
            } else if (t2[i] == '}') {
                n2[j++] = '}';
                inName = NO;
            }
        } else {
            n2[j++] = t2[i];
        }
    }
    n2[j] = '\0';

    if (strcasecmp(n1, n2) == 0)
        return YES;

    return NO;
}

#pragma mark - NSCoder methods

- (void)decodeValueOfObjCType:(const char*)type at:(void*)data
{
    NSParameterAssert(type);
    NSParameterAssert(data);
    
    // Make sure that even under iOS BOOLs are read with 'c' type.
    if(strcmp(type, @encode(BOOL)) == 0)
        type = "c";
    
    NSString* string;
    if(![self decodeSharedString:&string] || string.length == 0)
        return;
    
    const char* str = string.UTF8String;
    if(!typesAreCompatible(str, type))
    {
        [NSException raise:NSInvalidArgumentException format:@"NSUnarchiver decodeValueOfObjCType: wrong type in archive '%s', expected '%s'", str, type];
        return;
    }
    
    BOOL isObject = str[0] == '@';
    BOOL didRead = [self readType:str data:data];

    if (didRead && isObject)
    {
        [*((id*)data) retain];
    }
}

- (void)decodeValuesOfObjCTypes:(const char*)types, ...
{
    NSString* string;
    if(![self decodeSharedString:&string])
    {
        return;
    }

    const char *str = [string cStringUsingEncoding:NSASCIIStringEncoding];
    if(!typesAreCompatible(str, types))
    {
        [NSException raise:NSInvalidArgumentException format:@"NSUnarchiver decodeValuesOfObjCTypes: wrong types in archive '%@', expected '%s'", string, types];
        return;
    }

    va_list argList;
    va_start (argList, types);
    
    const char* archType = str;
    const char* expType = types;
    while(*archType != '\0' && *expType != '\0')
    {
        void* data = va_arg(argList, void*);
        BOOL isObject = archType[0] == '@';
        NSUDEBUG(@"next type is %c, data is %p\n", *archType, data);
        BOOL didRead = [self readType:archType data:data outType:&archType];
        unsigned s, a;
        expType = sizeofType(expType, &s, &a);

        if (didRead && isObject)
        {
            [*((id*)data) retain];
        }
    }
    
    va_end (argList);
}

// Archives written by 32-bit code store points and sizes as "ff" and rects as "ffff".
- (void)_decodeGeometry:(CGFloat*)values count:(unsigned)count type:(const char*)type legacyType:(const char*)legacyType
{
    NSString* string;
    const char* str = [self decodeSharedString:&string] ? [string cStringUsingEncoding:NSASCIIStringEncoding] : NULL;
    BOOL legacy = str && strcmp(str, legacyType) == 0;
    BOOL ok = legacy || (str && strcmp(str, type) == 0);

    for(unsigned i = 0; i < count && ok; i++)
    {
        if(legacy)
        {
            float value;
            if((ok = [self decodeFloat:&value]))
                values[i] = value;
        }
        else
            ok = [self readType:@encode(CGFloat) data:&values[i]];
    }

    if(!ok)
        [NSException raise:NSInvalidArgumentException format:@"NSUnarchiver: cannot decode geometry of type '%s', expected '%s' or '%s'", str ? str : "", type, legacyType];
}

- (CGPoint)decodePoint
{
    CGFloat v[2];
    [self _decodeGeometry:v count:2 type:@encode(CGPoint) legacyType:"ff"];
    return CGPointMake(v[0], v[1]);
}

- (CGSize)decodeSize
{
    CGFloat v[2];
    [self _decodeGeometry:v count:2 type:@encode(CGSize) legacyType:"ff"];
    return CGSizeMake(v[0], v[1]);
}

- (CGRect)decodeRect
{
    CGFloat v[4];
    [self _decodeGeometry:v count:4 type:@encode(CGRect) legacyType:"ffff"];
    return CGRectMake(v[0], v[1], v[2], v[3]);
}

- (void*)decodeBytesWithReturnedLength:(NSUInteger*)outLength
{
    NSParameterAssert(outLength);
    
    *outLength = 0;
    NSString* string;
    if(![self decodeSharedString:&string])
        return NULL;
    if(![string isEqualToString:@"+"])
        return NULL;
    
    int length;
    if(![self decodeInt:&length] || length < 0)
        return NULL;
    
    NSData* data;
    if(![self readData:&data length:(NSUInteger)length])
        return NULL;
    
    *outLength = (NSUInteger)length;
    return (void*)data.bytes;
}

- (id)decodeObject
{
    id obj;
    if (![self readObject:&obj])
    {
      NSUDEBUG(@"NSUnarchive readObject failed\n");
      return nil;
    }
    return obj;
}

- (NSInteger)versionForClassName:(NSString *)className
{
    NSParameterAssert(className);
    return ((NSNumber*)_versionByClassName[className]).integerValue;
}

-(void)decodeClassName:(NSString *)archiveName asClassName:(NSString *)runtimeName {
	if (_classNameMap == nil)
		_classNameMap = [[NSMutableDictionary alloc] init];
	_classNameMap[archiveName] = runtimeName;
}

-(NSString *)classNameDecodedForArchiveClassName:(NSString *)className {
	if (_classNameMap == nil)
		return className;
	NSString* mapped = _classNameMap[className];
	if (mapped != nil)
		return mapped;
	return className;
}

+(void)decodeClassName:(NSString *)archiveName asClassName:(NSString *)runtimeName {
	globalClassNameMap[archiveName] = runtimeName;
}

+(NSString *)classNameDecodedForArchiveClassName:(NSString *)className {
	NSString* mapped = globalClassNameMap[className];
	if (mapped != nil)
		return mapped;
	return className;
}

// Private API apps send before decoding. NSUnarchiver doesn't restrict the classes it decodes, so the
// set is accepted and ignored.
-(void)_setAllowedClasses:(NSSet *)classes {
}

-(void)replaceObject:original withObject:replacement {
   if (original == replacement || !original || !replacement)
      return;
   for (id key in [_sharedObjects allKeys]) {
      if (_sharedObjects[key] == original) {
         _sharedObjects[key] = replacement;
      }
   }
}

- (BOOL)allowsKeyedCoding
{
    return NO;
}

- (BOOL)containsValueForKey:(NSString *)key
{
    return NO;
}

- (id)decodeObjectForKey:(NSString *)key
{
    return nil;
}

- (BOOL)decodeBoolForKey:(NSString *)key
{
    return NO;
}

- (int)decodeIntForKey:(NSString *)key
{
    return 0;
}

- (int32_t)decodeInt32ForKey:(NSString *)key
{
    return 0;
}

- (int64_t)decodeInt64ForKey:(NSString *)key
{
    return 0;
}

- (float)decodeFloatForKey:(NSString *)key
{
    return 0.0f;
}

- (double)decodeDoubleForKey:(NSString *)key
{
    return 0.0;
}

- (NSInteger)decodeIntegerForKey:(NSString *)key
{
    return 0;
}

- (const uint8_t *)decodeBytesForKey:(NSString *)key returnedLength:(NSUInteger *)len
{
    if (len) *len = 0;
    return NULL;
}

@end

static Boolean stringsEqual(const void* s1, const void* s2)
{
   return strcmp((const char*) s1, (const char*) s2) == 0;
}

static CFHashCode stringHash(const void* s)
{
   const char* str = (const char*) s;
   CFHashCode hash = 5381;
   int c;

   while ((c = *str++))
      hash = ((hash << 5) + hash) + c;

   return hash;
}

static const void* stringRetain(CFAllocatorRef allocator, const void* s)
{
   return strdup((char*) s);
}

// Returns a permanently allocated string (atom).
// Atoms can be compared with ==.
static const char* uniqueString(const char* str)
{
   static CFMutableSetRef atoms;
   static dispatch_once_t once;

   dispatch_once(&once, ^{
      CFSetCallBacks cb = {
         .equal = stringsEqual,
         .hash = stringHash,
         .retain = stringRetain,
      };
      atoms = CFSetCreateMutable(NULL, 0, &cb);
   });

   if (!CFSetContainsValue(atoms, str))
      CFSetAddValue(atoms, str);

   return (const char*) CFSetGetValue(atoms, str);
}
