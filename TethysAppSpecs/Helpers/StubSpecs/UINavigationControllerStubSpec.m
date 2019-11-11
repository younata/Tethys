@import Quick;
@import Nimble;
@import UIKit;

QuickSpecBegin(UINavigationControllerStubSpec)

__block UINavigationController *subject;
__block UIViewController *rootController;

beforeEach(^{
    rootController = [[UIViewController alloc] init];
    subject = [[UINavigationController alloc] initWithRootViewController:rootController];
});

describe(@"pushing a view controller", ^{
    __block UIViewController *pushedViewController;

    beforeEach(^{
        pushedViewController = [[UIViewController alloc] init];
        [subject pushViewController:pushedViewController animated:YES];
    });

    it(@"updates the view controller stack", ^{
        expect(subject.viewControllers).to(equal(@[rootController, pushedViewController]));
    });

    it(@"marks the pushed view controller as top and visible", ^{
        expect(subject.topViewController).to(be(pushedViewController));
        expect(subject.visibleViewController).to(be(pushedViewController));
    });

    describe(@"pushing another view controller", ^{
        __block UIViewController *secondPushedVC;

        beforeEach(^{
            secondPushedVC = [[UIViewController alloc] init];
            [subject pushViewController:secondPushedVC animated:YES];
        });

        it(@"updates the view controller stack", ^{
            expect(subject.viewControllers).to(equal(@[rootController, pushedViewController, secondPushedVC]));
        });

        it(@"marks the pushed view controller as top and visible", ^{
            expect(subject.topViewController).to(be(secondPushedVC));
            expect(subject.visibleViewController).to(be(secondPushedVC));
        });

        describe(@"popping to the root view controller", ^{
            beforeEach(^{
                [subject popToRootViewControllerAnimated:YES];
            });

            it(@"updates the view controller stack", ^{
                expect(subject.viewControllers).to(equal(@[rootController]));
            });

            it(@"marks the root view controller as the top view controller", ^{
                expect(subject.topViewController).to(be(rootController));
            });

            it(@"marks the root view controller as the visible view controller", ^{
                expect(subject.visibleViewController).to(be(rootController));
            });
        });
    });

    describe(@"presenting from that view controller", ^{
        __block UIViewController *presentedVC;

        beforeEach(^{
            presentedVC = [[UIViewController alloc] init];
            [pushedViewController presentViewController:presentedVC animated:YES completion:nil];
        });

        it(@"does not change the view controller stack", ^{
            expect(subject.viewControllers).to(equal(@[rootController, pushedViewController]));
        });

        it(@"does not change what the top view controller shows", ^{
            expect(subject.topViewController).to(be(pushedViewController));
        });

        it(@"marks the presented view controller as visible", ^{
            expect(subject.visibleViewController).to(be(presentedVC));
        });
    });

    describe(@"popping the view controller", ^{
        beforeEach(^{
            [subject popViewControllerAnimated:YES];
        });

        it(@"updates the view controller stack", ^{
            expect(subject.viewControllers).to(equal(@[rootController]));
        });

        it(@"marks the previous view controller as the top view controller", ^{
            expect(subject.topViewController).to(be(rootController));
        });

        it(@"marks the previous view controller as the visible view controller", ^{
            expect(subject.visibleViewController).to(be(rootController));
        });
    });
});

describe(@"presenting a view controller", ^{
    __block UIViewController *presentedVC;

    beforeEach(^{
        presentedVC = [[UIViewController alloc] init];
        [subject presentViewController:presentedVC animated:YES completion:nil];
    });

    it(@"does not change the view controller stack", ^{
        expect(subject.viewControllers).to(equal(@[rootController]));
    });

    it(@"does not change what the top view controller shows", ^{
        expect(subject.topViewController).to(be(rootController));
    });

    it(@"marks the presented view controller as visible", ^{
        expect(subject.visibleViewController).to(be(presentedVC));
    });
});

describe(@"setting the view controller stack", ^{
    __block UIViewController *firstVC;
    __block UIViewController *secondVC;

    beforeEach(^{
        firstVC = [[UIViewController alloc] init];
        secondVC = [[UIViewController alloc] init];

        [subject setViewControllers:@[firstVC, secondVC] animated:YES];
    });

    it(@"sets the view controller stack", ^{
        expect(subject.viewControllers).to(equal(@[firstVC, secondVC]));
    });

    it(@"reports the second VC as the top view controller", ^{
        expect(subject.topViewController).to(be(secondVC));
    });

    it(@"reports the second VC as the visible view controller", ^{
        expect(subject.visibleViewController).to(be(secondVC));
    });
});

QuickSpecEnd

