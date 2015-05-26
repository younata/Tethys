import UIKit

class TextViewCell: UITableViewCell, UITextViewDelegate {

    let textView = UITextView(forAutoLayout: ())

    var onTextChange: (String?) -> Void = {(_) in }

    var placeholderText = ""

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(textView)
        textView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        textView.scrollEnabled = false
        textView.delegate = self
        textView.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
    }

    required init(coder: NSCoder) {
        fatalError("")
    }

    // MARK: UITextViewDelegate

    func textViewDidChange(textView: UITextView) {
        self.onTextChange(textView.text)
    }

    func textViewDidBeginEditing(textView: UITextView) {
        if textView.textColor != UIColor.blackColor() {
            textView.textColor = UIColor.blackColor()
            placeholderText = textView.text
            textView.text = ""
        }
    }

    func textViewDidEndEditing(textView: UITextView) {
        if textView.text == nil || textView.text == "" {
            textView.textColor = UIColor.grayColor()
            textView.text = placeholderText
        }
    }
}
