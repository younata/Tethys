#import "MethodRedirector.h"
#import <objc/runtime.h>

@implementation NSObject (MethodRedirection)

+ (void)redirectSelector:(SEL)originalSelector to:(SEL)newSelector {
    SEL renamedSelector = NSSelectorFromString([@"_original_" stringByAppendingString:NSStringFromSelector(originalSelector)]);
    if ([self instancesRespondToSelector:renamedSelector]) {
        return;
    }

    Method originalMethod = class_getInstanceMethod(self, originalSelector);
    class_addMethod(self, renamedSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));

    Method newMethod = class_getInstanceMethod(self, newSelector);
    class_replaceMethod(self, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
}

@end
