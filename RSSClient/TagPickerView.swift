import UIKit
import PureLayout

public class TagPickerView: UIView {
    public lazy var textField: UITextField = {
        let textField = UITextField(forAutoLayout: ())
        textField.delegate = self
        textField.placeholder = NSLocalizedString("TagPickerView_Placeholder", comment: "")
        textField.backgroundColor = UIColor(white: 0.8, alpha: 0.75)
        textField.layer.cornerRadius = 5

        self.addSubview(textField)
        textField.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        textField.autoSetDimension(.Height, toSize: 40)
        return textField
    }()

    public lazy var picker: UIPickerView = {
        let picker = UIPickerView(forAutoLayout: ())
        picker.delegate = self
        picker.dataSource = self

        self.addSubview(picker)
        picker.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        picker.autoPinEdge(.Top, toEdge: .Bottom, ofView: self.textField)
        picker.autoSetDimension(.Height, toSize: 120)
        return picker
    }()

    private var allTags: [String] = []
    private var didSelect: (String) -> Void = {(_) in }
    private var existingSolutions: [String] = [] {
        didSet {
            self.picker.reloadComponent(0)
        }
    }

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    public func configureWithTags(tags: [String], onSelect: (String) -> Void) {
        self.allTags = tags
        self.didSelect = onSelect

        self.picker.reloadComponent(0)
        self.textFieldDidChange("")
    }

    private func textFieldDidChange(text: String) -> Bool {
        let solutions: [String]
        if text.isEmpty {
            solutions = self.allTags
        } else {
            solutions = self.allTags.filter {
                return $0.rangeOfString(text) != nil
            }
            self.didSelect(text)
        }
        self.existingSolutions = solutions
        return true
    }
}

extension TagPickerView: UIPickerViewDataSource, UIPickerViewDelegate {
    public func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }

    public func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.existingSolutions.count
    }

    public func pickerView(pickerView: UIPickerView,
        attributedTitleForRow row: Int,
        forComponent component: Int) -> NSAttributedString? {
            let textColor = self.themeRepository?.textColor ?? UIColor.blackColor()
            return NSAttributedString(string: self.existingSolutions[row],
                attributes: [NSForegroundColorAttributeName: textColor])
    }

    public func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row < self.existingSolutions.count {
            let solution = self.existingSolutions[row]
            self.textField.text = solution
            self.textFieldDidChange(solution)
        }
    }
}

extension TagPickerView: UITextFieldDelegate {
    public func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange,
        replacementString string: String) -> Bool {
            guard let text = textField.text else {
                return false
            }
            let replacedText = (text as NSString).stringByReplacingCharactersInRange(range, withString: string)
            return textFieldDidChange(replacedText)
    }
}

extension TagPickerView: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.picker.reloadComponent(0)
    }
}
