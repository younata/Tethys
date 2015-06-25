#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CoreDataArticle;

@interface CoreDataFeed : NSManagedObject

@property (nullable, nonatomic, retain) NSString * title;
@property (nullable, nonatomic, retain) NSString * url;
@property (nullable, nonatomic, retain) NSString * summary;
@property (nullable, nonatomic, retain) NSString * query;
@property (nullable, nonatomic, retain) id tags;
@property (nullable, nonatomic, retain) NSNumber * waitPeriod;
@property (nullable, nonatomic, retain) NSNumber * remainingWait;
@property (nonnull, nonatomic, retain) NSSet <CoreDataArticle *> *articles;
@property (nullable, nonatomic, retain) id image;

@end

@interface CoreDataFeed (CoreDataGeneratedAccessors)

- (void)addArticlesObject:(nonnull CoreDataArticle *)value;
- (void)removeArticlesObject:(nonnull CoreDataArticle *)value;
- (void)addArticles:(nonnull NSSet <CoreDataArticle *> *)values;
- (void)removeArticles:(nonnull NSSet <CoreDataArticle *> *)values;

@end
