#import <UIKit/UIKit.h>

typedef void (^PCKTableViewRowActionHandler)(UITableViewRowAction *action, NSIndexPath *indexPath);

@interface UITableViewRowAction (TethysSpec)

- (PCKTableViewRowActionHandler)handler;

@end
