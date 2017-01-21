import TethysKit

public final class AuthorActivity: UIActivity {
    private let author: Author

    public init(author: Author) {
        self.author = author
        super.init()
    }

    public override var activityType: UIActivityType? {
        return UIActivityType("com.rachelbrindle.Tethys.author")
    }

    public override var activityTitle: String? {
        let formatString = NSLocalizedString("AuthorActivity_Title", comment: "")
        return String.localizedStringWithFormat(formatString, self.author.name)
    }

    public override var activityImage: UIImage? {
        return UIImage(named: "GrayIcon")
    }

    public override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return true
    }

    public override func perform() {
        self.activityDidFinish(true)
    }
}
