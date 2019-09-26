import UIKit
import CBGPromise

public protocol Refresher {
    func refresh()
}

public protocol LowPowerDiviner {
    var isLowPowerModeEnabled: Bool { get }
}
extension ProcessInfo: LowPowerDiviner {}

public enum RefreshControlStyle: Int, CustomStringConvertible {
    case spinner = 0
    case breakout = 1

    public var description: String {
        switch self {
        case .spinner:
            return NSLocalizedString("RefreshControlStyle_Spinner", comment: "")
        case .breakout:
            return NSLocalizedString("RefreshControlStyle_Breakout", comment: "")
        }
    }
}

public final class RefreshControl: NSObject {
    private let notificationCenter: NotificationCenter
    private let scrollView: UIScrollView
    private let mainQueue: OperationQueue
    private let settingsRepository: SettingsRepository
    fileprivate let refresher: Refresher
    fileprivate let lowPowerDiviner: LowPowerDiviner

    fileprivate var refreshControlStyle: RefreshControlStyle?

    public private(set) var breakoutView: BreakOutToRefreshView?

    public let spinner = UIRefreshControl()

    public init(notificationCenter: NotificationCenter,
                scrollView: UIScrollView,
                mainQueue: OperationQueue,
                settingsRepository: SettingsRepository,
                refresher: Refresher,
                lowPowerDiviner: LowPowerDiviner) {
        self.notificationCenter = notificationCenter
        self.scrollView = scrollView
        self.mainQueue = mainQueue
        self.settingsRepository = settingsRepository
        self.refresher = refresher
        self.lowPowerDiviner = lowPowerDiviner
        super.init()
        notificationCenter.addObserver(
            self,
            selector: #selector(RefreshControl.powerStateDidChange),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
        self.spinner.addTarget(self, action: #selector(RefreshControl.beginRefresh), for: .valueChanged)
        settingsRepository.addSubscriber(self)
        self.powerStateDidChange()
    }

    deinit {
        self.notificationCenter.removeObserver(self)
    }

    public func beginRefreshing(force: Bool = false) {
        guard let refreshControlStyle = self.refreshControlStyle, !self.isRefreshing || force else { return }
        switch refreshControlStyle {
        case .breakout:
            self.breakoutView?.beginRefreshing()
        case .spinner:
            self.spinner.beginRefreshing()
        }
    }

    public func endRefreshing(force: Bool = false) {
        guard self.isRefreshing || force else { return }

        self.breakoutView?.endRefreshing()
        self.spinner.endRefreshing()
    }

    public var isRefreshing: Bool {
        return self.breakoutView?.isRefreshing == true || self.spinner.isRefreshing
    }

    public func updateSize(_ size: CGSize) {
        guard let originalFrame = self.breakoutView?.frame else { return }
        self.breakoutView?.frame = CGRect(x: originalFrame.origin.x, y: originalFrame.origin.y,
                                          width: size.width, height: originalFrame.size.height)
        self.breakoutView?.layoutSubviews()
    }

    public func updateTheme() {
        guard let breakoutView = self.breakoutView else { return }

        self.applyTheme(to: breakoutView)
    }

    @objc private func powerStateDidChange() {
        self.mainQueue.addOperation {
            let forcedStyle: RefreshControlStyle?
            if self.lowPowerDiviner.isLowPowerModeEnabled {
                forcedStyle = .spinner
            } else {
                forcedStyle = nil
            }
            self.changeRefreshStyle(forcedStyle: forcedStyle)
        }
    }

    fileprivate func changeRefreshStyle(forcedStyle: RefreshControlStyle? = nil) {
        let style = forcedStyle ?? self.settingsRepository.refreshControl

        guard style != self.refreshControlStyle else { return }

        switch style {
        case .spinner:
            self.switchInSpinner()
        case .breakout:
            self.switchInBreakoutToRefresh()
        }
    }

    private func switchInBreakoutToRefresh() {
        let breakoutView = self.newBreakoutControl(scrollView: self.scrollView)
        self.breakoutView = breakoutView
        self.scrollView.addSubview(breakoutView)
        self.scrollView.refreshControl = nil

        if self.isRefreshing {
            self.endRefreshing(force: true)
            breakoutView.beginRefreshing()
        }

        self.refreshControlStyle = .breakout
    }

    private func switchInSpinner() {
        self.breakoutView?.removeFromSuperview()
        self.breakoutView = nil
        self.scrollView.refreshControl = self.spinner

        if self.isRefreshing {
            self.endRefreshing(force: true)
            self.spinner.beginRefreshing()
        }

        self.refreshControlStyle = .spinner
    }

    @objc private func beginRefresh() {
        self.refresher.refresh()
    }

    private func newBreakoutControl(scrollView: UIScrollView) -> BreakOutToRefreshView {
        let refreshView = BreakOutToRefreshView(scrollView: scrollView)
        refreshView.refreshDelegate = self
        refreshView.paddleColor = UIColor.blue
        refreshView.blockColors = [UIColor.darkGray, UIColor.gray, UIColor.lightGray]

        self.applyTheme(to: refreshView)
        return refreshView
    }

    private func applyTheme(to view: BreakOutToRefreshView) {
        view.scenebackgroundColor = Theme.backgroundColor
        view.textColor = Theme.textColor
        view.ballColor = Theme.highlightColor
    }
}

extension RefreshControl: SettingsRepositorySubscriber {
    public func didChangeSetting(_ settingsRepository: SettingsRepository) {
        self.powerStateDidChange()
    }
}

extension RefreshControl: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard self.refreshControlStyle == .breakout else { return }
        self.breakoutView?.scrollViewWillBeginDragging(scrollView)
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                          withVelocity velocity: CGPoint,
                                          targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard self.refreshControlStyle == .breakout else { return }
        self.breakoutView?.scrollViewWillEndDragging(scrollView,
                                                    withVelocity: velocity,
                                                    targetContentOffset: targetContentOffset)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard self.refreshControlStyle == .breakout else { return }
        self.breakoutView?.scrollViewDidScroll(scrollView)
    }
}

extension RefreshControl: BreakOutToRefreshDelegate {
    public func refreshViewDidRefresh(_ refreshView: BreakOutToRefreshView) {
        self.refresher.refresh()
    }
}
