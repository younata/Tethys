//
//  RBActivityIndicator.m
//  Apartment
//
//  Created by Rachel Brindle on 6/5/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

#import "RBActivityIndicator.h"
#import "PureLayout.h"

@interface RBActivityIndicator ()

@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic, strong) UILabel *doingStuff;
@property (nonatomic, strong) UIProgressView *progressBar;

@end

@implementation RBActivityIndicator

- (void)setDisplayMessage:(NSString *)displayMessage
{
    _displayMessage = displayMessage;
    UIColor *color = nil;
    UIColor *textColor = nil;
    UIActivityIndicatorViewStyle style;
    if (self.style == RBActivityIndicatorStyleDark) {
        color = [UIColor blackColor];
        textColor = [UIColor lightTextColor];
        style = UIActivityIndicatorViewStyleWhite;
        self.progressBar.progressTintColor = [UIColor whiteColor];
    } else {
        color = [UIColor whiteColor];
        textColor = [UIColor darkTextColor];
        style = UIActivityIndicatorViewStyleGray;
        self.progressBar.progressTintColor = [UIColor blackColor];
    }
    self.progressBar.trackTintColor = color;
    
    self.backgroundColor = [color colorWithAlphaComponent:0.5];
    self.layer.shadowColor = color.CGColor;
    self.layer.shadowOffset = CGSizeMake(0.0, 0.0);
    self.layer.shadowRadius = 5.0;
    self.layer.shadowOpacity = 1.0 ;
    self.layer.masksToBounds = NO;
    self.layer.cornerRadius = 5;
    
    self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:style];
    [self addSubview:self.indicator];
    self.indicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.indicator autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:20];
    [self.indicator autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.indicator startAnimating];
    
    self.doingStuff = [[UILabel alloc] initForAutoLayout];
    [self addSubview:self.doingStuff];
    self.doingStuff.text = self.displayMessage;
    self.doingStuff.textAlignment = NSTextAlignmentCenter;
    self.doingStuff.textColor = textColor;
    [self.doingStuff autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(0, 20, 20, 20) excludingEdge:ALEdgeTop];
    if (self.progressBar == nil) {
        [self.doingStuff autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.indicator withOffset:8];
    } else {
        [self addSubview:self.progressBar];
        [self.progressBar autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:20];
        [self.progressBar autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:20];
        [self.progressBar autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.indicator withOffset:8];
        [self.doingStuff autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.progressBar withOffset:8];
    }
    
}

- (void)setProgress:(double)progress
{
    self.progressBar.progress = progress;
}

- (void)setShowProgressBar:(BOOL)showProgressBar
{
    if (self.progressBar == nil && showProgressBar) {
        self.progressBar = [[UIProgressView alloc] initForAutoLayout];
    }
    self.progressBar.hidden = showProgressBar;
}

- (void)setDone:(NSString *)doneMsg
{
    [UIView animateWithDuration:0.2 animations:^{
        self.indicator.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished){
        self.indicator.hidden = YES;
        self.doingStuff.text = doneMsg;
    }];
}

@end
