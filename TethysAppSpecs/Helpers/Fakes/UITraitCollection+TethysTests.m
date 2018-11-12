#import "UITraitCollection+TethysTests.h"
#import "PCKMethodRedirector.h"
#import <objc/runtime.h>

static char * kForceTouchKey;

@interface UITraitCollection (TethysTestsPrivate)
- (UIForceTouchCapability)original_forceTouchCapability;
@end

@implementation UITraitCollection (TethysTests)

+ (void)load {
    [PCKMethodRedirector redirectSelector:@selector(forceTouchCapability)
                                 forClass:[self class]
                                       to:@selector(_forceTouchCapability)
                            andRenameItTo:@selector(original_forceTouchCapability)];
}

- (UIForceTouchCapability)_forceTouchCapability {
    NSNumber *val = objc_getAssociatedObject(self, kForceTouchKey);
    if (val == nil) {
        return [self original_forceTouchCapability];
    }
    return (UIForceTouchCapability)val.integerValue;
}

- (void)setForceTouchCapability:(UIForceTouchCapability)forceTouchCapability {
    objc_setAssociatedObject(self, kForceTouchKey, @(forceTouchCapability), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
