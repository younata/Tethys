import UIKit
import BreakOutToRefresh
import CBGPromise

public protocol Refresher {
    func refresh()
}

public protocol LowPowerDiviner {
    var isLowPowerModeEnabled: Bool { get }
}

extension ProcessInfo: LowPowerDiviner {}

public final class RefreshControl: NSObject {
    private let notificationCenter: NotificationCenter
    private let scrollView: UIScrollView
    private let mainQueue: OperationQueue
    fileprivate let refresher: Refresher
    fileprivate let lowPowerDiviner: LowPowerDiviner

    fileprivate enum RefreshControlType {
        case breakout
        case spinner
    }

    fileprivate var refreshControlUsed: RefreshControlType = .breakout

    public private(set) lazy var breakoutView: BreakOutToRefreshView = {
        let refreshView = BreakOutToRefreshView(scrollView: self.scrollView)
        refreshView.breakoutDelegate = self
        refreshView.scenebackgroundColor = UIColor.white
        refreshView.paddleColor = UIColor.blue
        refreshView.ballColor = UIColor.darkGreen()
        refreshView.blockColors = [UIColor.darkGray, UIColor.gray, UIColor.lightGray]
        return refreshView
    }()

    public let spinner = UIRefreshControl()

    public init(notificationCenter: NotificationCenter,
                scrollView: UIScrollView,
                mainQueue: OperationQueue,
                themeRepository: ThemeRepository,
                refresher: Refresher,
                lowPowerDiviner: LowPowerDiviner) {
        self.notificationCenter = notificationCenter
        self.scrollView = scrollView
        self.mainQueue = mainQueue
        self.refresher = refresher
        self.lowPowerDiviner = lowPowerDiviner
        super.init()
        notificationCenter.addObserver(
            self,
            selector: #selector(RefreshControl.powerStateDidChange),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
        self.powerStateDidChange()
        self.spinner.addTarget(self, action: #selector(RefreshControl.beginRefresh), for: .valueChanged)
        themeRepository.addSubscriber(self)
    }

    deinit {
        self.notificationCenter.removeObserver(self)
    }

    public func beginRefreshing(force: Bool = false) {
        guard !self.isRefreshing || force else { return }
        switch self.refreshControlUsed {
        case .breakout:
            self.breakoutView.beginRefreshing()
        case .spinner:
            self.spinner.beginRefreshing()
        }
    }

    public func endRefreshing(force: Bool = false) {
        guard self.isRefreshing || force else { return }

        self.breakoutView.endRefreshing()
        self.spinner.endRefreshing()
    }

    public var isRefreshing: Bool {
        return self.breakoutView.isRefreshing || self.spinner.isRefreshing
    }

    public func updateSize(_ size: CGSize) {
        let height: CGFloat = 100
        self.breakoutView.frame = CGRect(x: 0, y: -height, width: size.width, height: height)
        self.breakoutView.layoutSubviews()
    }

    @objc private func powerStateDidChange() {
        self.mainQueue.addOperation {
            if self.lowPowerDiviner.isLowPowerModeEnabled {
                self.switchInSpinner()
            } else {
                self.switchInBreakoutToRefresh()
            }
        }
    }

    private func switchInBreakoutToRefresh() {
        self.scrollView.addSubview(self.breakoutView)
        self.scrollView.refreshControl = nil

        if self.isRefreshing {
            self.endRefreshing()
            self.breakoutView.beginRefreshing()
        }

        self.refreshControlUsed = .breakout
    }

    private func switchInSpinner() {
        self.breakoutView.removeFromSuperview()
        self.scrollView.refreshControl = self.spinner

        if self.isRefreshing {
            self.endRefreshing()
            self.spinner.beginRefreshing()
        }

        self.refreshControlUsed = .spinner
    }

    @objc private func beginRefresh() {
        self.refresher.refresh()
    }
}

extension RefreshControl: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.breakoutView.scenebackgroundColor = themeRepository.backgroundColor
        self.breakoutView.textColor = themeRepository.textColor

        self.spinner.tintColor = themeRepository.textColor
    }
}

extension RefreshControl: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard self.refreshControlUsed == .breakout else { return }
        self.breakoutView.scrollViewWillBeginDragging(scrollView)
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                          withVelocity velocity: CGPoint,
                                          targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard self.refreshControlUsed == .breakout else { return }
        self.breakoutView.scrollViewWillEndDragging(scrollView,
                                                    withVelocity: velocity,
                                                    targetContentOffset: targetContentOffset)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard self.refreshControlUsed == .breakout else { return }
        self.breakoutView.scrollViewDidScroll(scrollView)
    }
}

extension RefreshControl: BreakOutToRefreshDelegate {
    public func refreshViewDidRefresh(_ refreshView: BreakOutToRefreshView) {
        self.refresher.refresh()
    }
}
