#include "native-support.h"
#include "native-production.inc"

static unsigned failures;
#define CHECK(c,label) do { if (!(c)) { ++failures; printf("FAIL %s\n",label); } } while (0)
@interface NativeIvars : NSObject { @public id _isToken, token, isToken, _URL; signed char _signedValue; unsigned char _guard; int _integerValue; _Bool _truth; Pair _pair; Tiny _tiny; unsigned nilCalls; }
@end
@implementation NativeIvars
- (void)setNilValueForKey:(id)key { ++nilCalls; }
@end
@interface NativeUnder : NSObject @end
@implementation NativeUnder
- (id)_getToken { return (id)11; }
- (id)_token { return (id)22; }
@end
@interface NativePrimitive : NSObject @end
@implementation NativePrimitive
- (id)getPrimitiveToken { return (id)11; }
- (void)setPrimitiveToken:(id)v {}
@end
@interface NativeGet : NativeUnder @end
@implementation NativeGet
- (id)getToken { return (id)33; }
- (id)token { return (id)44; }
- (id)isToken { return (id)55; }
@end
@interface NativeNoDirect : NativeIvars @end
@implementation NativeNoDirect
+ (BOOL)accessInstanceVariablesDirectly { return NO; }
@end
@interface NativePrivateSet : NativeIvars @end
@implementation NativePrivateSet
- (void)_setToken:(id)v { token = v; }
@end
@interface NativePublicSet : NativePrivateSet @end
@implementation NativePublicSet
- (void)setToken:(id)v { token = (id)((uintptr_t)v + 1); }
@end
static NSKeyValueAccessor *getter(Class c, const char *key) { return [NSObject _createValueGetterWithContainerClassID:c key:[NSString from:key]]; }
static NSKeyValueAccessor *setter(Class c, const char *key) { return [NSObject _createValueSetterWithContainerClassID:c key:[NSString from:key]]; }
static BOOL methodIs(NSKeyValueAccessor *a, const char *s) { return a->selectedMethod && !strcmp(sel_getName(method_getName(a->selectedMethod)), s); }
static BOOL ivarIs(NSKeyValueAccessor *a, const char *s) { return a->selectedIvar && !strcmp(ivar_getName(a->selectedIvar), s); }
static void search(void) {
    NSKeyValueAccessor *a = getter([NativeUnder class], "token");
    CHECK(methodIs(a,"_token"), "_token beats excluded _getToken");
    if (a->selectedMethod) CHECK(((id(*)(id,SEL))method_getImplementation(a->selectedMethod))([NativeUnder alloc], method_getName(a->selectedMethod)) == (id)22, "selected getter returns expected value");
    CHECK(methodIs(getter([NativeGet class], "token"),"getToken"), "getToken precedence");
    CHECK(object_getClass(getter([NativePrimitive class], "token")) == [NSKeyValueUndefinedGetter class], "primitive getter excluded");
    CHECK(object_getClass(setter([NativePrimitive class], "token")) == [NSKeyValueUndefinedSetter class], "primitive setter excluded");
    CHECK(ivarIs(getter([NativeIvars class], "token"),"_isToken"), "getter ivar precedence");
    CHECK(ivarIs(setter([NativeIvars class], "token"),"_isToken"), "setter ivar precedence");
    CHECK(ivarIs(getter([NativeIvars class], "URL"),"_URL"), "uppercase getter ivar");
    CHECK(ivarIs(setter([NativeIvars class], "URL"),"_URL"), "uppercase setter ivar");
    CHECK(object_getClass(getter([NativeNoDirect class], "token")) == [NSKeyValueUndefinedGetter class], "getter direct access disabled");
    CHECK(object_getClass(setter([NativeNoDirect class], "token")) == [NSKeyValueUndefinedSetter class], "setter direct access disabled");
    CHECK(methodIs(setter([NativePrivateSet class], "token"),"_setToken:"), "private setter beats ivar");
    a = setter([NativePublicSet class], "token");
    CHECK(methodIs(a,"setToken:"), "public setter beats private");
    NativePublicSet *o = [NativePublicSet alloc];
    ((void(*)(id,SEL,id))method_getImplementation(a->selectedMethod))(o,method_getName(a->selectedMethod),(id)100);
    CHECK(o->token == (id)101, "selected setter changes state");
}
static void boxing(void) {
    NativeIvars *o = [NativeIvars alloc]; Class c = [NativeIvars class];
    o->_signedValue = -7; o->_guard = 0xa5; o->_integerValue = -345; o->_truth = 1;
    o->_pair = (Pair){2,4,8}; o->_tiny = (Tiny){17,29};
    Ivar ch = class_getInstanceVariable(c,"_signedValue"), truth = class_getInstanceVariable(c,"_truth"), pair = class_getInstanceVariable(c,"_pair");
    const char *type = @encode(signed char); IMP imp = NULL;
    TYPE_TO_IMP(_NSGet, ValueInIvar);
    CHECK(((NSNumber *)((id(*)(id,SEL,Ivar))imp)(o,0,ch))->number == -7, "signed char dispatch preserves sign");
    CHECK(((NSNumber *)_NSGetCharValueInIvar(o,0,ch))->number == -7, "signed char read");
    CHECK(((NSNumber *)_NSGetIntValueInIvar(o,0,class_getInstanceVariable(c,"_integerValue")))->number == -345, "int read");
    CHECK(_NSGetBoolValueInIvar(o,0,truth) == kCFBooleanTrue, "B true singleton");
    o->_truth = 0; CHECK(_NSGetBoolValueInIvar(o,0,truth) == kCFBooleanFalse, "B false singleton");
    for (int i = 0; i < 2; ++i) { o->_signedValue = i; CHECK(_NSGetCharValueInIvar(o,0,ch) == (i ? kCFBooleanTrue : kCFBooleanFalse), "c boolean singleton"); }
    Pair p = {0}; [_NSGetStructValueInIvar(o,0,pair) getValue:&p];
    CHECK(p.first == 2 && p.second == 4 && p.third == 8, "whole struct ivar boxing");
    Tiny t = {0}; [_NSGetStructValueInIvar(o,0,class_getInstanceVariable(c,"_tiny")) getValue:&t];
    CHECK(t.first == 17 && t.second == 29, "tiny struct ivar boxing");
    _NSSetStructValueForKeyInIvar(o,0,nil,nil,pair);
    CHECK(o->nilCalls == 1, "nil struct dispatch");
    p = (Pair){32,64,128}; _NSSetStructValueForKeyInIvar(o,0,[NSValue value:&p withObjCType:@encode(Pair)],nil,pair);
    CHECK(o->_pair.third == 128, "whole struct ivar assignment");
    BOOL raised = NO;
    @try { _NSSetStructValueForKeyInIvar(o,0,[NSValue value:&t withObjCType:@encode(Tiny)],nil,pair); }
    @catch(id exception) { raised = YES; }
    CHECK(raised && o->_pair.third == 128, "mismatch rejected before mutation");
    CHECK(o->_guard == 0xa5, "neighbor scalar unchanged");
}
static void retarget(void) {
    Method old = class_getInstanceMethod([NativePrivateSet class],@selector(_setToken:));
    Method new = class_getInstanceMethod([NativePublicSet class],@selector(setToken:));
    NativeCachedSetter *cached = [NativeCachedSetter alloc];
    cached->_implementation = method_getImplementation(old);
    [cached setMethod:new];
    NativePublicSet *o = [NativePublicSet alloc];
    ((void(*)(id,SEL,id))cached->_implementation)(o,method_getName(new),(id)100);
    CHECK(o->token == (id)101, "retarget cached direct object IMP");
    cached->_extraArgument2 = old; cached->_implementation = method_getImplementation(old);
    [cached setMethod:new];
    CHECK(cached->_extraArgument2 == new && cached->_implementation == method_getImplementation(old), "retarget Method extra preserves wrapper IMP");
}
int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    kCFBooleanTrue = [NSNumber numberWithInt:1]; kCFBooleanFalse = [NSNumber numberWithInt:0];
    if (argc == 1 || !strcmp(argv[1],"search")) search();
    if (argc == 1 || !strcmp(argv[1],"boxing")) boxing();
    if (argc == 1 || !strcmp(argv[1],"retarget")) retarget();
    printf("native-kvc: %u failures\n",failures); return failures ? 1 : 0;
}
