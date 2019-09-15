#import "UIContextMenuConfiguration+Tests.h"
#import "PCKMethodRedirector.h"
#import <objc/runtime.h>

//@property (nonatomic, readonly, nullable) UIContextMenuContentPreviewProvider previewProvider;
//@property (nonatomic, readonly, nullable) UIContextMenuActionProvider actionProvider;

static char *kPreviewKey = "kPreviewKey";
static char *kActionKey = "kActionKey";

@interface UIContextMenuConfiguration (TestsPrivate)
+ (instancetype)configurationWithOriginalIdentifier:(id<NSCopying>)identifier
                                    previewProvider:(UIContextMenuContentPreviewProvider)previewProvider
                                     actionProvider:(UIContextMenuActionProvider)actionProvider;
@end

@implementation UIContextMenuConfiguration (Tests)

+ (void)load {
    [PCKMethodRedirector redirectSelector:@selector(configurationWithIdentifier:previewProvider:actionProvider:)
         forClass:self
               to:@selector(configurationWithFakeIdentifier:previewProvider:actionProvider:)
    andRenameItTo:@selector(configurationWithOriginalIdentifier:previewProvider:actionProvider:)];
}

+ (instancetype)configurationWithFakeIdentifier:(id<NSCopying>)identifier
                                previewProvider:(UIContextMenuContentPreviewProvider)previewProvider
                                 actionProvider:(UIContextMenuActionProvider)actionProvider {
    id instance = [self configurationWithOriginalIdentifier:identifier previewProvider:previewProvider actionProvider:actionProvider];
    objc_setAssociatedObject(instance, kPreviewKey, previewProvider, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(instance, kActionKey, actionProvider, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return instance;
}

- (UIContextMenuContentPreviewProvider)previewProvider {
    return objc_getAssociatedObject(self, kPreviewKey);
}

- (UIContextMenuActionProvider)actionProvider {
    return objc_getAssociatedObject(self, kActionKey);
}

@end
