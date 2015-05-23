#import "DataManager.h"
#import "rNews-Swift.h"

@implementation DataManagerObjc

- (nonnull NSArray *)allTags {
    return @[];
}

- (nonnull NSArray *)feeds {
    return @[];
}

- (nonnull NSArray *)feedsMatchingTag:(nullable NSString *)tag {
    return @[];
}

- (void)newFeed:(nonnull NSString *)feedURL completion:(nonnull FeedCreation)completion {

}

- (nonnull Feed *)newQueryFeed:(nonnull NSString *)title code:(nonnull NSString *)code summary:(nullable NSString *)summary {
    return [Feed new];
}

@end
