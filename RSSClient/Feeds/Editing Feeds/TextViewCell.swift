import UIKit
import SyntaxKit

public class TextViewCell: UITableViewCell {
    public lazy var textView: UITextView = {
        let textView = UITextView(forAutoLayout: ())
        textView.isScrollEnabled = false
        textView.delegate = self
        textView.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)

        self.contentView.addSubview(textView)
        textView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
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

    fileprivate func reloadParser() -> AttributedParser? {
        let bundle = Bundle(for: self.classForCoder)
        let themeFileName = self.themeRepository?.syntaxHighlightFile ?? "mac_classic"
        if let languagePath = bundle.path(forResource: "JavaScript", ofType: "tmLanguage"),
            let languagePlist = NSDictionary(contentsOfFile: languagePath) as? [NSObject: AnyObject],
            let language = Language(dictionary: languagePlist),
            let themePath = bundle.path(forResource: themeFileName, ofType: "tmTheme"),
            let themePlist = NSDictionary(contentsOfFile: themePath) as? [NSObject: AnyObject],
            let theme = SyntaxKit.Theme(dictionary: themePlist) {
                return AttributedParser(language: language, theme: theme)
        }
        return nil
    }

    internal func applyStyling() {
        if let parser = self.attributedParser {
            self.textView.delegate = nil
            let selection = textView.selectedRange
            let baseAttributes: [String: AnyObject]?
            let textColor = self.themeRepository?.textColor ?? UIColor.black
            let pointSize = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body).pointSize
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
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
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
    public func textViewDidChange(_ textView: UITextView) {
        self.applyStyling()
        self.onTextChange?(textView.text)
    }
}
