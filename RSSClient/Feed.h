//
//  Feed.h
//  RSSClient
//
//  Created by Rachel Brindle on 9/28/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Article;

@interface Feed : NSManagedObject

@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * summary;
@property (nonatomic, retain) NSString * query;
@property (nonatomic, retain) id tags;
@property (nonatomic, retain) NSNumber * waitPeriod;
@property (nonatomic, retain) NSNumber * remainingWait;
@property (nonatomic, retain) NSSet *articles;

@end

@interface Feed (CoreDataGeneratedAccessors)

- (void)addArticlesObject:(Article *)value;
- (void)removeArticlesObject:(Article *)value;
- (void)addArticles:(NSSet *)values;
- (void)removeArticles:(NSSet *)values;

@end
