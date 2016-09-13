#import <WebKit/WebKit.h>

@interface WKWebView (rNewsTests)

@property (nullable, nonatomic, strong) NSURL *currentURL;
@property (nullable, nonatomic, strong, readonly) NSURLRequest *lastRequestLoaded;
@property (nullable, nonatomic, strong, readonly) NSString *lastHTMLStringLoaded;

@end
