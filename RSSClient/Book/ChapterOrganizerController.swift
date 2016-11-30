import UIKit
import rNewsKit
import Ra

public protocol ChapterOrganizerControllerDelegate: class {
    func chapterOrganizerControllerDidChangeChapters(_: ChapterOrganizerController)
}

public class ChapterOrganizerController: UIViewController, Injectable {
    public let tableView: UITableView = {
        let tableView = UITableView(forAutoLayout: ())
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 100
        return tableView
    }()

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

    private var tableHeight: NSLayoutConstraint?

    public weak var delegate: ChapterOrganizerControllerDelegate?
    public weak var articles: DataStoreBackedArray<Article>?

    public var maxHeight: Int = 300 {
        didSet {
            self.tableHeight?.constant = CGFloat(min(self.maxHeight, self.chapters.count * 100))
        }
    }

    public var chapters: [Article] = [] {
        didSet {
            self.tableHeight?.constant = CGFloat(min(self.maxHeight, self.chapters.count * 100))
            self.delegate?.chapterOrganizerControllerDidChangeChapters(self)
            self.reorderButton.isEnabled = !self.chapters.isEmpty
        }
    }

    fileprivate var themeRepository: ThemeRepository
    fileprivate var settingsRepository: SettingsRepository
    private var articleListController: (Void) -> ArticleListController

    public init(themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                articleListController: @escaping (Void) -> ArticleListController) {
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.articleListController = articleListController
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            settingsRepository: injector.create(kind: SettingsRepository.self)!,
            articleListController: { injector.create(kind: ArticleListController.self)! }
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        self.tableHeight = self.tableView.autoSetDimension(
            .height,
            toSize: CGFloat(min(300, self.chapters.count * 100))
        )

        self.tableView.register(ArticleCell.self, forCellReuseIdentifier: "cell")

        let topStackView = UIStackView(forAutoLayout: ())
        topStackView.axis = .horizontal
        topStackView.distribution = UIStackViewDistribution.equalSpacing
        topStackView.alignment = .center

        self.view.addSubview(topStackView)
        topStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 40),
                                                  excludingEdge: .bottom)
        self.tableView.autoPinEdge(.top, to: .bottom, of: topStackView)

        topStackView.addArrangedSubview(self.reorderButton)
        topStackView.addArrangedSubview(self.addChapterButton)

        self.addChapterButton.addTarget(self,
                                        action: #selector(ChapterOrganizerController.addChapter),
                                        for: .touchUpInside)
        self.reorderButton.addTarget(self,
                                     action: #selector(ChapterOrganizerController.toggleEditMode),
                                     for: .touchUpInside)

        self.tableView.keyboardDismissMode = .onDrag
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.themeRepository.addSubscriber(self)
    }

    @objc private func addChapter() {
        let articleList = self.articleListController()
        articleList.delegate = self
        articleList.articles = self.articles ?? DataStoreBackedArray()
        self.navigationController?.pushViewController(articleList, animated: true)
    }

    @objc private func toggleEditMode() {
        if self.tableView.isEditing {
            self.reorderButton.setTitle(NSLocalizedString("ChapterOrganizerController_ReorderButton_Reorder",
                                                          comment: ""), for: .normal)
        } else {
            self.reorderButton.setTitle(NSLocalizedString("Generic_Done", comment: ""),
                                        for: .normal)
        }
        self.tableView.setEditing(!self.tableView.isEditing, animated: true)
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

    public func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    public func tableView(_ tableView: UITableView,
                          moveRowAt sourceIndexPath: IndexPath,
                          to destinationIndexPath: IndexPath) {
        let chapter = self.chapters[sourceIndexPath.row]
        var chapters = self.chapters
        chapters.remove(at: sourceIndexPath.row)
        chapters.insert(chapter, at: destinationIndexPath.row)
        self.chapters = chapters
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

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

extension ChapterOrganizerController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.tableView.backgroundColor = themeRepository.backgroundColor
        self.tableView.separatorColor = themeRepository.textColor

        self.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle
    }
}

extension ChapterOrganizerController: ArticleListControllerDelegate {
    public func articleListControllerCanSelectMultipleArticles(_: ArticleListController) -> Bool {
        return true
    }

    public func articleListControllerShouldShowToolbar(_: ArticleListController) -> Bool {
        return false
    }

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
        self.tableView.reloadData()
        _ = self.navigationController?.popViewController(animated: true)
    }

    public func articleListController(_: ArticleListController, shouldPreviewArticle article: Article) -> Bool {
        return false
    }
}
