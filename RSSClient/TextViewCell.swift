import UIKit

public class TextViewCell: UITableViewCell, UITextViewDelegate {

    public let textView = UITextView(forAutoLayout: ())

    var onTextChange: (String?) -> Void = {(_) in }

    var placeholderText = ""

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(textView)
        textView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        textView.scrollEnabled = false
        textView.delegate = self
        textView.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
    }

    public required init(coder: NSCoder) {
        fatalError("")
    }

    // MARK: UITextViewDelegate

    public func textViewDidChange(textView: UITextView) {
        self.onTextChange(textView.text)
    }

    public func textViewDidBeginEditing(textView: UITextView) {
        if textView.textColor != UIColor.blackColor() {
            textView.textColor = UIColor.blackColor()
            placeholderText = textView.text
            textView.text = ""
        }
    }

    public func textViewDidEndEditing(textView: UITextView) {
        if textView.text == nil || textView.text == "" {
            textView.textColor = UIColor.grayColor()
            textView.text = placeholderText
        }
    }
}
