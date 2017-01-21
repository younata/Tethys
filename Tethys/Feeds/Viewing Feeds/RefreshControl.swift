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

    fileprivate var refreshControlStyle: RefreshControlStyle

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

    // swiftlint:disable function_parameter_count
    public init(notificationCenter: NotificationCenter,
                scrollView: UIScrollView,
                mainQueue: OperationQueue,
                themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                refresher: Refresher,
                lowPowerDiviner: LowPowerDiviner) {
        self.notificationCenter = notificationCenter
        self.scrollView = scrollView
        self.mainQueue = mainQueue
        self.settingsRepository = settingsRepository
        self.refresher = refresher
        self.lowPowerDiviner = lowPowerDiviner
        self.refreshControlStyle = settingsRepository.refreshControl
        super.init()
        notificationCenter.addObserver(
            self,
            selector: #selector(RefreshControl.powerStateDidChange),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
        self.spinner.addTarget(self, action: #selector(RefreshControl.beginRefresh), for: .valueChanged)
        themeRepository.addSubscriber(self)
        settingsRepository.addSubscriber(self)
        self.powerStateDidChange()
    }
    // swiftlint:enable function_parameter_count

    deinit {
        self.notificationCenter.removeObserver(self)
    }

    public func beginRefreshing(force: Bool = false) {
        guard !self.isRefreshing || force else { return }
        switch self.refreshControlStyle {
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
            let forcedStyle: RefreshControlStyle?
            if self.lowPowerDiviner.isLowPowerModeEnabled {
                forcedStyle = .breakout
            } else {
                forcedStyle = nil
            }
            self.changeRefreshStyle(forcedStyle: forcedStyle)
        }
    }

    fileprivate func changeRefreshStyle(forcedStyle: RefreshControlStyle? = nil) {
        if let _ = forcedStyle {
            self.switchInSpinner()
        } else {
            switch self.settingsRepository.refreshControl {
            case .spinner:
                self.switchInSpinner()
            case .breakout:
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

        self.refreshControlStyle = .breakout
    }

    private func switchInSpinner() {
        self.breakoutView.removeFromSuperview()
        self.scrollView.refreshControl = self.spinner

        if self.isRefreshing {
            self.endRefreshing()
            self.spinner.beginRefreshing()
        }

        self.refreshControlStyle = .spinner
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

extension RefreshControl: SettingsRepositorySubscriber {
    public func didChangeSetting(_ settingsRepository: SettingsRepository) {
        self.refreshControlStyle = settingsRepository.refreshControl
        self.changeRefreshStyle()
    }
}

extension RefreshControl: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard self.refreshControlStyle == .breakout else { return }
        self.breakoutView.scrollViewWillBeginDragging(scrollView)
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                          withVelocity velocity: CGPoint,
                                          targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard self.refreshControlStyle == .breakout else { return }
        self.breakoutView.scrollViewWillEndDragging(scrollView,
                                                    withVelocity: velocity,
                                                    targetContentOffset: targetContentOffset)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard self.refreshControlStyle == .breakout else { return }
        self.breakoutView.scrollViewDidScroll(scrollView)
    }
}

extension RefreshControl: BreakOutToRefreshDelegate {
    public func refreshViewDidRefresh(_ refreshView: BreakOutToRefreshView) {
        self.refresher.refresh()
    }
}
