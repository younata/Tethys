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

@property (nullable, nonatomic, retain) NSString * url;
@property (nullable, nonatomic, retain) NSString * kind;
@property (nullable, nonatomic, retain) NSData * data;
@property (nullable, nonatomic, retain) NSNumber * downloaded;
@property (nullable, nonatomic, retain) Article *article;

@end
