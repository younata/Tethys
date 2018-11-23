import Tethys
import TethysKit

final class FakeArticleCellController: ArticleCellController {
    private(set) var configureCalls: [(cell: ArticleCell, article: Article)] = []
    func configure(cell: ArticleCell, with article: Article) {
        self.configureCalls.append((cell, article))
    }
}
