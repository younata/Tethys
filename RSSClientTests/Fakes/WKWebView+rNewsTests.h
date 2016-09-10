#import <WebKit/WebKit.h>

@interface WKWebView (rNewsTests)

@property (nullable, nonatomic, strong) URL *currentURL;
@property (nullable, nonatomic, strong, readonly) URLRequest *lastRequestLoaded;
@property (nullable, nonatomic, strong, readonly) NSString *lastHTMLStringLoaded;

@end
