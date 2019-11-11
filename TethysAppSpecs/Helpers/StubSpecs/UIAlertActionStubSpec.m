@import Quick;
@import Nimble;
@import UIKit;

#import "UIAlertActionStub.h"

QuickSpecBegin(UIAlertActionStub)

it(@"stores the handler method", ^{
    __block int handlerCallCount = 0;
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        handlerCallCount += 1;
    }];
    expect(handlerCallCount).to(equal(0));
    action.handler(action);
    expect(handlerCallCount).to(equal(1));
});

QuickSpecEnd
