import UIKit
import Muon
import Ra
import rNewsKit

public final class FeedViewController: UIViewController, Injectable {
    public var feed: rNewsKit.Feed? = nil {
        didSet {
            self.navigationItem.title = self.feed?.displayTitle ?? ""
            self.resetFeedView()
        }
    }

    public let feedEditView = FeedEditView(forAutoLayout: ())
    fileprivate var feedURL: URL? = nil
    fileprivate var feedTags: [String]? = nil

    private let feedRepository: DatabaseUseCase
    private let themeRepository: ThemeRepository
    fileprivate let tagEditorViewController: (Void) -> TagEditorViewController

    public init(feedRepository: DatabaseUseCase,
                themeRepository: ThemeRepository,
                tagEditorViewController: @escaping (Void) -> TagEditorViewController) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        self.tagEditorViewController = tagEditorViewController

        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(kind: DatabaseUseCase.self)!,
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            tagEditorViewController: {injector.create(kind: TagEditorViewController.self)!}
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let dismissTitle = NSLocalizedString("Generic_Dismiss", comment: "")
        let dismissButton = UIBarButtonItem(title: dismissTitle, style: .plain, target: self,
                                            action: #selector(FeedViewController.dismissFromNavigation))
        self.navigationItem.leftBarButtonItem = dismissButton

        let saveTitle = NSLocalizedString("Generic_Save", comment: "")
        let saveButton = UIBarButtonItem(title: saveTitle, style: .plain, target: self, action:
            #selector(FeedViewController.save))
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.title = self.feed?.displayTitle ?? ""

        self.view.addSubview(self.feedEditView)
        self.feedEditView.autoPinEdgesToSuperviewEdges()

        self.themeRepository.addSubscriber(self)
        self.feedEditView.themeRepository = self.themeRepository

        self.feedEditView.delegate = self

        self.setTagMaxHeight(height: self.view.bounds.size.height)
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        self.setTagMaxHeight(height: size.height)
    }

    private func setTagMaxHeight(height: CGFloat) {
        self.feedEditView.maxHeight = Int(height - 400)
    }

    fileprivate func resetFeedView() {
        guard let feed = self.feed else { return }
        self.feedEditView.configure(title: feed.displayTitle, url: feed.url,
                                    summary: feed.displaySummary, tags: feed.tags)
    }

    @objc fileprivate func dismissFromNavigation() {
        self.navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc fileprivate func save() {
        if let theFeed = self.feed {
            if let theFeedURL = self.feedURL, theFeedURL != theFeed.url {
                theFeed.url = theFeedURL
            }
            if let theFeedTags = self.feedTags, theFeedTags != theFeed.tags {
                let existingTags = theFeed.tags
                existingTags.forEach { theFeed.removeTag($0) }
                theFeedTags.forEach { theFeed.addTag($0) }
            }
            _ = self.feedRepository.saveFeed(theFeed)
        }
        self.dismissFromNavigation()
    }
}

extension FeedViewController: FeedEditViewDelegate {
    public func feedEditView(_ feedEditView: FeedEditView, urlDidChange url: URL) {
        self.feedURL = url
    }

    public func feedEditView(_ feedEditView: FeedEditView, tagsDidChange tags: [String]) {
        self.feedTags = tags
    }

    public func feedEditView(_ feedEditView: FeedEditView,
                             editTag tag: String?,
                             completion: @escaping (String) -> (Void)) {
        let tagEditorViewController = self.tagEditorViewController()
        if let tag = tag {
            tagEditorViewController.configure(tag: tag)
        }
        tagEditorViewController.onSave = completion
        self.navigationController?.pushViewController(tagEditorViewController, animated: true)
    }
}

extension FeedViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: themeRepository.textColor
        ]
    }
}
