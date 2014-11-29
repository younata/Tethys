//
//  QueryFeedViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class QueryFeedViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    
    let scrollView = UIScrollView(forAutoLayout: ())
    
    let titleField = UITextField(forAutoLayout: ())
    let summaryField = UITextView(forAutoLayout: ())
    let queryField = UITextView(forAutoLayout: ())
    
    var scrollBottomConstraint : NSLayoutConstraint? = nil
    
    var summaryHeight : NSLayoutConstraint? = nil
    var queryHeight : NSLayoutConstraint? = nil
    
    var feed : Feed? = nil {
        didSet {
            titleField.text = feed?.title ?? ""
            summaryField.text = feed?.summary ?? ""
            queryField.text = feed?.query ?? ""
        }
    }
    var dataManager : DataManager? = nil
    
    let testButton : UIButton = UIButton.buttonWithType(.System) as UIButton

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = .None
        /*
        self.view.addSubview(scrollView)
        scrollView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        scrollBottomConstraint = scrollView.autoPinEdgeToSuperviewEdge(.Bottom)
        scrollView.contentSize = self.view.bounds.size
        scrollView.backgroundColor = UIColor.clearColor()*/
        
        //let view = scrollView
        
        let label = UITextView(forAutoLayout: ())
        view.addSubview(label)
        label.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(8, 8, 0, 8), excludingEdge: .Bottom)
        label.autoSetDimension(.Height, toSize: 64, relation: .GreaterThanOrEqual)
        label.scrollEnabled = false
        label.editable = false
        label.attributedText = NSAttributedString(data: NSData(contentsOfURL: NSBundle.mainBundle().URLForResource("aboutQueryFeeds", withExtension: "html")!)!, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType], documentAttributes: nil, error: nil)
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        
        view.addSubview(titleField)
        titleField.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        titleField.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        titleField.autoPinEdge(.Top, toEdge: .Bottom, ofView: label, withOffset: 8)
        titleField.autoSetDimension(.Height, toSize: 32)
        
        titleField.delegate = self
        titleField.placeholder = NSLocalizedString("All Unread", comment: "")
        titleField.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        titleField.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        titleField.layer.cornerRadius = 5
        
        view.addSubview(summaryField)
        summaryField.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        summaryField.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        summaryField.autoPinEdge(.Top, toEdge: .Bottom, ofView: titleField, withOffset: 8)
        summaryHeight = summaryField.autoSetDimension(.Height, toSize: 32)
        
        summaryField.delegate = self
        summaryField.text = feed?.summary ?? NSLocalizedString("Feeds with unread articles", comment: "")
        summaryField.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        summaryField.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        summaryField.layer.cornerRadius = 5
        self.textViewDidChange(summaryField)
        
        view.addSubview(queryField)
        queryField.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        queryField.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        queryField.autoPinEdge(.Top, toEdge: .Bottom, ofView: summaryField, withOffset: 8)
        queryHeight = queryField.autoSetDimension(.Height, toSize: 32)
        
        queryField.delegate = self
        queryField.text = feed?.query ?? "function(article) {\n    return !article.read;\n}"
        queryField.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        queryField.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        queryField.layer.cornerRadius = 5
        self.textViewDidChange(queryField)
        
        view.addSubview(testButton)
        testButton.setTranslatesAutoresizingMaskIntoConstraints(false)
        testButton.autoAlignAxisToSuperviewAxis(.Vertical)
        testButton.autoSetDimension(.Height, toSize: 32)
        testButton.autoPinEdge(.Top, toEdge: .Bottom, ofView: queryField, withOffset: 8)
        
        testButton.setTitle(NSLocalizedString("Preview Query", comment: ""), forState: .Normal)
        testButton.setTitleColor(UIColor.darkGreenColor(), forState: .Normal)
        testButton.setTitleColor(UIColor.grayColor(), forState: .Disabled)
        testButton.addTarget(self, action: "test", forControlEvents: .TouchUpInside)
        testButton.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        testButton.layer.cornerRadius = 5
        testButton.enabled = queryField.text != ""
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Save", comment: ""), style: .Plain, target: self, action: "save")
        self.navigationItem.rightBarButtonItem!.enabled = feed != nil
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func save() {
        let loading = LoadingView(frame: self.view.bounds)
        self.view.addSubview(loading)
        loading.msg = NSLocalizedString("Creating Query Feed", comment: "")
        dispatch_async(dispatch_get_main_queue()) {
            if let f = self.feed {
                f.title = self.titleField.text
                f.query = self.queryField.text
                f.managedObjectContext?.save(nil)
            } else if let dm = self.dataManager {
                dm.newQueryFeed(self.titleField.text, code: self.queryField.text, summary: self.summaryField.text)
            } else {
                println("feed is nil and so is datamanager")
            }
            loading.removeFromSuperview()
            self.dismiss()
        }
    }
    
    func getKeyboardHeight(note: NSNotification) -> CGFloat {
        let info = note.userInfo!
        let value = info[UIKeyboardFrameBeginUserInfoKey as NSObject] as NSValue
        let beginRect = value.CGRectValue()
        return UIInterfaceOrientationIsLandscape(self.interfaceOrientation) ? CGRectGetWidth(beginRect) : CGRectGetHeight(beginRect)
    }
    
    func keyboardWillShow(note: NSNotification) {
        scrollBottomConstraint?.constant = -1 * getKeyboardHeight(note)
        self.view.setNeedsUpdateConstraints()
        let info = note.userInfo!
        let duration = info[UIKeyboardAnimationDurationUserInfoKey as NSObject] as Double
        UIView.animateWithDuration(duration, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    func keyboardWillHide(note: NSNotification) {
        scrollBottomConstraint?.constant = 0
        self.view.setNeedsUpdateConstraints()
        let info = note.userInfo!
        let duration = info[UIKeyboardAnimationDurationUserInfoKey as NSObject] as Double
        UIView.animateWithDuration(duration, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    func test() {
        let articleList = ArticleListController(style: .Plain)
        articleList.previewMode = true
        articleList.articles = dataManager!.articlesMatchingQuery(queryField.text)
        self.navigationController?.pushViewController(articleList, animated: true)
    }
    
    // MARK: UITextViewDelegate
    
    func textViewDidChange(textView: UITextView) {
        let text = (textView.text! as NSString)
        let width = self.view.bounds.size.width - 16 - (textView.textContainerInset.left + textView.textContainerInset.right)
        let h = fabs(textView.textContainerInset.top + textView.textContainerInset.bottom) + 5
        let bounds = text.boundingRectWithSize(CGSizeMake(width - 16, CGFloat.max), options: .UsesLineFragmentOrigin, attributes: [NSFontAttributeName: textView.font], context: nil)
        let height = max(ceil(CGRectGetHeight(bounds)) + h, 32)
        if textView == summaryField {
            summaryHeight?.constant = height
        } else if textView == queryField {
            queryHeight?.constant = height
            testButton.enabled = textView.text != ""
            self.navigationItem.rightBarButtonItem?.enabled = (titleField.text as NSString).length != 0 && (textView.text as NSString).length != 0
        }
        scrollView.setNeedsLayout()
    }
    
    // MARK: UITextFieldDelegate
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let text = (textField.text as NSString).stringByReplacingCharactersInRange(range, withString: string)
        self.navigationItem.rightBarButtonItem?.enabled = (text as NSString).length != 0 && (queryField.text as NSString).length != 0
        return true
    }
}
