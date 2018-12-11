import UIKit
import PureLayout

public final class TagPickerView: UIView {
    public lazy var textField: UITextField = {
        let textField = UITextField(forAutoLayout: ())
        textField.delegate = self
        let placeholder = NSAttributedString(string: NSLocalizedString("TagPickerView_Placeholder", comment: ""),
                                             attributes: [NSAttributedString.Key.foregroundColor: UIColor.gray])
        textField.attributedPlaceholder = placeholder

        self.addSubview(textField)
        textField.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .bottom)
        textField.autoSetDimension(.height, toSize: 40)
        return textField
    }()

    public lazy var picker: UIPickerView = {
        let picker = UIPickerView(forAutoLayout: ())
        picker.delegate = self
        picker.dataSource = self

        self.addSubview(picker)
        picker.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        picker.autoPinEdge(.top, to: .bottom, of: self.textField)
        picker.autoSetDimension(.height, toSize: 120)
        return picker
    }()

    fileprivate var allTags: [String] = []
    fileprivate var didSelect: (String) -> Void = {(_) in }
    fileprivate var existingSolutions: [String] = [] {
        didSet {
            self.picker.reloadComponent(0)
        }
    }

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    public func configureWithTags(_ tags: [String], onSelect: @escaping (String) -> Void) {
        self.allTags = tags
        self.didSelect = onSelect

        self.picker.reloadComponent(0)
        _ = self.textFieldDidChange("")
    }

    fileprivate func textFieldDidChange(_ text: String) -> Bool {
        let solutions: [String]
        if text.isEmpty {
            solutions = self.allTags
        } else {
            solutions = self.allTags.filter {
                return $0.range(of: text) != nil
            }
            self.didSelect(text)
        }
        self.existingSolutions = solutions
        return true
    }
}

extension TagPickerView: UIPickerViewDataSource, UIPickerViewDelegate {
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.existingSolutions.count
    }

    public func pickerView(_ pickerView: UIPickerView,
                           attributedTitleForRow row: Int,
                           forComponent component: Int) -> NSAttributedString? {
        let textColor = self.themeRepository?.textColor ?? UIColor.black
        return NSAttributedString(string: self.existingSolutions[row],
                                  attributes: [NSAttributedString.Key.foregroundColor: textColor])
    }

    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row < self.existingSolutions.count {
            let solution = self.existingSolutions[row]
            self.textField.text = solution
            _ = self.textFieldDidChange(solution)
        }
    }
}

extension TagPickerView: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        guard let text = textField.text else {
            return false
        }
        let replacedText = (text as NSString).replacingCharacters(in: range, with: string)
        return textFieldDidChange(replacedText)
    }
}

extension TagPickerView: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.picker.reloadComponent(0)
    }
}
