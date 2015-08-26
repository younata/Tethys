#import <UIKit/UIKit.h>

typedef void (^PCKTableViewRowActionHandler)(UITableViewRowAction *action, NSIndexPath *indexPath);

@interface UITableViewRowAction (rNewsSpec)

- (PCKTableViewRowActionHandler)handler;

@end
