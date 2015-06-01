#import "UIBarButtonItem+rNewsTests.h"

@implementation UIBarButtonItem (rNewsTests)

- (void)tap {
    id target = self.target;
    SEL action = self.action;
    id argument = nil;

    NSMethodSignature *methodSignature = [target methodSignatureForSelector:action];
    if (methodSignature == nil) {
        NSLog(@"================> %@, %@", target, NSStringFromSelector(action));
        return;
    }
    if (methodSignature.numberOfArguments == 1) {
        argument = self;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [target performSelector:action withObject:argument];
#pragma clang diagnostic pop
}

@end
