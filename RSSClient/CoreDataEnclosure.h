#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CoreDataArticle;

@interface CoreDataEnclosure : NSManagedObject

@property (nullable, nonatomic, retain) NSString * url;
@property (nullable, nonatomic, retain) NSString * kind;
@property (nullable, nonatomic, retain) NSData * data;
@property (nullable, nonatomic, retain) NSNumber * downloaded;
@property (nullable, nonatomic, retain) CoreDataArticle *article;

@end
