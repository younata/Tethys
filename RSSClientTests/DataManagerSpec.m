#import <Quick/Quick.h>
#import <Nimble/Nimble.h>
#import "DataManager.h"

QuickSpecBegin(DataManagerSpec)

describe(@"DataManager", ^{
    __block DataManagerObjc *subject;
    beforeEach(^{
        subject = [[DataManagerObjc alloc] init];
    });

    describe(@"-allTags", ^{
        it(@"should return a list of all unique tags in the database", ^{
            expect(subject.allTags).to(equal(@[]));
        });
    });

    describe(@"-allFeeds", ^{
        it(@"should return a list of all feeds in the database", ^{
            expect(subject.feeds).to(equal(@[]));
        });
    });

    describe(@"-feedsMatchingTag:", ^{
        context(@"when the tag is nil", ^{
            it(@"should return all feeds", ^{
                expect([subject feedsMatchingTag:nil]).to(equal(subject.feeds));
            });
        });

        context(@"when the tag is empty", ^{
            it(@"should return all feeds", ^{
                expect([subject feedsMatchingTag:@""]).to(equal(subject.feeds));
            });
        });

        context(@"when there are feeds containing tags that match the tag", ^{
            beforeEach(^{
                // TODO: set things up.
            });

            it(@"should return only those feeds", ^{
                expect([subject feedsMatchingTag:@"a"]).to(equal(@[]));
            });
        });
    });
});

QuickSpecEnd
