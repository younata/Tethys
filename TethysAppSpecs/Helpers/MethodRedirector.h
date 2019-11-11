#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (MethodRedirection)

+ (void)redirectSelector:(SEL)originalSelector to:(SEL)newSelector andRenameItTo:(SEL)renamedSelector;

@end

NS_ASSUME_NONNULL_END
