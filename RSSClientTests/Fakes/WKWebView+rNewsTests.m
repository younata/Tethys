#import "WKWebView+rNewsTests.h"
#import "PCKMethodRedirector.h"
#import <objc/runtime.h>

static char * kUrlKey;
static char * kRequestKey;
static char * kHtmlKey;

@interface WKWebView (rNewsTestsPrivate)

- (nullable WKNavigation *)original_loadRequest:(nonnull URLRequest *)request;
- (nullable WKNavigation *)original_loadHTMLString:(nonnull NSString *)string baseURL:(nullable URL *)baseURL;

@end

@implementation WKWebView (rNewsTests)

+ (void)load {
    [PCKMethodRedirector redirectSelector:@selector(loadRequest:)
                                 forClass:[self class]
                                       to:@selector(_loadRequest:)
                            andRenameItTo:@selector(original_loadRequest:)];

    [PCKMethodRedirector redirectSelector:@selector(loadHTMLString:baseURL:)
                                 forClass:[self class]
                                       to:@selector(_loadHTMLString:baseURL:)
                            andRenameItTo:@selector(original_loadHTMLString:baseURL:)];
}

- (void)setCurrentURL:(URL * __nullable)currentURL {
    objc_setAssociatedObject(self, &kUrlKey, currentURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (URL * __nullable)currentURL {
    return objc_getAssociatedObject(self, &kUrlKey);
}

- (URL * __nullable)URL {
    return self.currentURL;
}

- (URLRequest * __nullable)lastRequestLoaded {
    return objc_getAssociatedObject(self, &kRequestKey);
}

- (nullable WKNavigation *)_loadRequest:(nonnull URLRequest *)request {
    objc_setAssociatedObject(self, &kRequestKey, request, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return nil;
}

- (NSString * __nullable)lastHTMLStringLoaded {
    return objc_getAssociatedObject(self, &kHtmlKey);
}

- (nullable WKNavigation *)_loadHTMLString:(nonnull NSString *)string baseURL:(nullable URL *)baseURL {
    objc_setAssociatedObject(self, &kHtmlKey, string, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return nil;
}

@end
