#import <Foundation/Foundation.h>

@class Feed;

typedef void (^FeedCreation)( Feed * __nullable ,  NSError * __nullable );

@interface DataManagerObjc : NSObject

- (nonnull NSArray *)allTags;
- (nonnull NSArray *)feeds;
- (nonnull NSArray *)feedsMatchingTag:(nullable NSString *)tag;
- (void)newFeed:(nonnull NSString *)feedURL completion:(nonnull FeedCreation)completion;
- (nonnull Feed *)newQueryFeed:(nonnull NSString *)title code:(nonnull NSString *)code summary:(nullable NSString *)summary;

@end
