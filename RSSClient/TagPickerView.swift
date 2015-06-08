import UIKit
import PureLayout_iOS

public class TagPickerView: UIView, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate {
    public lazy var textField: UITextField = {
        let textField = UITextField(forAutoLayout: ())
        textField.delegate = self
        textField.placeholder = NSLocalizedString("Tag", comment: "")
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

    public func configureWithTags(tags: [String], onSelect: (String) -> Void) {
        allTags = tags
        didSelect = onSelect

        picker.reloadComponent(0)
        textFieldDidChange("")
    }

    // MARK: - UIPickerView protocols

    public func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }

    public func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return existingSolutions.count
    }

    public func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return existingSolutions[row] ?? ""
    }

    public func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row < existingSolutions.count {
            let solution = existingSolutions[row]
            textField.text = solution
            textFieldDidChange(solution)
        }
    }

    // Mark: - UITextFieldDelegate

    public func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange,
        replacementString string: String) -> Bool {
            let text = (textField.text as NSString).stringByReplacingCharactersInRange(range, withString: string)
            return textFieldDidChange(text)
    }

    // Mark: - Private

    private func textFieldDidChange(text: String) -> Bool {
        let solutions: [String]
        if text.isEmpty {
            solutions = allTags
        } else {
            solutions = allTags.filter {
                return $0.rangeOfString(text) != nil
            }
            didSelect(text)
        }
        existingSolutions = solutions
        return true
    }
}
