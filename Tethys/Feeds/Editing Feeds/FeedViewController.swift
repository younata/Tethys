import UIKit
import Result
import TethysKit
import CBGPromise

public final class FeedViewController: UIViewController {

    public let feedDetailView = FeedDetailView(forAutoLayout: ())
    fileprivate var feedURL: URL?
    fileprivate var feedTags: [String]?

    public let feed: Feed
    private let feedService: FeedService
    private let themeRepository: ThemeRepository
    fileprivate let tagEditorViewController: () -> TagEditorViewController

    public init(feed: Feed,
                feedService: FeedService,
                themeRepository: ThemeRepository,
                tagEditorViewController: @escaping () -> TagEditorViewController) {
        self.feed = feed
        self.feedService = feedService
        self.themeRepository = themeRepository
        self.tagEditorViewController = tagEditorViewController

        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
        self.navigationItem.title = self.feed.displayTitle

        self.view.addSubview(self.feedDetailView)
        self.feedDetailView.autoPinEdgesToSuperviewEdges()

        self.themeRepository.addSubscriber(self)
        self.feedDetailView.themeRepository = self.themeRepository
        self.feedDetailView.delegate = self
        self.feedDetailView.configure(title: feed.displayTitle, url: feed.url,
                                      summary: feed.displaySummary, tags: feed.tags)

        self.setTagMaxHeight(height: self.view.bounds.size.height)
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        self.setTagMaxHeight(height: size.height)
    }

    private func setTagMaxHeight(height: CGFloat) {
        self.feedDetailView.maxHeight = Int(height - 400)
    }

    @objc fileprivate func dismissFromNavigation() {
        self.navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc fileprivate func save() {
        var futures: [Future<Result<Feed, TethysError>>] = []
        if let theFeedURL = self.feedURL, theFeedURL != self.feed.url {
            futures.append(self.feedService.set(url: theFeedURL, on: self.feed))
        }
        if let tags = self.feedTags, tags != self.feed.tags {
            futures.append(self.feedService.set(tags: tags, of: self.feed))
        }
        guard !futures.isEmpty else {
            self.dismissFromNavigation()
            return
        }
        Promise<Result<Feed, TethysError>>.when(futures).then { _ in
            self.dismissFromNavigation()
        }
    }
}

extension FeedViewController: FeedDetailViewDelegate {
    public func feedDetailView(_ feedDetailView: FeedDetailView, urlDidChange url: URL) {
        self.feedURL = url
    }

    public func feedDetailView(_ feedDetailView: FeedDetailView, tagsDidChange tags: [String]) {
        self.feedTags = tags
    }

    public func feedDetailView(_ feedDetailView: FeedDetailView,
                               editTag tag: String?,
                               completion: @escaping (String) -> Void) {
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
