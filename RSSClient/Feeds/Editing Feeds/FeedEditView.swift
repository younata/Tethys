import UIKit

public protocol FeedEditViewDelegate: class {
    func feedEditView(_ feedEditView: FeedEditView, urlDidChange url: URL)
    func feedEditView(_ feedEditView: FeedEditView, tagsDidChange tags: [String])
    func feedEditView(_ feedEditView: FeedEditView, editTag tag: String?, completion: @escaping (String) -> (Void))
}

public final class FeedEditView: UIView {
    let mainStackView = UIStackView(forAutoLayout: ())

    let titleLabel = UILabel(forAutoLayout: ())
    let urlField = UITextField(forAutoLayout: ())
    let summaryLabel = UILabel(forAutoLayout: ())
    let tagsList = UITableView(forAutoLayout: ())
    let addTagButton = UIButton(type: .system)

    fileprivate var tags: [String] = []

    weak var delegate: FeedEditViewDelegate?
    weak var themeRepository: ThemeRepository? {
        didSet {
            themeRepository?.addSubscriber(self)
        }
    }

    public func configure(title: String, url: URL, summary: String, tags: [String]) {
        self.titleLabel.text = title
        self.summaryLabel.text = summary

        let delegate = self.delegate
        self.delegate = nil
        self.urlField.text = url.absoluteString
        self.delegate = delegate

        self.tags = tags
        self.tagsList.reloadData()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(mainStackView)

        self.mainStackView.autoAlignAxis(.horizontal, toSameAxisOf: self, withOffset: 54)
        self.mainStackView.autoPinEdge(toSuperviewEdge: .leading)
        self.mainStackView.autoPinEdge(toSuperviewEdge: .trailing)
        self.mainStackView.autoPinEdge(toSuperviewEdge: .top, withInset: 84, relation: .greaterThanOrEqual)
        self.mainStackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 20, relation: .greaterThanOrEqual)

        self.mainStackView.addArrangedSubview(self.titleLabel)
        self.mainStackView.addArrangedSubview(self.urlField)
        self.mainStackView.addArrangedSubview(self.summaryLabel)
        self.mainStackView.addArrangedSubview(self.tagsList)
        self.mainStackView.addArrangedSubview(self.addTagButton)

        self.urlField.delegate = self
        self.tagsList.delegate = self
        self.tagsList.dataSource = self

        self.tagsList.register(TableViewCell.self, forCellReuseIdentifier: "cell")

        self.addTagButton.setTitle(NSLocalizedString("FeedViewController_Actions_AddTag", comment: ""), for: .normal)
        self.addTagButton.addTarget(self, action: #selector(FeedEditView.didTapAddTarget), for: .touchUpInside)
        self.addTagButton.setTitleColor(UIColor.darkGreen(), for: .normal)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func didTapAddTarget() {
        self.delegate?.feedEditView(self, editTag: nil) { newTag in
            self.tags.append(newTag)
            let indexPath = IndexPath(row: self.tags.count - 1, section: 0)
            self.tagsList.insertRows(at: [indexPath], with: .automatic)
            self.delegate?.feedEditView(self, tagsDidChange: self.tags)
        }
    }
}

extension FeedEditView: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.backgroundColor = themeRepository.backgroundColor

        self.tagsList.backgroundColor = themeRepository.backgroundColor
        self.tagsList.separatorColor = themeRepository.textColor
        self.tagsList.indicatorStyle = themeRepository.scrollIndicatorStyle

        self.titleLabel.textColor = themeRepository.textColor
        self.urlField.textColor = themeRepository.textColor
        self.summaryLabel.textColor = themeRepository.textColor
    }
}

extension FeedEditView: UITextFieldDelegate {
    public func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        let text = NSString(string: textField.text ?? "").replacingCharacters(in: range, with: string)
        if let url = URL(string: text), let _ = url.scheme {
            self.delegate?.feedEditView(self, urlDidChange: url)
        }
        return true
    }
}

extension FeedEditView: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tags.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        cell.textLabel?.text = self.tags[indexPath.row]
        return cell
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle,
                          forRowAt indexPath: IndexPath) {}
}

extension FeedEditView: UITableViewDelegate {
    public func tableView(_ tableView: UITableView,
                          editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UITableViewRowAction(style: .default, title: deleteTitle, handler: {(_, indexPath) in
            self.tags.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.delegate?.feedEditView(self, tagsDidChange: self.tags)
        })
        let editTitle = NSLocalizedString("Generic_Edit", comment: "")
        let edit = UITableViewRowAction(style: .normal, title: editTitle, handler: {(_, indexPath) in
            let tag = self.tags[indexPath.row]

            self.delegate?.feedEditView(self, editTag: tag) { newTag in
                self.tags[indexPath.row] = newTag
                tableView.reloadRows(at: [indexPath], with: .automatic)
                self.delegate?.feedEditView(self, tagsDidChange: self.tags)
            }
        })
        return [delete, edit]
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        let tag = self.tags[indexPath.row]

        self.delegate?.feedEditView(self, editTag: tag) { newTag in
            self.tags[indexPath.row] = newTag
            tableView.reloadRows(at: [indexPath], with: .automatic)
            self.delegate?.feedEditView(self, tagsDidChange: self.tags)
        }
    }
}
