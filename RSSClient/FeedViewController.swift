//
//  FeedViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/2/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class FeedViewController: UITableViewController {
    
    var feed : Feed? = nil {
        didSet {
            self.navigationItem.title = self.feed?.feedTitle() ?? ""
            self.tableView.reloadData()
        }
    }
    
    lazy var dataManager : DataManager = { self.injector!.create(DataManager.self) as DataManager }()
    
    let intervalFormatter = NSDateIntervalFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Save", comment: ""), style: .Plain, target: self, action: "save")
        self.navigationItem.title = self.feed?.feedTitle() ?? ""

        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.registerClass(TextFieldCell.self, forCellReuseIdentifier: "text")
        tableView.tableFooterView = UIView()
        
        intervalFormatter.calendar = NSCalendar.currentCalendar()
        intervalFormatter.dateStyle = .MediumStyle
        intervalFormatter.timeStyle = .ShortStyle
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func save() {
        feed?.managedObjectContext?.save(nil)
        dataManager.writeOPML()
        dismiss()
    }
    
    func showTagEditor(tagIndex: Int) -> TagEditorViewController {
        let tagEditor = self.injector!.create(TagEditorViewController.self) as TagEditorViewController
        tagEditor.feed = feed
        if tagIndex < feed?.allTags().count {
            tagEditor.tagIndex = tagIndex
            tagEditor.tagPicker.textField.text = feed?.allTags()[tagIndex]
        }
        self.navigationController?.pushViewController(tagEditor, animated: true)
        return tagEditor
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        #if DEBUG
        let numSection = 5
        #else
        let numSection = 4
        #endif
        return (feed == nil ? 0 : numSection)
    }
    
    let tagSection = 3

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if feed == nil {
            return 0
        }
        if section == tagSection { // tags
            return feed!.allTags().count + 1
        }
        return 1
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("Title", comment: "")
        case 1:
            return NSLocalizedString("URL", comment: "")
        case 2:
            return NSLocalizedString("Summary", comment: "")
        case tagSection:
            return NSLocalizedString("Tags", comment: "")
        case 4:
            return NSLocalizedString("Next Expected Update", comment: "")
        default:
            return nil
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as UITableViewCell
        
        cell.textLabel?.textColor = UIColor.blackColor()
        cell.textLabel?.text = ""

        switch (indexPath.section) {
        case 0:
            if let title = (feed?.feedTitle() == "" ? nil : feed?.feedTitle()) {
                cell.textLabel?.text = title
            } else {
                cell.textLabel?.text = NSLocalizedString("No title available", comment: "")
                cell.textLabel?.textColor = UIColor.grayColor()
            }
        case 1:
            let tc = tableView.dequeueReusableCellWithIdentifier("text", forIndexPath: indexPath) as TextFieldCell
            tc.onTextChange = {(_) in } // remove any previous onTextChange for setting stuff here.
            tc.textField.text = feed?.url
            tc.showValidator = true
            tc.onTextChange = {(text) in
                if let txt = text {
                    request(.GET, txt).responseString {(_, _, str, error) in
                        if let err = error {
                            tc.setValid(false)
                        } else if let s = str {
                            let fp = FeedParser(string: s)
                            fp.failure {(_) in tc.setValid(false)}
                            fp.success {(_) in tc.setValid(true)}
                        }
                    }
                }
                return
            }
            return tc
        case 2:
            if let summary = (feed?.feedSummary() == "" ? nil : feed?.feedSummary())  {
                cell.textLabel?.text = summary
            } else {
                cell.textLabel?.text = NSLocalizedString("No summary available", comment: "")
                cell.textLabel?.textColor = UIColor.grayColor()
            }
        case tagSection:
            if let tags = feed?.allTags() {
                if indexPath.row == tags.count {
                    cell.textLabel?.text = NSLocalizedString("Add Tag", comment: "")
                    cell.textLabel?.textColor = UIColor.darkGreenColor()
                } else {
                    cell.textLabel?.text = tags[indexPath.row]
                }
            }
        case 4:
            if let f = feed {
                let (date, stdev) = FeedStatistics().estimateNextFeedTime(f)
                if let d = date {
                    let start = d.dateByAddingTimeInterval(-stdev)
                    let end = d.dateByAddingTimeInterval(stdev)
                    cell.textLabel?.text = intervalFormatter.stringFromDate(start, toDate: end)
                } else {
                    cell.textLabel?.text = NSLocalizedString("Unknown", comment: "")
                }
            }
            cell.textLabel?.numberOfLines = 0
        default:
            break
        }

        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return indexPath.section == tagSection && indexPath.row != (tableView.numberOfRowsInSection(2) - 1)
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        if feed == nil {
            return nil
        }
        if indexPath.section != tagSection {
            return nil
        }
        if feed!.allTags().count == indexPath.row {
            return nil
        }
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
            print("")
            self.showTagEditor(indexPath.row)
        })
        return [delete, edit]
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        
        if indexPath.section == tagSection {
            if let count = feed?.allTags().count {
                if indexPath.row == count {
                    showTagEditor(indexPath.row)
                }
            }
        }
    }
}
