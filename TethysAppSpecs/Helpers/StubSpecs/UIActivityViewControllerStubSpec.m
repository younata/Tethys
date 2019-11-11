@import Quick;
@import Nimble;
@import UIKit;

#import "UIActivityViewControllerStub.h"

@interface TestActivity : UIActivity
@end

@implementation TestActivity

- (NSString *)activityTitle {
    return @"Test Activity";
}
@end

QuickSpecBegin(UIActivityViewControllerStubSpec)

__block UIActivityViewController *subject;

beforeEach(^{
    TestActivity *activity = [[TestActivity alloc] init];
    subject = [[UIActivityViewController alloc] initWithActivityItems:@[@"hello"]
                                                applicationActivities:@[activity]];
});

it(@"records the activity items", ^{
   expect(subject.activityItems).to(equal(@[@"hello"]));
});

it(@"records the application activities", ^{
   expect(subject.applicationActivities).to(haveCount(1));
   expect(subject.applicationActivities.lastObject.activityTitle).to(equal(@"Test Activity"));
});

QuickSpecEnd

