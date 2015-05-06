//
//  QueryFeedViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/3/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class QueryFeedViewController: UITableViewController {
    
    var feed : Feed? = nil {
        didSet {
            self.navigationItem.title = self.feed?.feedTitle() ?? NSLocalizedString("New Query Feed", comment: "")
            self.tableView.reloadData()
            if feed?.query == nil {
                feed?.query = "function(article) {\n    return !article.read;\n}"
            }
        }
    }
    
    lazy var dataManager : DataManager = { self.injector!.create(DataManager.self) as! DataManager }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .Plain, target: self, action: "dismiss")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Save", comment: ""), style: .Plain, target: self, action: "save")
        self.navigationItem.title = self.feed?.feedTitle() ?? NSLocalizedString("New Query Feed", comment: "")
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "tags")
        tableView.registerClass(TextViewCell.self, forCellReuseIdentifier: "cell")
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 64
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    func dismiss() {
        if let feed = self.feed {
            if feed.title == nil && feed.query == nil {
                dataManager.deleteFeed(feed)
            }
        }
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func save() {
        if let feed = self.feed {
            if feed.title == nil && feed.query == nil {
                dataManager.deleteFeed(feed)
            }
            feed.managedObjectContext?.save(nil)
        }
        dataManager.writeOPML()
        dismiss()
    }
    
    func showTagEditor(tagIndex: Int) {
        let tagEditor = self.injector!.create(TagEditorViewController.self) as! TagEditorViewController
        tagEditor.feed = feed
        if tagIndex < feed?.allTags().count {
            tagEditor.tagIndex = tagIndex
            tagEditor.tagPicker.textField.text = feed?.allTags()[tagIndex]
        }
        self.navigationController?.pushViewController(tagEditor, animated: true)
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return feed == nil ? 3 : 4
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section != 3 {
            return 1
        }
        return (feed?.allTags().count ?? 0) + 1
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("Title", comment: "")
        case 1:
            return NSLocalizedString("Summary", comment: "")
        case 2:
            return NSLocalizedString("Query", comment: "")
        case 3:
            return NSLocalizedString("Tags", comment: "")
        default:
            return nil
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 3 {
            let cell = tableView.dequeueReusableCellWithIdentifier("tags", forIndexPath: indexPath) as! UITableViewCell
            if let tags = feed?.allTags() {
                if indexPath.row == tags.count {
                    cell.textLabel?.text = NSLocalizedString("Add Tag", comment: "")
                    cell.textLabel?.textColor = UIColor.darkGreenColor()
                } else {
                    cell.textLabel?.text = tags[indexPath.row]
                }
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TextViewCell
            cell.textView.textColor = UIColor.blackColor()
            switch (indexPath.section) {
            case 0:
                if let title = (feed?.feedTitle() == "" ? nil : feed?.feedTitle()) {
                    cell.textView.text = title
                } else {
                    cell.textView.text = NSLocalizedString("No title available", comment: "")
                    cell.textView.textColor = UIColor.grayColor()
                }
                cell.onTextChange = {
                    if let feed = self.feed {
                        feed.title = $0
                    }
                    self.navigationItem.rightBarButtonItem?.enabled = self.feed?.title != nil && self.feed?.query != nil
                }
            case 1:
                if let summary = (feed?.feedSummary() == "" ? nil : feed?.feedSummary())  {
                    cell.textView.text = summary
                } else {
                    cell.textView.text = NSLocalizedString("No summary available", comment: "")
                    cell.textView.textColor = UIColor.grayColor()
                }
                cell.onTextChange = {
                    if let feed = self.feed {
                        feed.summary = $0
                    }
                }
            case 2:
                if let query = feed?.query {
                    cell.textView.text = query
                } else {
                    cell.textView.text = "function(article) {\n    return !article.read;\n}"
                }
                cell.onTextChange = {
                    if let feed = self.feed {
                        feed.query = $0
                    }
                    self.navigationItem.rightBarButtonItem?.enabled = self.feed?.title != nil && self.feed?.query != nil
                }
            default:
                break
            }
            return cell
        }
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if indexPath.section == 3 {
            return indexPath.row < (feed?.allTags().count ?? 1)
        } else if indexPath.section == 2 {
            return true
        }
        return false
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        if feed == nil {
            return nil
        }
        if indexPath.section < 2 {
            return nil
        }
        if feed!.allTags().count == indexPath.row {
            return nil
        }
        if indexPath.section == 2 {
            let preview = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Preview", comment: ""), handler: {(_, _) in
                let articleList = ArticleListController(style: .Plain)
                articleList.previewMode = true
                articleList.articles = self.dataManager.articlesMatchingQuery(self.feed?.query ?? "")
                self.navigationController?.pushViewController(articleList, animated: true)
            })
            return [preview]
        } else if indexPath.section == 3 {
            let delete = UITableViewRowAction(style: .Default, title: NSLocalizedString("Delete", comment: ""), handler: {(_, indexPath) in
                if let feed = self.feed {
                    var tags = feed.allTags()
                    let tag = tags[indexPath.row]
                    tags.removeAtIndex(indexPath.row)
                    feed.tags = tags
                    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                    if tag.hasPrefix("~") {
                        tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .None)
                    } else if tag.hasPrefix("`") {
                        tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 1)], withRowAnimation: .None)
                    }
                }
            })
            let edit = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Edit", comment: ""), handler: {(_, indexPath) in
                self.showTagEditor(indexPath.row)
            })
            return [delete, edit]
        }
        return nil
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        
        if indexPath.section == 3,
            let count = feed?.allTags().count where indexPath.row == count {
                showTagEditor(indexPath.row)
        }
    }
}
