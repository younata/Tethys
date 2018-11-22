import TethysKit

func articleFactory(
    title: String = "",
    link: URL = URL(string: "https://example.com")!,
    summary: String = "",
    authors: [Author] = [],
    published: Date = Date(),
    updatedAt: Date? = nil,
    identifier: String = "",
    content: String = "",
    read: Bool = false,
    synced: Bool = false,
    estimatedReadingTime: TimeInterval = 0,
    feed: Feed? = nil,
    flags: [String] = []
    ) -> Article {
    return Article(
        title: title,
        link: link,
        summary: summary,
        authors: authors,
        published: published,
        updatedAt: updatedAt,
        identifier: identifier,
        content: content,
        read: read,
        synced: synced,
        estimatedReadingTime: estimatedReadingTime,
        feed: feed,
        flags: flags
    )
}
