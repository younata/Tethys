#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CoreDataArticle;

@interface CoreDataEnclosure : NSManagedObject

@property (null_resettable, nonatomic, retain) NSString * url;
@property (null_resettable, nonatomic, retain) NSString * kind;
@property (nullable, nonatomic, retain) NSData * data;
@property (null_resettable, nonatomic, retain) NSNumber * downloaded;
@property (nullable, nonatomic, retain) CoreDataArticle *article;

@end
