import rNewsKit

public class AuthorActivity: UIActivity {
    private let author: Author

    public init(author: Author) {
        self.author = author
        super.init()
    }

    public override func activityType() -> String? {
        return "com.rachelbrindle.rnews.author"
    }

    public override func activityTitle() -> String? {
        let formatString = NSLocalizedString("AuthorActivity_Title", comment: "")
        return String.localizedStringWithFormat(formatString, self.author.name)
    }

    public override func activityImage() -> UIImage? {
        return UIImage(named: "GrayIcon")
    }

    public override func canPerformWithActivityItems(activityItems: [AnyObject]) -> Bool {
        return true
    }

    public override func performActivity() {
        self.activityDidFinish(true)
    }
}
