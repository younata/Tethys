import UIKit
import SyntaxKit

public class TextViewCell: UITableViewCell {
    public lazy var textView: UITextView = {
        let textView = UITextView(forAutoLayout: ())
        textView.scrollEnabled = false
        textView.delegate = self
        textView.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)

        self.contentView.addSubview(textView)
        textView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
        return textView
    }()

    private lazy var attributedParser: AttributedParser? = {
        return self.reloadParser()
    }()

    public var onTextChange: ((String?) -> Void)? = nil

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    private func reloadParser() -> AttributedParser? {
        let bundle = NSBundle(forClass: self.classForCoder)
        let themeFileName = self.themeRepository?.syntaxHighlightFile ?? "mac_classic"
        if let languagePath = bundle.pathForResource("JavaScript", ofType: "tmLanguage"),
            languagePlist = NSDictionary(contentsOfFile: languagePath) as? [NSObject: AnyObject],
            language = Language(dictionary: languagePlist),
            themePath = bundle.pathForResource(themeFileName, ofType: "tmTheme"),
            themePlist = NSDictionary(contentsOfFile: themePath) as? [NSObject: AnyObject],
            theme = SyntaxKit.Theme(dictionary: themePlist) {
                return AttributedParser(language: language, theme: theme)
        }
        return nil
    }

    internal func applyStyling() {
        if let parser = self.attributedParser {
            self.textView.delegate = nil
            let selection = textView.selectedRange
            let baseAttributes: [String: AnyObject]?
            let textColor = self.themeRepository?.textColor ?? UIColor.blackColor()
            let pointSize = UIFont.preferredFontForTextStyle(UIFontTextStyleBody).pointSize
            if let font = UIFont(name: "Menlo-Regular", size: pointSize) {
                baseAttributes = [NSFontAttributeName: font, NSForegroundColorAttributeName: textColor]
            } else {
                baseAttributes = nil
            }
            self.textView.attributedText = parser.attributedStringForString(textView.text,
                baseAttributes: baseAttributes)
            self.textView.selectedRange = selection
            self.textView.delegate = self
        }
    }
}

extension TextViewCell: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.backgroundColor = self.themeRepository?.backgroundColor
        self.textView.backgroundColor = self.themeRepository?.backgroundColor
        self.textView.textColor = self.themeRepository?.textColor

        self.attributedParser = self.reloadParser()

        let oldOnTextChange = self.onTextChange
        self.onTextChange = {_ in}
        self.applyStyling()
        self.onTextChange = oldOnTextChange
    }
}

extension TextViewCell: UITextViewDelegate {
    public func textViewDidChange(textView: UITextView) {
        self.applyStyling()
        self.onTextChange?(textView.text)
    }
}
