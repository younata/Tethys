class URLShareSheet: UIActivityViewController {
    let url: URL
    let themeRepository: ThemeRepository

    private let labelWrapper = UIView(forAutoLayout: ())
    private let label = UILabel(forAutoLayout: ())

    init(url: URL, themeRepository: ThemeRepository, activityItems: [Any], applicationActivities: [UIActivity]?) {
        self.url = url
        self.themeRepository = themeRepository

        super.init(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.view.addSubview(self.labelWrapper)
        self.labelWrapper.autoPinEdge(.bottom, to: .top, of: self.view, withOffset: -20)
        self.labelWrapper.autoPinEdge(toSuperviewEdge: .leading)
        self.labelWrapper.autoPinEdge(toSuperviewEdge: .trailing)
        self.labelWrapper.backgroundColor = self.themeRepository.textColor
        self.labelWrapper.layer.cornerRadius = 10

        self.labelWrapper.addSubview(self.label)
        self.label.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))

        self.label.numberOfLines = 0
        self.label.textColor = self.themeRepository.backgroundColor
        self.label.text = self.url.absoluteString

        self.view.layer.masksToBounds = false
        self.view.clipsToBounds = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        UIView.animate(withDuration: 0.25) {
            self.labelWrapper.alpha = 0
        }

        self.labelWrapper.removeFromSuperview()
    }
}
