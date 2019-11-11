@import Quick;
@import Nimble;

#import "MethodRedirector.h"

@interface TestObject: NSObject

- (NSString *)a;
- (NSString *)b;

@end

@implementation TestObject

- (NSString *)a { return @"a"; }
- (NSString *)b { return @"b"; }

@end

QuickSpecBegin(MethodRedirectorSpec)
it(@"redirects selectors on instance methods", ^{
   TestObject *object = [[TestObject alloc] init];
   expect([object a]).to(equal(@"a"));
   expect([object b]).to(equal(@"b"));

   [TestObject redirectSelector:@selector(a) to:@selector(b)];

   expect([object a]).to(equal(@"b"));
   expect([object b]).to(equal(@"b"));
   expect([object respondsToSelector:NSSelectorFromString(@"_original_a")]).to(beTrue());
});
QuickSpecEnd
