import UIKit

class EnclosuresViewController: UIViewController {

    var enclosures: [CoreDataEnclosure]? = nil {
        didSet {
            enclosuresView.enclosures = enclosures
        }
    }

    var dataManager: DataManager? = nil {
        didSet {
            enclosuresView.dataManager = dataManager;
        }
    }

    let enclosuresView = EnclosuresView(frame: CGRectZero)

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("Enclosures", comment: "")
        let dismiss = NSLocalizedString("Dismiss", comment: "")
        let dismissButton = UIBarButtonItem(title: dismiss, style: .Plain, target: self, action: "dismiss")
        self.navigationItem.leftBarButtonItem = dismissButton

        enclosuresView.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.view.addSubview(enclosuresView)
        enclosuresView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(8, 8, 8, 8))

        enclosuresView.openEnclosure = {(enclosure) in
            let vc = UIViewController()
            let webView = UIWebView()

            vc.view.addSubview(webView)
            webView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
            webView.loadData(enclosure.data, MIMEType: enclosure.kind, textEncodingName: "UTF-8",
                baseURL: NSURL(string: enclosure.url ?? ""))

            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func dismiss() {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
}
