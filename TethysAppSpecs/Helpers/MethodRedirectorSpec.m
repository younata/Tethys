@import Quick;
@import Nimble;

#import "MethodRedirector.h"

@interface TestObject: NSObject

- (NSString *)a;
- (NSString *)b;
- (NSString *)_original_a;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation TestObject

- (NSString *)a { return @"a"; }
- (NSString *)b { return @"b"; }


@end
#pragma clang diagnostic pop

QuickSpecBegin(MethodRedirectorSpec)
it(@"redirects selectors on instance methods", ^{
    TestObject *object = [[TestObject alloc] init];
    expect([object a]).to(equal(@"a"));
    expect([object b]).to(equal(@"b"));

    [TestObject redirectSelector:@selector(a) to:@selector(b) andRenameItTo:@selector(_original_a)];

    expect([object a]).to(equal(@"b"));
    expect([object b]).to(equal(@"b"));
    expect([object _original_a]).to(equal(@"a"));
});

QuickSpecEnd
