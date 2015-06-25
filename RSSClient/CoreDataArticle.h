#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CoreDataFeed;
@class CoreDataEnclosure;

@interface CoreDataArticle : NSManagedObject

@property (nullable, nonatomic, retain) NSString * title;
@property (nullable, nonatomic, retain) NSString * link;
@property (nullable, nonatomic, retain) NSString * summary;
@property (nullable, nonatomic, retain) NSString * author;
@property (null_resettable, nonatomic, retain) NSDate * published;
@property (nullable, nonatomic, retain) NSDate * updatedAt;
@property (nullable, nonatomic, retain) NSString * identifier;
@property (nullable, nonatomic, retain) NSString * content;
@property (nonatomic) BOOL read;
@property (nullable, nonatomic, retain) CoreDataFeed *feed;
@property (nullable, nonatomic, retain) id flags;
@property (nonnull, nonatomic, retain) NSSet <CoreDataEnclosure *> *enclosures;

@end

@interface CoreDataArticle (CoreDataGeneratedAccessors)

- (void)addEnclosuresObject:(nonnull CoreDataEnclosure *)value;
- (void)removeEnclosuresObject:(nonnull CoreDataEnclosure *)value;
- (void)addEnclosures:(nonnull NSSet <CoreDataEnclosure *> *)values;
- (void)removeEnclosures:(nonnull NSSet <CoreDataEnclosure *> *)values;

@end
