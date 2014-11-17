//
//  Feed.m
//  RSSClient
//
//  Created by Rachel Brindle on 9/28/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

#import "Feed.h"
#import "Article.h"


@implementation Feed

@dynamic title;
@dynamic url;
@dynamic summary;
@dynamic image;
@dynamic articles;
@dynamic groups;

- (NSUInteger)unreadArticles
{
    NSUInteger ret = 0;
    for (Article *article in self.articles) {
        ret += article.read ? 0 : 1;
    }
    return ret;
}

@end
