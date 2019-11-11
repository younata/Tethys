#import "UIViewControllerStub.h"
#import "MethodRedirector.h"
#import <objc/runtime.h>

static char * kShowMainKey = "kShowMainKey";
static char * kShowDetailKey = "kShowDetailKey";
static char * kPresentedKey = "kPresentedKey";
static char * kPresentingKey = "kPresentingKey";

@implementation UIViewController (TethysTests)

+ (void)load {
    [self redirectSelector:@selector(showViewController:sender:)
                        to:@selector(_showViewController:sender:)
             andRenameItTo:NSSelectorFromString(@"_original_showViewController:sender:")];

    [self redirectSelector:@selector(showDetailViewController:sender:)
                        to:@selector(_showDetailViewController:sender:)
             andRenameItTo:NSSelectorFromString(@"_original_showDetailViewController:sender:")];

    [self redirectSelector:@selector(presentViewController:animated:completion:)
                        to:@selector(_presentViewController:animated:completion:)
             andRenameItTo:NSSelectorFromString(@"_original_presentViewController:animated:completion:")];

    [self redirectSelector:@selector(presentedViewController)
                        to:@selector(_presentedViewController)
             andRenameItTo:NSSelectorFromString(@"_original_presentedViewController")];

    [self redirectSelector:@selector(dismissViewControllerAnimated:completion:)
                        to:@selector(_dismissViewControllerAnimated:completion:)
             andRenameItTo:NSSelectorFromString(@"_original_dismissViewControllerAnimated:completion:")];

    [self redirectSelector:@selector(presentingViewController)
                        to:@selector(_presentingViewController)
             andRenameItTo:NSSelectorFromString(@"_original_presentingViewController")];
}

// MARK: -showViewController

- (void)_showViewController:(UIViewController *)vc sender:(id)sender {
    objc_setAssociatedObject(self, kShowMainKey, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (nullable UIViewController *)shownViewController {
    return objc_getAssociatedObject(self, kShowMainKey);
}

// MARK: -showDetailViewController

- (void)_showDetailViewController:(UIViewController *)vc sender:(id)sender {
    objc_setAssociatedObject(self, kShowDetailKey, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (nullable UIViewController *)shownDetailViewController {
    return objc_getAssociatedObject(self, kShowDetailKey);
}

// MARK: -presentViewController

- (void)_presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^ __nullable)(void))completion {
    [vc _setPresentingViewController:self];
    [self _changePresentedVC:vc completion:completion];
}

- (nullable UIViewController *)_presentedViewController {
    return objc_getAssociatedObject(self, kPresentedKey);
}

- (nullable UIViewController *)_presentingViewController {
    return objc_getAssociatedObject(self, kPresentingKey);
}

- (void)_setPresentingViewController:(nullable UIViewController *)viewController {
    objc_setAssociatedObject(self, kPresentingKey, viewController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)_dismissViewControllerAnimated:(BOOL)flag completion:(void (^ __nullable)(void))completion {
    [[self presentedViewController] _setPresentingViewController:nil];
    [self _changePresentedVC:nil completion:completion];
}

- (void)_changePresentedVC:(nullable UIViewController *)vc completion:(void (^ __nullable)(void))completion {
    objc_setAssociatedObject(self, kPresentedKey, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (completion) {
        completion();
    }
}

@end
