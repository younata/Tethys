import UIKit
import TethysKit

public protocol ChapterOrganizerControllerDelegate: class {
    func chapterOrganizerControllerDidChangeChapters(_: ChapterOrganizerController)
}

public class ChapterOrganizerController: UIViewController {
    public let addChapterButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("ChapterOrganizerController_AddChapter_Title", comment: ""), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(UIColor.darkGreen(), for: .normal)
        return button
    }()

    public let reorderButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("ChapterOrganizerController_ReorderButton_Reorder", comment: ""),
                        for: .normal)
        button.setTitleColor(UIColor.darkGreen(), for: .normal)
        button.setTitleColor(UIColor.gray, for: .disabled)
        button.isEnabled = false
        return button
    }()

    public let actionableTableView: ActionableTableView = {
        let atv = ActionableTableView(forAutoLayout: ())
        atv.tableView.estimatedRowHeight = 100
        return atv
    }()

    public weak var delegate: ChapterOrganizerControllerDelegate?
    public var articles: AnyCollection<Article> = AnyCollection<Article>([])

    public var maxHeight: Int {
        get { return self.actionableTableView.maxHeight }
        set { self.actionableTableView.maxHeight = newValue }
    }

    public var chapters: [Article] = [] {
        didSet {
            self.delegate?.chapterOrganizerControllerDidChangeChapters(self)
            self.reorderButton.isEnabled = !self.chapters.isEmpty
            self.actionableTableView.recalculateHeightConstraint()
        }
    }

    fileprivate var themeRepository: ThemeRepository
    fileprivate var settingsRepository: SettingsRepository
    private var articleListController: () -> ArticleListController

    public init(themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                articleListController: @escaping () -> ArticleListController) {
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.articleListController = articleListController
        self.actionableTableView.themeRepository = themeRepository
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.actionableTableView.tableView.dataSource = self
        self.actionableTableView.tableView.delegate = self
        self.view.addSubview(self.actionableTableView)
        self.actionableTableView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)
        self.actionableTableView.tableView.register(ArticleCell.self, forCellReuseIdentifier: "cell")

        self.actionableTableView.setActions([self.reorderButton, self.addChapterButton])
        self.addChapterButton.addTarget(self,
                                        action: #selector(ChapterOrganizerController.addChapter),
                                        for: .touchUpInside)
        self.reorderButton.addTarget(self,
                                     action: #selector(ChapterOrganizerController.toggleEditMode),
                                     for: .touchUpInside)

        self.actionableTableView.tableView.keyboardDismissMode = .onDrag
    }

    @objc private func addChapter() {
        let articleList = self.articleListController()
        articleList.delegate = self
        articleList.articles = self.articles
        self.navigationController?.pushViewController(articleList, animated: true)
    }

    @objc private func toggleEditMode() {
        if self.actionableTableView.tableView.isEditing {
            self.reorderButton.setTitle(NSLocalizedString("ChapterOrganizerController_ReorderButton_Reorder",
                                                          comment: ""), for: .normal)
        } else {
            self.reorderButton.setTitle(NSLocalizedString("Generic_Done", comment: ""),
                                        for: .normal)
        }
        self.actionableTableView.tableView.setEditing(!self.actionableTableView.tableView.isEditing, animated: true)
    }
}

extension ChapterOrganizerController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.chapters.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ArticleCell
        cell.themeRepository = self.themeRepository
        cell.hideUnread = true
        let chapter = self.chapters[indexPath.row]

        cell.configure(
            title: chapter.title,
            publishedDate: chapter.updatedAt ?? chapter.published,
            author: chapter.authorsString,
            read: true,
            readingTime: nil
        )
        return cell
    }

    public func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { return true }

    public func tableView(_ tableView: UITableView,
                          moveRowAt sourceIndexPath: IndexPath,
                          to destinationIndexPath: IndexPath) {
        let chapter = self.chapters[sourceIndexPath.row]
        var chapters = self.chapters
        chapters.remove(at: sourceIndexPath.row)
        chapters.insert(chapter, at: destinationIndexPath.row)
        self.chapters = chapters
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { return true }

    public func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    public func tableView(_ tableView: UITableView,
                          editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        if tableView.isEditing {
            return .none
        } else {
            return .delete
        }
    }
}

extension ChapterOrganizerController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView,
                          editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UITableViewRowAction(style: .destructive, title: deleteTitle) { _, indexPath in
            self.chapters.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        return [delete]
    }
}

extension ChapterOrganizerController: ArticleListControllerDelegate {
    public func articleListControllerCanSelectMultipleArticles(_: ArticleListController) -> Bool { return true }

    public func articleListControllerShouldShowToolbar(_: ArticleListController) -> Bool { return false }

    public func articleListControllerRightBarButtonItems(_ articleList: ArticleListController) -> [UIBarButtonItem] {
        return [
            UIBarButtonItem(title: NSLocalizedString("GenerateBookViewController_AddChapters", comment: ""),
                            style: .plain,
                            target: articleList,
                            action: #selector(ArticleListController.selectArticles))
        ]
    }

    public func articleListController(_: ArticleListController, canEditArticle article: Article) -> Bool {
        return false
    }

    public func articleListController(_: ArticleListController, shouldShowArticleView article: Article) -> Bool {
        return false
    }

    public func articleListController(_: ArticleListController, didSelectArticles articles: [Article]) {
        self.chapters += (articles.filter { !self.chapters.contains($0) })
        self.actionableTableView.tableView.reloadData()
        self.actionableTableView.recalculateHeightConstraint()
        _ = self.navigationController?.popViewController(animated: true)
    }

    public func articleListController(_: ArticleListController, shouldPreviewArticle article: Article) -> Bool {
        return false
    }
}
