#import "UIBarButtonItem+TethysTests.h"

@implementation UIBarButtonItem (TethysTests)

- (void)tap {
    id target = self.target;
    SEL action = self.action;
    id argument = nil;

    if (![target respondsToSelector:action]) {
        NSLog(@"===============> Unrecognized selector: %@, %@", target, NSStringFromSelector(action));
        return;
    }

    NSMethodSignature *methodSignature = [target methodSignatureForSelector:action];
    if (methodSignature == nil) {
        NSLog(@"================> unrecognized selector: %@, %@", target, NSStringFromSelector(action));
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
