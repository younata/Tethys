import UIKit
import Swinject
import TethysKit

let OpenFeedUserActivityIdentifier = "com.rachelbrindle.RSSClient.feed"
let OpenArticleUserActivityIdentifier = "com.rachelbrindle.RSSClient.article"

let FeedUserActivityInfoKey = "com.rachelbrindle.RSSClient.useractivity.feed"
let ArticleUserActivityInfoKey = "com.rachelbrindle.RSSClient.useractivity.article"

public class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    public var window: UIWindow?

    public lazy var container: Container = {
        let container = Container()
        TethysKit.configure(container: container)
        Tethys.configure(container: container)
        return container
    }()

    private lazy var analytics: Analytics = {
        self.container.resolve(Analytics.self)!
    }()

    private lazy var feedService: FeedService = {
        return self.container.resolve(FeedService.self)!
    }()

    private lazy var importUseCase: ImportUseCase = {
        self.container.resolve(ImportUseCase.self)!
    }()

    private func splitView() -> SplitViewController {
        self.container.resolve(SplitViewController.self)!
    }

    private func feedList() -> FeedListController {
        return self.container.resolve(FeedListController.self)!
    }

    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
        let feed: Feed?
        let article: Article?
        if let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity,
            let interpretted = self.interpret(activity: userActivity) {
            feed = interpretted.feed
            article = interpretted.article
        } else if let windowScene = scene as? UIWindowScene, self.window == nil {
            self.window = UIWindow(windowScene: windowScene)
            self.window?.makeKeyAndVisible()
            feed = nil
            article = nil
        } else {
            feed = nil
            article = nil
        }
        self.setup(window: self.window!, feed: feed, article: article)
    }

    public func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }

    private func interpret(activity: NSUserActivity) -> (feed: Feed, article: Article?)? {
        return nil
//        switch activity.persistentIdentifier {
//        case OpenFeedUserActivityIdentifier:
//            guard let feedIdentifier = activity.userInfo?[FeedUserActivityInfoKey] as? String else {
//                return nil
//            }
//            return (feed: nil, article: nil)
//            break
//        case OpenArticleUserActivityIdentifier:
//            break
//        default:
//            return nil
//        }
    }

    private func configure(window: UIWindow?, with activity: NSUserActivity) -> Bool {
//        if activity.title == GalleryOpenDetailPath {
//            if let photoID = activity.userInfo?[GalleryOpenDetailPhotoIdKey] as? String {
//
//                if let photoDetailViewController = PhotoDetailViewController.loadFromStoryboard() {
//                    photoDetailViewController.photo = Photo(name: photoID)
//
//                    if let navigationController = window?.rootViewController as? UINavigationController {
//                        navigationController.pushViewController(photoDetailViewController, animated: false)
//                        return true
//                    }
//                }
//            }
//        }
        return false
    }

    private func setup(window: UIWindow, feed: Feed?, article: Article?) {
        let feedList = self.feedList()
        let splitView = self.splitView()
        splitView.masterNavigationController.viewControllers = [feedList]
        splitView.detailNavigationController.viewControllers = [UIViewController()]
        splitView.viewControllers = [
            splitView.masterNavigationController,
            splitView.detailNavigationController
        ]

        if let feed = feed, let article = article {
            let articleListController = feedList.showFeed(feed, animated: false)
            _ = articleListController.showArticle(article, animated: false)
        }

        window.rootViewController = splitView
    }
}
