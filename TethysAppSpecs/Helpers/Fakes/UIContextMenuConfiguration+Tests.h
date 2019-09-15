#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIContextMenuConfiguration (Tests)

@property (nonatomic, readonly, nullable) UIContextMenuContentPreviewProvider previewProvider;
@property (nonatomic, readonly, nullable) UIContextMenuActionProvider actionProvider;

@end

NS_ASSUME_NONNULL_END
