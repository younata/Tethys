//
//  Article.h
//  RSSClient
//
//  Created by Rachel Brindle on 9/28/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Feed;

@interface Article : NSManagedObject

@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * link;
@property (nonatomic, retain) NSString * summary;
@property (nonatomic, retain) NSString * author;
@property (nonatomic, retain) NSDate * published;
@property (nonatomic, retain) id enclosures;
@property (nonatomic, retain) NSDate * updatedAt;
@property (nonatomic, retain) NSString * identifier;
@property (nonatomic, retain) NSString * content;
@property (nonatomic) BOOL read;
@property (nonatomic, retain) id enclosureURLs;
@property (nonatomic, retain) Feed *feed;
@property (nonatomic, retain) id preview;

@end
