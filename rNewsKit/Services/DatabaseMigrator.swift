protocol DatabaseMigratorType {
    func migrate(from: DataService, to: DataService, progress: Double -> Void, finish: Void -> Void)
    func deleteEverything(database: DataService, progress: Double -> Void, finish: Void -> Void)
}

struct DatabaseMigrator: DatabaseMigratorType {
    func migrate(from: DataService, to: DataService, progress: Double -> Void, finish: Void -> Void) {
        var progressCalls: Double = 0
        let expectedProgressCalls: Double = 6

        let updateProgress = {
            progressCalls += 1
            progress(progressCalls / expectedProgressCalls)
        }

        from.allFeeds { oldFeeds in
            updateProgress()
            let oldArticles = oldFeeds.reduce([Article]()) { $0 + Array($1.articlesArray) }
            let oldEnclosures = oldArticles.reduce([Enclosure]()) { $0 + Array($1.enclosuresArray) }

            to.allFeeds { existingFeeds in
                updateProgress()
                let existingArticles = existingFeeds.reduce([Article]()) { $0 + Array($1.articlesArray) }
                let existingEnclosures = existingArticles.reduce([Enclosure]()) { $0 + Array($1.enclosuresArray) }

                let feedsToMigrate = oldFeeds.filter { !existingFeeds.contains($0) }
                let articlesToMigrate = oldArticles.filter { !existingArticles.contains($0) }
                let enclosuresToMigrate = oldEnclosures.filter { !existingEnclosures.contains($0) }

                var feedsDictionary: [Feed: Feed] = [:]
                var articlesDictionary: [Article: Article] = [:]
                var enclosuresDictionary: [Enclosure: Enclosure] = [:]

                to.batchCreate(feedsToMigrate.count,
                    articleCount: articlesToMigrate.count,
                    enclosureCount: enclosuresToMigrate.count) { newFeeds, newArticles, newEnclosures in
                        for (idx, oldFeed) in feedsToMigrate.enumerate() {
                            let newFeed = newFeeds[idx]
                            feedsDictionary[oldFeed] = newFeed
                        }
                        feedsDictionary.forEach(self.migrateFeed)

                        updateProgress()

                        for (idx, oldArticle) in articlesToMigrate.enumerate() {
                            let newArticle = newArticles[idx]
                            articlesDictionary[oldArticle] = newArticle

                            if let oldFeed = oldArticle.feed, let feed = feedsDictionary[oldFeed] {
                                newArticle.feed = feed
                                feed.addArticle(newArticle)
                            }
                        }
                        articlesDictionary.forEach(self.migrateArticle)

                        updateProgress()

                        for (idx, oldEnclosure) in enclosuresToMigrate.enumerate() {
                            let newEnclosure = newEnclosures[idx]
                            enclosuresDictionary[oldEnclosure] = newEnclosure

                            if let oldArticle = oldEnclosure.article, let article = articlesDictionary[oldArticle] {
                                newEnclosure.article = article
                                article.addEnclosure(newEnclosure)
                            }

                        }
                        enclosuresDictionary.forEach(self.migrateEnclosure)

                        updateProgress()

                        to.batchSave(Array(feedsDictionary.values),
                            articles: Array(articlesDictionary.values),
                            enclosures: Array(enclosuresDictionary.values)) {
                                updateProgress()
                                finish()
                        }
                }
            }
        }
    }

    func deleteEverything(database: DataService, progress: Double -> Void, finish: Void -> Void) {
        database.deleteEverything {
            progress(1.0)
            finish()
        }
    }

    private func migrateFeed(from oldFeed: Feed, to newFeed: Feed) {
        newFeed.title = oldFeed.title
        newFeed.url = oldFeed.url
        newFeed.summary = oldFeed.summary
        newFeed.query = oldFeed.query
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
        newArticle.author = oldArticle.author
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

    private func migrateEnclosure(from oldEnclosure: Enclosure, to newEnclosure: Enclosure) {
        newEnclosure.url = oldEnclosure.url
        newEnclosure.kind = oldEnclosure.kind
    }
}
