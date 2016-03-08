public class AuthorActivity: UIActivity {
    private let author: String

    public init(author: String) {
        self.author = author
        super.init()
    }

    public override func activityType() -> String? {
        return "com.rachelbrindle.rnews.author"
    }

    public override func activityTitle() -> String? {
        return String.localizedStringWithFormat(NSLocalizedString("AuthorActivity_Title", comment: ""), self.author)
    }

    public override func activityImage() -> UIImage? {
        return UIImage(named: "Podcast")
    }

    public override func canPerformWithActivityItems(activityItems: [AnyObject]) -> Bool {
        return true
    }

    public override func performActivity() {
        self.activityDidFinish(true)
    }
}
