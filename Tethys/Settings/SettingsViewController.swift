import UIKit
import PureLayout
import SafariServices
import Result
import TethysKit

public final class SettingsViewController: UIViewController {
    public let tableView = UITableView(frame: CGRect.zero, style: .grouped)

    fileprivate let settingsRepository: SettingsRepository
    fileprivate let opmlService: OPMLService
    fileprivate let mainQueue: OperationQueue
    fileprivate let accountService: AccountService
    fileprivate let messenger: Messenger
    fileprivate let loginController: LoginController
    fileprivate let documentationViewController: (Documentation) -> DocumentationViewController

    fileprivate lazy var showReadingTimes: Bool = { return self.settingsRepository.showEstimatedReadingLabel }()
    fileprivate lazy var refreshControlStyle: RefreshControlStyle = { return self.settingsRepository.refreshControl }()

    fileprivate var accounts: [Account] = []

    public init(settingsRepository: SettingsRepository,
                opmlService: OPMLService,
                mainQueue: OperationQueue,
                accountService: AccountService,
                messenger: Messenger,
                loginController: LoginController,
                documentationViewController: @escaping (Documentation) -> DocumentationViewController) {
        self.settingsRepository = settingsRepository
        self.opmlService = opmlService
        self.mainQueue = mainQueue
        self.accountService = accountService
        self.messenger = messenger
        self.loginController = loginController
        self.documentationViewController = documentationViewController

        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("SettingsViewController_Title", comment: "")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save,
            target: self,
            action: #selector(SettingsViewController.didTapSave))
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Generic_Close", comment: ""),
                                                                style: .plain, target: self,
                                                                action: #selector(SettingsViewController.didTapDismiss))

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: .zero)

        self.tableView.register(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "switch")

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.allowsMultipleSelection = true

        self.accountService.accounts().then { results in
            self.mainQueue.addOperation {
                self.accounts = results.compactMap { $0.value }
                self.reloadTable()
            }
        }

        self.applyTheme()
        self.reloadTable()
    }

    private func applyTheme() {
        self.tableView.backgroundColor = Theme.backgroundColor
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.splitViewController?.setNeedsStatusBarAppearanceUpdate()
        self.reloadTable()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        self.reloadTable()
    }

    public override var canBecomeFirstResponder: Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {
        let save = UIKeyCommand(input: "s", modifierFlags: .command,
                                action: #selector(SettingsViewController.didTapSave))
        let dismiss = UIKeyCommand(input: "w", modifierFlags: .command,
                                   action: #selector(SettingsViewController.didTapDismiss))

        save.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Save", comment: "")
        dismiss.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Close", comment: "")

        return [save, dismiss]
    }

    @objc fileprivate func didTapDismiss() {
        let presenter = self.presentingViewController ?? self.navigationController?.presentingViewController
        if let presentingController = presenter {
            presentingController.dismiss(animated: true, completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }

    @objc fileprivate func didTapSave() {
        self.settingsRepository.showEstimatedReadingLabel = self.showReadingTimes
        self.settingsRepository.refreshControl = self.refreshControlStyle
        self.didTapDismiss()
    }

    fileprivate func reloadTable() {
        self.tableView.reloadData()
        let currentRefreshStyleIndexPath = IndexPath(row: self.refreshControlStyle.rawValue,
                                                     section: SettingsSection.refresh.rawValue)
        self.tableView.selectRow(at: currentRefreshStyleIndexPath, animated: false, scrollPosition: .none)
    }
}

extension SettingsViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.numberOfSettings()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        guard let section = SettingsSection(rawValue: sectionNum) else {
            return 0
        }
        switch section {
        case .account:
            return 1 + self.accounts.count
        case .refresh:
            return 2
        case .other:
            return OtherSection.numberOfOptions
        case .credits:
            return 3
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = SettingsSection(rawValue: indexPath.section) else {
            return TableViewCell()
        }
        switch section {
        case .account:
            return self.accountCell(indexPath: indexPath)
        case .refresh:
            return self.refreshCell(indexPath: indexPath)
        case .other:
            return self.otherCell(indexPath: indexPath)
        case .credits:
            return self.creditCell(indexPath: indexPath)
        }
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection sectionNum: Int) -> String? {
        guard let section = SettingsSection(rawValue: sectionNum) else { return nil }
        return section.description
    }

    private func accountCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        cell.textLabel?.text = NSLocalizedString("SettingsViewController_Account_Inoreader", comment: "")
        if indexPath.row < self.accounts.count {
            cell.detailTextLabel?.text = self.accounts[indexPath.row].username
        } else {
            cell.detailTextLabel?.text = NSLocalizedString("SettingsViewController_Account_Add", comment: "")
        }
        return cell
    }

    private func refreshCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        guard let refreshStyle = RefreshControlStyle(rawValue: indexPath.row) else { return cell }
        cell.textLabel?.text = refreshStyle.description
        return cell
    }

    private func otherCell(indexPath: IndexPath) -> UITableViewCell {
        let row = OtherSection(rawValue: indexPath.row)!
        var tableCell: UITableViewCell
        switch row {
        case .showReadingTimes:
            let cell = self.tableView.dequeueReusableCell(withIdentifier: "switch",
                                                     for: indexPath) as! SwitchTableViewCell
            cell.onTapSwitch = {_ in }
            cell.theSwitch.isOn = self.showReadingTimes
            cell.onTapSwitch = {aSwitch in
                self.showReadingTimes = aSwitch.isOn
                self.navigationItem.rightBarButtonItem?.isEnabled = true
            }
            tableCell = cell
        case .exportOPML:
            let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            tableCell = cell
        case .gitVersion:
            let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            tableCell = cell

            cell.detailTextLabel?.text = Bundle.main.infoDictionary?["CurrentGitVersion"] as? String
        }
        tableCell.textLabel?.text = row.description
        return tableCell
    }

    private func creditCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        if indexPath.row == 0 {
            cell.textLabel?.text = NSLocalizedString("SettingsViewController_Credits_MainDeveloper_Name", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("SettingsViewController_Credits_MainDeveloper_Detail",
                                                           comment: "")
        } else if indexPath.row == 1 {
            cell.textLabel?.text = NSLocalizedString("SettingsViewController_Credits_Libraries", comment: "")
            cell.detailTextLabel?.text = ""
        } else if indexPath.row == 2 {
            cell.textLabel?.text = NSLocalizedString("SettingsViewController_Credits_Icons", comment: "")
            cell.detailTextLabel?.text = ""
        }
        return cell
    }
}

