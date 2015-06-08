import UIKit

public class TextViewCell: UITableViewCell, UITextViewDelegate {

    public lazy var textView: UITextView = {
        let textView = UITextView(forAutoLayout: ())
        textView.scrollEnabled = false
        textView.delegate = self
        textView.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)

        self.contentView.addSubview(textView)
        textView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        return textView
    }()

    public var onTextChange: (String?) -> Void = {(_) in }

    // MARK: UITextViewDelegate

    public func textViewDidChange(textView: UITextView) {
        self.onTextChange(textView.text)
    }
}
