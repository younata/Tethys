#import "UITraitCollection+TethysTests.h"
#import "MethodRedirector.h"
#import <objc/runtime.h>

static char * kForceTouchKey;

@interface UITraitCollection (TethysTestsPrivate)
- (UIForceTouchCapability)_original_forceTouchCapability;
@end

@implementation UITraitCollection (TethysTests)

+ (void)load {
    [self redirectSelector:@selector(forceTouchCapability)
                        to:@selector(_forceTouchCapability)
     andRenameItTo:@selector(_original_forceTouchCapability)];
}

- (UIForceTouchCapability)_forceTouchCapability {
    NSNumber *val = objc_getAssociatedObject(self, kForceTouchKey);
    if (val == nil) {
        return [self _original_forceTouchCapability];
    }
    return (UIForceTouchCapability)val.integerValue;
}

- (void)setForceTouchCapability:(UIForceTouchCapability)forceTouchCapability {
    objc_setAssociatedObject(self, kForceTouchKey, @(forceTouchCapability), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
