@import UIKit;
#import "MethodRedirector.h"

@interface UINavigationController (SpecPrivate)

- (void)_original_pushViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)pushViewController:(UIViewController *)viewController ignoringAnimated:(BOOL)animated;

- (UIViewController *)_original_popViewControllerAnimated:(BOOL)animated;
- (UIViewController *)popViewControllerIgnoringAnimated:(BOOL)animated;

- (NSArray *)_original_popToRootViewControllerAnimated:(BOOL)animated;
- (NSArray *)popToRootViewControllerIgnoringAnimated:(BOOL)animated;

- (void)setViewControllers:(NSArray *)viewControllers ignoringAnimated:(BOOL)animated;
- (void)_original_setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation UINavigationController (SpecPrivate)

+ (void)load {
    [self redirectSelector:@selector(pushViewController:animated:)
                        to:@selector(pushViewController:ignoringAnimated:)
             andRenameItTo:@selector(_original_pushViewController:animated:)];

    [self redirectSelector:@selector(popViewControllerAnimated:)
                        to:@selector(popViewControllerIgnoringAnimated:)
             andRenameItTo:@selector(_original_popViewControllerAnimated:)];

    [self redirectSelector:@selector(popToRootViewControllerAnimated:)
                        to:@selector(popToRootViewControllerIgnoringAnimated:)
             andRenameItTo:@selector(_original_popToRootViewControllerAnimated:)];

    [self redirectSelector:@selector(setViewControllers:animated:)
                        to:@selector(setViewControllers:ignoringAnimated:)
             andRenameItTo:@selector(_original_setViewControllers:animated:)];
}

- (void)pushViewController:(UIViewController *)viewController ignoringAnimated:(BOOL)animated {
    [self _original_pushViewController:viewController animated:NO];
}

- (UIViewController *)popViewControllerIgnoringAnimated:(BOOL)animated {
    return [self _original_popViewControllerAnimated:NO];
}

- (NSArray *)popToRootViewControllerIgnoringAnimated:(BOOL)animated {
    return [self _original_popToRootViewControllerAnimated:NO];
}

- (void)setViewControllers:(NSArray *)viewControllers ignoringAnimated:(BOOL)animated {
    [self _original_setViewControllers:viewControllers animated:NO];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

- (UIViewController *)visibleViewController {
    if (self.presentedViewController) {
        return self.presentedViewController;
    } else {
        for (UIViewController *viewController in self.viewControllers) {
            if (viewController.presentedViewController) {
                return viewController.presentedViewController;
            }
        }
    }
    return self.topViewController;
}

#pragma clang diagnostic pop

@end
#pragma clang diagnostic pop
