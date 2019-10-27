import TethysKit

func feedFactory(
    title: String = "title",
    url: URL = URL(string: "https://example.com/feed")!,
    summary: String = "summary",
    tags: [String] = [],
    unreadCount: Int = 0,
    image: Image? = nil
    ) -> Feed {
    return Feed(
        title: title,
        url: url,
        summary: summary,
        tags: tags,
        unreadCount: unreadCount,
        image: image
    )
}

func articleFactory(
    title: String = "",
    link: URL = URL(string: "https://example.com")!,
    summary: String = "",
    authors: [Author] = [],
    identifier: String = "",
    content: String = "",
    read: Bool = false,
    estimatedReadingTime: TimeInterval = 0,
    published: Date = Date(),
    updated: Date? = nil
    ) -> Article {
    return Article(
        title: title,
        link: link,
        summary: summary,
        authors: authors,
        identifier: identifier,
        content: content,
        read: read,
        published: published,
        updated: updated
    )
}