extension SettingsViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let section = SettingsSection(rawValue: indexPath.section) else { return }

        switch section {
        case .refresh:
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        default:
            break
        }
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { return false }

    @objc(tableView:commitEditingStyle:forRowAtIndexPath:)
    public func tableView(_ tableView: UITableView,
                          commit editingStyle: UITableViewCell.EditingStyle,
                          forRowAt indexPath: IndexPath) {}

    public func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath,
                          point: CGPoint) -> UIContextMenuConfiguration? {
        guard SettingsSection(rawValue: indexPath.section) == .credits else {
            return nil
        }
        return UIContextMenuConfiguration(
            identifier: indexPath as NSIndexPath,
            previewProvider: { [weak self] in
                if indexPath.row == 0 {
                    guard let url = URL(string: "https://twitter.com/younata") else { return nil }
                    return SFSafariViewController(url: url)
                } else if indexPath.row == 1 {
                    return self?.documentationViewController(.libraries)
                } else if indexPath.row == 2 {
                    return self?.documentationViewController(.icons)
                } else {
                    return nil
                }
            },
            actionProvider: { elements in
                return UIMenu(title: "", children: elements)
        })
    }

    public func tableView(_ tableView: UITableView,
                          willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                          animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion { [weak self] in
            guard let viewController = animator.previewViewController else { return }
            if viewController.isKind(of: SFSafariViewController.self) {
                let indexPath = IndexPath(row: SettingsSection.credits.rawValue, section: 0)
                viewController.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
                self?.present(viewController, animated: true, completion: nil)
            } else {
                self?.navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = SettingsSection(rawValue: indexPath.section) else { return }
        switch section {
        case .account:
            self.didTapAccountCell(indexPath: indexPath)
        case .refresh:
            self.didTapRefreshCell(indexPath: indexPath)
        case .other:
            self.didTapOtherCell(tableView: tableView, indexPath: indexPath)
        case .credits:
            self.didTapCreditCell(tableView: tableView, indexPath: indexPath)
        }
    }

    private func didTapAccountCell(indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        self.loginController.begin().then { result in
            switch result {
            case .success(let account):
                self.accounts.append(account)
                self.tableView.insertRows(at: [indexPath], with: .right)
            case .failure(.network(_, .cancelled)):
                break
            default:
                self.messenger.warning(
                    title: NSLocalizedString("SettingsViewController_Account_Error_Title", comment: ""),
                    message: NSLocalizedString("SettingsViewController_Account_Error_Message", comment: "")
                )
            }
        }
    }

    private func didTapRefreshCell(indexPath: IndexPath) {
        guard let refreshControlStyle = RefreshControlStyle(rawValue: indexPath.row) else { return }
        self.refreshControlStyle = refreshControlStyle
        self.navigationItem.rightBarButtonItem?.isEnabled = true
        self.reloadTable()
    }

    private func didTapOtherCell(tableView: UITableView, indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard let otherSection = OtherSection(rawValue: indexPath.row) else { return }

        switch otherSection {
        case .exportOPML:
            _ = self.opmlService.writeOPML().then {
                switch $0 {
                case let .success(url):
                    self.mainQueue.addOperation {
                        let shareSheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        shareSheet.popoverPresentationController?.sourceView = tableView
                        shareSheet.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)
                        self.present(shareSheet, animated: true, completion: nil)
                    }
                case .failure:
                    self.mainQueue.addOperation {
                        let alertTitle = NSLocalizedString("SettingsViewController_Other_ExportOPML_Error_Title",
                                                           comment: "")
                        let alertMsg = NSLocalizedString("SettingsViewController_Other_ExportOPML_Error_Message",
                                                         comment: "")
                        let alert = UIAlertController(title: alertTitle,
                                                      message: alertMsg,
                                                      preferredStyle: .alert)
                        let dismissTitle = NSLocalizedString("Generic_Ok", comment: "")
                        alert.addAction(UIAlertAction(title: dismissTitle, style: .default) { _ in
                            self.dismiss(animated: true, completion: nil)
                        })
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        default:
            break
        }
    }

    private func didTapCreditCell(tableView: UITableView, indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if indexPath.row == 0 {
            guard let url = URL(string: "https://twitter.com/younata") else { return }
            let viewController = SFSafariViewController(url: url)
            viewController.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
            self.present(viewController, animated: true, completion: nil)
        } else if indexPath.row == 1 {
            let viewController = self.documentationViewController(.libraries)
            self.navigationController?.pushViewController(viewController, animated: true)
        } else if indexPath.row == 2 {
            let viewController = self.documentationViewController(.icons)
            self.navigationController?.pushViewController(viewController, animated: true)
        }
    }
}
