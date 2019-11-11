@import Quick;
@import Nimble;
@import UIKit;

QuickSpecBegin(UIViewControllerStubSpec)

__block UIViewController *subject;

beforeEach(^{
    subject = [[UIViewController alloc] init];
});

describe(@"presenting a view controller", ^{
    __block UIViewController *presentedVC;

    beforeEach(^{
        presentedVC = [[UIViewController alloc] init];

        [subject presentViewController:presentedVC animated:YES completion:nil];
    });

    it(@"reports that VC as the presented view controller", ^{
        expect(subject.presentedViewController).to(be(presentedVC));
    });

    it(@"marks the presented VC's presentingViewController as the receiver", ^{
        expect(presentedVC.presentingViewController).to(be(subject));
    });

    describe(@"dismissing the view controller", ^{
        beforeEach(^{
            [subject dismissViewControllerAnimated:YES completion:nil];
        });

        it(@"sets the presented view controller as nil", ^{
            expect(subject.presentedViewController).to(beNil());
        });

        it(@"sets the presented VC's presentingViewController to nil", ^{
            expect(presentedVC.presentingViewController).to(beNil());
        });
    });
});

QuickSpecEnd
