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
@class Enclosure;

@interface Article : NSManagedObject

@property (nullable, nonatomic, retain) NSString * title;
@property (nullable, nonatomic, retain) NSString * link;
@property (nullable, nonatomic, retain) NSString * summary;
@property (nullable, nonatomic, retain) NSString * author;
@property (nullable, nonatomic, retain) NSDate * published;
@property (nullable, nonatomic, retain) NSDate * updatedAt;
@property (nullable, nonatomic, retain) NSString * identifier;
@property (nullable, nonatomic, retain) NSString * content;
@property (nonatomic) BOOL read;
@property (nullable, nonatomic, retain) Feed *feed;
@property (nullable, nonatomic, retain) id flags;
@property (nonnull, nonatomic, retain) NSSet *enclosures;

@end

@interface Article (CoreDataGeneratedAccessors)

- (void)addEnclosuresObject:(nonnull Enclosure *)value;
- (void)removeEnclosuresObject:(nonnull Enclosure *)value;
- (void)addEnclosures:(nonnull NSSet *)values;
- (void)removeEnclosures:(nonnull NSSet *)values;

@end
