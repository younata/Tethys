#import "UIAlertActionStub.h"
#import <objc/runtime.h>

static char *kHandlerKey;

@interface UIAlertAction (StubPrivate)

+ (instancetype)_original_actionWithTitle:(nullable NSString *)title
                                    style:(UIAlertActionStyle)style
                                  handler:(void (^ __nullable)(UIAlertAction *action))handler;

@end

@implementation UIAlertAction (Stub)

+ (void)load {
    Class cls = objc_getMetaClass(class_getName([self class]));
    SEL originalSelector = @selector(actionWithTitle:style:handler:);
    SEL newSelector = @selector(_actionWithTitle:style:handler:);
    SEL renamedSelector = @selector(_original_actionWithTitle:style:handler:);

    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    class_addMethod(cls, renamedSelector, method_getImplementation(originalMethod),
                    method_getTypeEncoding(originalMethod));

    Method newMethod = class_getInstanceMethod(cls, newSelector);
    class_replaceMethod(cls, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
}

+ (instancetype)_actionWithTitle:(nullable NSString *)title
                           style:(UIAlertActionStyle)style
                         handler:(void (^ __nullable)(UIAlertAction *action))handler {
    UIAlertAction *result = [self _original_actionWithTitle:title style:style handler:handler];
    objc_setAssociatedObject(result, kHandlerKey, handler, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return result;
}

- (void (^)(UIAlertAction * _Nonnull))handler {
    return objc_getAssociatedObject(self, kHandlerKey);
}

@end
