#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FakeWKContentMenuElementInfo : WKContextMenuElementInfo

@property (nonatomic, copy, nullable) NSURL *link;

+ (instancetype)newWithLinkURL:(NSURL *)linkURL NS_SWIFT_NAME(new(linkURL:));

@end

NS_ASSUME_NONNULL_END
