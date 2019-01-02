#import "ASWebAuthenticationSession+TethysTests.h"
#import "PCKMethodRedirector.h"
#import <objc/runtime.h>

static char *kURLKey = "kURLKey";
static char *kCallbackSchemeKey = "kCallbackSchemeKey";
static char *kHandlerKey = "kHandlerKey";

static char *kBeganKey = "kBeganKey";
static char *kCancelledKey = "kCancelledKey";

@interface ASWebAuthenticationSession (TethysTestsPrivate)
- (instancetype)initWithOriginalURL:(NSURL *)URL callbackURLScheme:(NSString *)callbackURLScheme completionHandler:(ASWebAuthenticationSessionCompletionHandler)completionHandler;

- (BOOL)original_start;
- (void)original_cancel;
@end

@implementation ASWebAuthenticationSession (TethysTests)

+ (void)load {
    [PCKMethodRedirector redirectSelector:@selector(initWithURL:callbackURLScheme:completionHandler:)
                                 forClass:[self class]
                                       to:@selector(initWithFakeURL:callbackURLScheme:completionHandler:)
                            andRenameItTo:@selector(initWithOriginalURL:callbackURLScheme:completionHandler:)];

    [PCKMethodRedirector redirectSelector:@selector(start)
                                 forClass:[self class]
                                       to:@selector(_start)
                            andRenameItTo:@selector(original_start)];

    [PCKMethodRedirector redirectSelector:@selector(cancel)
                                 forClass:[self class]
                                       to:@selector(_cancel)
                            andRenameItTo:@selector(original_cancel)];
}

- (instancetype)initWithFakeURL:(NSURL *)url callbackURLScheme:(NSString *)callbackURLScheme completionHandler:(ASWebAuthenticationSessionCompletionHandler)completionHandler {
    if ((self = [self initWithOriginalURL:url callbackURLScheme:callbackURLScheme completionHandler:completionHandler]) != nil) {
        objc_setAssociatedObject(self, kURLKey, url, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(self, kCallbackSchemeKey, callbackURLScheme, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(self, kHandlerKey, completionHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);

        objc_setAssociatedObject(self, kBeganKey, @(NO), OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(self, kCancelledKey, @(NO), OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return self;
}

- (NSURL *)url {
    return objc_getAssociatedObject(self, kURLKey);
}

- (NSString *)callbackURLScheme {
    return objc_getAssociatedObject(self, kCallbackSchemeKey);
}

- (ASWebAuthenticationSessionCompletionHandler)completionHandler {
    return objc_getAssociatedObject(self, kHandlerKey);
}

- (BOOL)began {
    return [(NSNumber *)objc_getAssociatedObject(self, kBeganKey) boolValue];
}

- (BOOL)cancelled {
    return [(NSNumber *)objc_getAssociatedObject(self, kCancelledKey) boolValue];
}

- (BOOL)_start {
    if ([self began]) {
        [NSException raise:@"Assertion fail" format:@"Tried to re-begin authentication while already in an authentication session"];
    }
    if ([self cancelled]) {
        [NSException raise:@"Assertion fail" format:@"Tried to re-begin authentication after cancelling authentication session"];
    }
    objc_setAssociatedObject(self, kBeganKey, @(YES), OBJC_ASSOCIATION_COPY_NONATOMIC);
    return YES;
}

- (void)_cancel {
    if (![self began]) {
        [NSException raise:@"Assertion Failed" format:@"Tried to cancel before starting authentication session"];
    }
    if ([self cancelled]) {
        [NSException raise:@"Assertion Failed" format:@"While not technically illegal, it makes no sense to cancel an already cancelled authentication session"];
    }

    objc_setAssociatedObject(self, kBeganKey, @(NO), OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, kCancelledKey, @(YES), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
