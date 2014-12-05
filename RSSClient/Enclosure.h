//
//  Enclosure.h
//  RSSClient
//
//  Created by Rachel Brindle on 12/4/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Article;

@interface Enclosure : NSManagedObject

@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * kind;
@property (nonatomic, retain) NSData * data;
@property (nonatomic, retain) NSNumber * downloaded;
@property (nonatomic, retain) Article *article;

@end
