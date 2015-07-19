import UIKit
import SyntaxKit

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

    private lazy var attributedParser: AttributedParser? = {
        let bundle = NSBundle(forClass: self.classForCoder)
        if let languagePath = bundle.pathForResource("JavaScript", ofType: "tmLanguage"),
            let languagePlist = NSDictionary(contentsOfFile: languagePath) as? [NSObject: AnyObject],
            let language = Language(dictionary: languagePlist),
            let themePath = bundle.pathForResource("mac_classic", ofType: "tmTheme"),
            let themePlist = NSDictionary(contentsOfFile: themePath) as? [NSObject: AnyObject],
            let theme = Theme(dictionary: themePlist) {
                return AttributedParser(language: language, theme: theme)
        }
        return nil
    }()

    public var onTextChange: (String?) -> Void = {(_) in }

    internal func applyStyling() {
        if let parser = attributedParser {
            textView.delegate = nil
            let selection = textView.selectedRange
            let baseAttributes: [String: AnyObject]?
            if let font = UIFont(name: "Menlo-Regular", size: 14) {
                baseAttributes = [NSFontAttributeName: font]
            } else {
                baseAttributes = nil
            }
            textView.attributedText = parser.attributedStringForString(textView.text, baseAttributes: baseAttributes)
            textView.selectedRange = selection
            textView.delegate = self
        }
    }

    // MARK: UITextViewDelegate

    public func textViewDidChange(textView: UITextView) {
        applyStyling()
        self.onTextChange(textView.text)
    }
}
