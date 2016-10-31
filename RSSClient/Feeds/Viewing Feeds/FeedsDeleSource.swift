import Foundation
import rNewsKit
import CBGPromise

public protocol FeedsSource {
    var feeds: [Feed] { get }

    func editFeed(feed: Feed)
    func shareFeed(feed: Feed)
    func markRead(feed: Feed) -> Future<Void>
    func deleteFeed(feed: Feed) -> Future<Bool>
}

public final class FeedsDeleSource: NSObject {
    fileprivate let tableView: UITableView
    fileprivate let feedsSource: FeedsSource
    fileprivate let themeRepository: ThemeRepository
    fileprivate let navigationController: UINavigationController
    fileprivate let mainQueue: OperationQueue
    fileprivate let articleListController: (Void) -> (ArticleListController)

    fileprivate var feeds: [Feed] {
        return self.feedsSource.feeds
    }

    public var scrollViewDelegate: UIScrollViewDelegate?

    // swiftlint:disable function_parameter_count
    public init(tableView: UITableView,
                feedsSource: FeedsSource,
                themeRepository: ThemeRepository,
                navigationController: UINavigationController,
                mainQueue: OperationQueue,
                articleListController: @escaping (Void) -> (ArticleListController)) {
        self.tableView = tableView
        self.feedsSource = feedsSource
        self.themeRepository = themeRepository
        self.navigationController = navigationController
        self.mainQueue = mainQueue
        self.articleListController = articleListController

        super.init()

        self.tableView.register(FeedTableCell.self, forCellReuseIdentifier: "read")
        self.tableView.register(FeedTableCell.self, forCellReuseIdentifier: "unread")
        // Prevents a green triangle which'll (dis)appear depending on
        // whether new feed loaded into it has unread articles or not.
    }
    // swiftlint:enable function_parameter_count

    fileprivate func feedAtIndexPath(_ indexPath: IndexPath) -> Feed {
        return self.feedsSource.feeds[indexPath.row]
    }

    fileprivate func configuredArticleListWithFeeds(_ feed: Feed) -> ArticleListController {
        let articleListController = self.articleListController()
        articleListController.feed = feed
        return articleListController
    }

    fileprivate func showArticleList(_ articleListController: ArticleListController, animated: Bool) {
        self.navigationController.pushViewController(articleListController, animated: animated)
    }
}

extension FeedsDeleSource: UIViewControllerPreviewingDelegate {
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                                  viewControllerForLocation location: CGPoint) -> UIViewController? {
        if let indexPath = self.tableView.indexPathForRow(at: location) {
            let feed = self.feedAtIndexPath(indexPath)
            let articleListController = configuredArticleListWithFeeds(feed)
            articleListController._previewActionItems = self.articleListPreviewItems(feed: feed)
            return articleListController
        }
        return nil
    }

    private func articleListPreviewItems(feed: Feed) -> [UIPreviewAction] {
        let readTitle = NSLocalizedString("FeedsTableViewController_PreviewItem_MarkRead", comment: "")
        let markRead = UIPreviewAction(title: readTitle, style: .default) { _ in
            _ = self.feedsSource.markRead(feed: feed)
        }
        let editTitle = NSLocalizedString("Generic_Edit", comment: "")
        let edit = UIPreviewAction(title: editTitle, style: .default) { _ in
            self.feedsSource.editFeed(feed: feed)
        }
        let shareTitle = NSLocalizedString("Generic_Share", comment: "")
        let share = UIPreviewAction(title: shareTitle, style: .default) { _ in
            self.feedsSource.shareFeed(feed: feed)
        }
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UIPreviewAction(title: deleteTitle, style: .destructive) { _ in
            _ = self.feedsSource.deleteFeed(feed: feed)
        }
        return [markRead, edit, share, delete]
    }

    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                                  commit viewControllerToCommit: UIViewController) {
        if let articleController = viewControllerToCommit as? ArticleListController {
            self.showArticleList(articleController, animated: true)
        }
    }
}

extension FeedsDeleSource: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.feeds.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let feed = self.feedAtIndexPath(indexPath)
        let cellTypeToUse = (feed.unreadArticles.isEmpty ? "unread": "read")
        // Prevents a green triangle which'll (dis)appear depending on
        // whether new feed loaded into it has unread articles or not.

        if let cell = tableView.dequeueReusableCell(withIdentifier: cellTypeToUse,
                                                    for: indexPath) as? FeedTableCell {
            cell.feed = feed
            cell.themeRepository = self.themeRepository
            return cell
        }
        return UITableViewCell()
    }
}

extension FeedsDeleSource: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        let al = self.configuredArticleListWithFeeds(self.feedAtIndexPath(indexPath))
        self.showArticleList(al, animated: true)
    }

    // swiftlint:disable line_length
    @objc(tableView:canEditRowAtIndexPath:) public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    @objc(tableView:commitEditingStyle:forRowAtIndexPath:) public func tableView(_ tableView: UITableView,
                                                                                 commit editingStyle: UITableViewCellEditingStyle,
                                                                                 forRowAt indexPath: IndexPath) {}
    // swiftlint:enable line_length

    public func tableView(_ tableView: UITableView,
                          editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UITableViewRowAction(style: .default, title: deleteTitle) {(_, indexPath: IndexPath!) in
            _ = self.feedsSource.deleteFeed(feed: self.feedAtIndexPath(indexPath)).then {
                if $0 {
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                } else {
                    tableView.reloadRows(at: [indexPath], with: .right)
                }
            }
        }

        let readTitle = NSLocalizedString("FeedsTableViewController_Table_EditAction_MarkRead", comment: "")
        let markRead = UITableViewRowAction(style: .normal, title: readTitle) {_, indexPath in
            _ = self.feedsSource.markRead(feed: self.feedAtIndexPath(indexPath)).then {
                self.mainQueue.addOperation {
                    tableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }
        }

        let editTitle = NSLocalizedString("Generic_Edit", comment: "")
        let edit = UITableViewRowAction(style: .normal, title: editTitle) {_, indexPath in
            self.feedsSource.editFeed(feed: self.feedAtIndexPath(indexPath))
        }
        edit.backgroundColor = UIColor.blue
        let shareTitle = NSLocalizedString("Generic_Share", comment: "")
        let share = UITableViewRowAction(style: .normal, title: shareTitle) {_ in
            self.feedsSource.shareFeed(feed: self.feedAtIndexPath(indexPath))
        }
        share.backgroundColor = UIColor.darkGreen()
        return [delete, markRead, edit, share]
    }
}

extension FeedsDeleSource: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.scrollViewDelegate?.scrollViewWillBeginDragging?(scrollView)
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                          withVelocity velocity: CGPoint,
                                          targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        self.scrollViewDelegate?.scrollViewWillEndDragging?(scrollView,
                                              withVelocity: velocity,
                                              targetContentOffset: targetContentOffset)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.scrollViewDelegate?.scrollViewDidScroll?(scrollView)
    }
}
