//
//  RBActivityIndicator.h
//  Apartment
//
//  Created by Rachel Brindle on 6/5/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    RBActivityIndicatorStyleLight,
    RBActivityIndicatorStyleDark,
} RBActivityIndicatorStyle;

@interface RBActivityIndicator : UIView

@property (nonatomic) RBActivityIndicatorStyle style;
@property (nonatomic, copy) NSString *displayMessage;
@property (nonatomic) double progress;
@property (nonatomic) BOOL showProgressBar;

- (void)setDone:(NSString *)doneMsg;

@end
