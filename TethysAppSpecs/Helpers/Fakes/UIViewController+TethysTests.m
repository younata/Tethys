#import "UIViewController+TethysTests.h"
#import "MethodRedirector.h"
#import <objc/runtime.h>

static char * kShowMainKey;
static char * kShowDetailKey;

@implementation UIViewController (TethysTests)

+ (void)load {
    [self redirectSelector:@selector(showViewController:sender:)
                        to:@selector(_showViewController:sender:)];

    [self redirectSelector:@selector(showDetailViewController:sender:)
                        to:@selector(_showDetailViewController:sender:)];
}

- (void)_showViewController:(UIViewController *)vc sender:(id)sender {
    objc_setAssociatedObject(self, kShowMainKey, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)_showDetailViewController:(UIViewController *)vc sender:(id)sender {
    objc_setAssociatedObject(self, kShowDetailKey, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (nullable UIViewController *)shownViewController {
    return objc_getAssociatedObject(self, kShowMainKey);
}

- (nullable UIViewController *)shownDetailViewController {
    return objc_getAssociatedObject(self, kShowDetailKey);
}

@end
