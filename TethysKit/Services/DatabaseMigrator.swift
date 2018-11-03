protocol DatabaseMigratorType {
    func migrate(_ from: DataService, to: DataService,
                 progress: @escaping (Double) -> Void,
                 finish: @escaping () -> Void)
    func deleteEverything(_ database: DataService,
                          progress: @escaping (Double) -> Void,
                          finish: @escaping () -> Void)
}

struct DatabaseMigrator: DatabaseMigratorType {
    func migrate(_ from: DataService, to: DataService,
                 progress: @escaping (Double) -> Void,
                 finish: @escaping () -> Void) {
        var progressCalls: Double = 0
        let expectedProgressCalls: Double = 4

        let updateProgress = {
            progressCalls += 1
            progress(progressCalls / expectedProgressCalls)
        }

        _ = from.allFeeds().then { oldResult in
            guard case let .success(oldFeeds) = oldResult else {
                return
            }
            updateProgress()
            let oldArticles = oldFeeds.reduce([Article]()) { $0 + Array($1.articlesArray) }

            _ = to.allFeeds().then { newResult in
                guard case let .success(existingFeeds) = newResult else {
                    return
                }
                updateProgress()
                let existingArticles = existingFeeds.reduce([Article]()) { $0 + Array($1.articlesArray) }

                let feedsToMigrate = oldFeeds.filter { !existingFeeds.contains($0) }
                let articlesToMigrate = oldArticles.filter { !existingArticles.contains($0) }

                var feedsDictionary: [Feed: Feed] = [:]
                var articlesDictionary: [Article: Article] = [:]

                let feedsUrls = feedsToMigrate.map { $0.url }
                let articleUrls = articlesToMigrate.map { $0.link }

                _ = to.batchCreate(feedURLs: feedsUrls, articleURLs: articleUrls).then { createResult in
                    guard case let .success(newFeeds, newArticles) = createResult else {
                        return
                    }
                    for (idx, oldFeed) in feedsToMigrate.enumerated() {
                        let newFeed = newFeeds[idx]
                        feedsDictionary[oldFeed] = newFeed
                    }
                    feedsDictionary.forEach(self.migrateFeed)

                    updateProgress()

                    for (idx, oldArticle) in articlesToMigrate.enumerated() {
                        let newArticle = newArticles[idx]
                        articlesDictionary[oldArticle] = newArticle

                        if let oldFeed = oldArticle.feed, let feed = feedsDictionary[oldFeed] {
                            newArticle.feed = feed
                            feed.addArticle(newArticle)
                        }
                    }
                    articlesDictionary.forEach(self.migrateArticle)

                    updateProgress()

                    _ = to.batchSave(Array(feedsDictionary.values),
                                     articles: Array(articlesDictionary.values)).then { _ in
                        updateProgress()
                        finish()
                    }
                }
            }
        }
    }

    func deleteEverything(_ database: DataService,
                          progress: @escaping (Double) -> Void,
                          finish: @escaping () -> Void) {
        _ = database.deleteEverything().then { _ in
            progress(1.0)
            finish()
        }
    }

    private func migrateFeed(from oldFeed: Feed, to newFeed: Feed) {
        newFeed.title = oldFeed.title
        newFeed.summary = oldFeed.summary
        for tag in newFeed.tags {
            newFeed.removeTag(tag)
        }
        for tag in oldFeed.tags {
            newFeed.addTag(tag)
        }
        newFeed.waitPeriod = oldFeed.waitPeriod
        newFeed.remainingWait = oldFeed.remainingWait
        newFeed.image = oldFeed.image
    }

    private func migrateArticle(from oldArticle: Article, to newArticle: Article) {
        newArticle.title = oldArticle.title
        newArticle.link = oldArticle.link
        newArticle.summary = oldArticle.summary
        newArticle.authors = oldArticle.authors
        newArticle.published = oldArticle.published
        newArticle.updatedAt = oldArticle.updatedAt
        newArticle.identifier = oldArticle.identifier
        newArticle.content = oldArticle.content
        if oldArticle.estimatedReadingTime > 0 {
            newArticle.estimatedReadingTime = oldArticle.estimatedReadingTime
        } else {
            newArticle.estimatedReadingTime = estimateReadingTime(oldArticle.content)
        }
        newArticle.read = oldArticle.read

        for flag in newArticle.flags {
            newArticle.removeFlag(flag)
        }
        for flag in oldArticle.flags {
            newArticle.addFlag(flag)
        }
    }
}
