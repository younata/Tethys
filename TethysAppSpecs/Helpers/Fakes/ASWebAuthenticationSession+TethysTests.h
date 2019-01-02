#import <AuthenticationServices/AuthenticationServices.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASWebAuthenticationSession (TethysTests)

@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) NSString *callbackURLScheme;
@property (nonatomic, readonly) ASWebAuthenticationSessionCompletionHandler completionHandler;

@property (nonatomic, readonly) BOOL began;
@property (nonatomic, readonly) BOOL cancelled;


@end

NS_ASSUME_NONNULL_END
