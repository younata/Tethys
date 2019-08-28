import UIKit
import TethysKit

public protocol Bootstrapper {
    func begin(_ feedAndArticle: (feed: Feed, article: Article)?)
}

public final class BootstrapWorkFlow: Bootstrapper {
    private let window: UIWindow
    private let splitViewController: SplitViewController
    private let feedsTableViewController: () -> FeedListController
    private let blankViewController: () -> BlankViewController

    public init(window: UIWindow,
                splitViewController: SplitViewController,
                feedsTableViewController: @escaping () -> FeedListController,
                blankViewController: @escaping () -> BlankViewController) {
        self.window = window
        self.splitViewController = splitViewController
        self.feedsTableViewController = feedsTableViewController
        self.blankViewController = blankViewController
    }

    private var feedAndArticle: (feed: Feed, article: Article)?
    public func begin(_ feedAndArticle: (feed: Feed, article: Article)? = nil) {
        self.feedAndArticle = feedAndArticle
        self.showFeedsController()
    }

//    public func workFlowDidAdvance(_ workFlow: WorkFlow) {
//    }
//
//    public func workFlowDidFinish(_ workFlow: WorkFlow) {
//        self.showFeedsController()
//    }

    private func showFeedsController() {
        let feedsTableViewController = self.feedsTableViewController()
        self.splitViewController.masterNavigationController.viewControllers = [
            feedsTableViewController
        ]
        self.splitViewController.detailNavigationController.viewControllers = [
            self.blankViewController()
        ]
        self.splitViewController.viewControllers = [
            self.splitViewController.masterNavigationController,
            self.splitViewController.detailNavigationController
        ]

        if let (feed, article) = self.feedAndArticle {
            let articleListController = feedsTableViewController.showFeed(feed, animated: false)
            _ = articleListController.showArticle(article, animated: false)
        }

        self.window.rootViewController = self.splitViewController
    }
}
