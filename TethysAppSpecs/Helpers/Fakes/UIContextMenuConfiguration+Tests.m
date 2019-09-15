#import "UIContextMenuConfiguration+Tests.h"

@implementation UIContextMenuConfiguration (Tests)

- (UIContextMenuContentPreviewProvider)previewProvider {
    return [self valueForKey:@"_previewProvider"];
}

- (UIContextMenuActionProvider)actionProvider {
    return [self valueForKey:@"_actionProvider"];
}

@end

@implementation UIAction (Tests)

- (UIActionHandler)handler {
    return [self valueForKey:@"_handler"];
}

@end
