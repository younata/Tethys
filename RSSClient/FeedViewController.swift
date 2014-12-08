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
    
    var dataManager: DataManager? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Save", comment: ""), style: .Plain, target: self, action: "save")
        self.navigationItem.title = self.feed?.feedTitle() ?? ""

        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.tableFooterView = UIView()
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
        dataManager?.writeOPML()
        dismiss()
    }
    
    func showTagEditor(tagIndex: Int) -> TagEditorViewController {
        let tagEditor = TagEditorViewController()
        tagEditor.feed = feed
        tagEditor.dataManager = dataManager
        if tagIndex < feed?.allTags().count {
            tagEditor.tagIndex = tagIndex
            tagEditor.tagPicker.textField.text = feed?.allTags()[tagIndex]
        }
        self.navigationController?.pushViewController(tagEditor, animated: true)
        return tagEditor
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return (feed == nil ? 0 : 3)
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if feed == nil {
            return 0
        }
        if section == 0 {
            return (feed?.feedTitle() == nil ? 0 : 1)
        }
        if section == 1 {
            return (feed?.feedSummary() == nil ? 0 : 1)
        }
        return feed!.allTags().count + 1
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("Title", comment: "")
        case 1:
            return NSLocalizedString("Summary", comment: "")
        case 2:
            return NSLocalizedString("Tags", comment: "")
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
            if let summary = (feed?.feedSummary() == "" ? nil : feed?.feedSummary())  {
                cell.textLabel?.text = summary
            } else {
                cell.textLabel?.text = NSLocalizedString("No summary available", comment: "")
                cell.textLabel?.textColor = UIColor.grayColor()
            }
        case 2:
            if let tags = feed?.allTags() {
                if indexPath.row == tags.count {
                    cell.textLabel?.text = NSLocalizedString("Add Tag", comment: "")
                    cell.textLabel?.textColor = UIColor.darkGreenColor()
                } else {
                    cell.textLabel?.text = tags[indexPath.row]
                }
            }
        default:
            break
        }

        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return indexPath.section == 2 && indexPath.row != (tableView.numberOfRowsInSection(2) - 1)
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        if feed == nil {
            return nil
        }
        if indexPath.section != 2 {
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
        
        if indexPath.section == 2 {
            if let count = feed?.allTags().count {
                if indexPath.row == count {
                    showTagEditor(indexPath.row)
                }
            }
        }
    }
}
