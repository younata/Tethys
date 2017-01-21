#import "NSUserActivity+TethysTests.h"
#import "PCKMethodRedirector.h"
#import <objc/runtime.h>

static char * kCurrentKey;
static char * kValidKey;

@interface NSUserActivity (TethysTestsPrivate)
- (void)original_becomeCurrent;
- (void)original_resignCurrent;
- (void)original_invalidate;
@end

@implementation NSUserActivity (TethysTests)

+ (void)load {
    [PCKMethodRedirector redirectSelector:@selector(becomeCurrent)
                                 forClass:[self class]
                                       to:@selector(_becomeCurrent)
                            andRenameItTo:@selector(original_becomeCurrent)];

    [PCKMethodRedirector redirectSelector:@selector(resignCurrent)
                                 forClass:[self class]
                                       to:@selector(_resignCurrent)
                            andRenameItTo:@selector(original_resignCurrent)];

    [PCKMethodRedirector redirectSelector:@selector(invalidate)
                                 forClass:[self class]
                                       to:@selector(_invalidate)
                            andRenameItTo:@selector(original_invalidate)];
}

- (BOOL)active {
    return [objc_getAssociatedObject(self, &kCurrentKey) boolValue];
}

- (void)_becomeCurrent {
    objc_setAssociatedObject(self, &kCurrentKey, @YES, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)_resignCurrent {
    objc_setAssociatedObject(self, &kCurrentKey, @NO, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)valid {
    return objc_getAssociatedObject(self, &kValidKey) != nil;
}

- (void)_invalidate {
    objc_setAssociatedObject(self, &kCurrentKey, @NO, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &kValidKey, @NO, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
