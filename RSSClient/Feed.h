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

@property (nullable, nonatomic, retain) NSString * title;
@property (nullable, nonatomic, retain) NSString * url;
@property (nullable, nonatomic, retain) NSString * summary;
@property (nullable, nonatomic, retain) NSString * query;
@property (nullable, nonatomic, retain) id tags;
@property (nullable, nonatomic, retain) NSNumber * waitPeriod;
@property (nullable, nonatomic, retain) NSNumber * remainingWait;
@property (nonnull, nonatomic, retain) NSSet *articles;
@property (nullable, nonatomic, retain) id image;

@end

@interface Feed (CoreDataGeneratedAccessors)

- (void)addArticlesObject:(nonnull Article *)value;
- (void)removeArticlesObject:(nonnull Article *)value;
- (void)addArticles:(nonnull NSSet *)values;
- (void)removeArticles:(nonnull NSSet *)values;

@end
