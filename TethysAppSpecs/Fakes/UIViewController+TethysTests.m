#import "UIViewController+TethysTests.h"
#import "PCKMethodRedirector.h"
#import <objc/runtime.h>

static char * kShowMainKey;
static char * kShowDetailKey;

@interface UIViewController (TethysTestsPrivate)

- (void)original_showViewController:(UIViewController *)vc sender:(id)sender;
- (void)original_showDetailViewController:(UIViewController *)vc sender:(id)sender;

@end

@implementation UIViewController (TethysTests)

+ (void)load {
    [PCKMethodRedirector redirectSelector:@selector(showViewController:sender:)
                                 forClass:self
                                       to:@selector(_showViewController:sender:)
                            andRenameItTo:@selector(original_showViewController:sender:)];

    [PCKMethodRedirector redirectSelector:@selector(showDetailViewController:sender:)
                                 forClass:self
                                       to:@selector(_showDetailViewController:sender:)
                            andRenameItTo:@selector(original_showDetailViewController:sender:)];
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
