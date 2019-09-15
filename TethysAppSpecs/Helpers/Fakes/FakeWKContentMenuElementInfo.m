#import "FakeWKContentMenuElementInfo.h"

@implementation FakeWKContentMenuElementInfo

+ (instancetype)newWithLinkURL:(NSURL *)linkURL {
    FakeWKContentMenuElementInfo *theSelf = [self new];
    if (theSelf != nil && [theSelf isKindOfClass:[FakeWKContentMenuElementInfo class]]) {
        theSelf.link = linkURL;
    }
    return theSelf;
}

- (NSURL * _Nullable)linkURL {
    return self.link;
}

@end
