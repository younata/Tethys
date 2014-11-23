//
//  GroupsEditorController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/9/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class GroupsEditorController: UITableViewController, UITextFieldDelegate {
    
    var groupFeeds : [Feed] = []
    var group: Group! = nil {
        didSet {
            groupFeeds = (group.feeds.allObjects as [Feed]).sorted {
                return $0.title < $1.title
            }
        }
    }
    let feeds = DataManager.sharedInstance().feeds()
    var cancelButton : UIBarButtonItem! = nil
    var editButton: UIBarButtonItem! = nil
    
    let nameField = UITextField(frame: CGRectZero)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        editButton = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        self.navigationItem.rightBarButtonItem = self.editButtonItem()
        self.navigationItem.leftBarButtonItem = editButton
        
        cancelButton = UIBarButtonItem(title: NSLocalizedString("End Editing", comment: ""), style: .Plain, target: nameField, action: "resignFirstResponder")
    
        self.navigationItem.titleView = nameField
        nameField.delegate = self
        nameField.backgroundColor = UIColor(white: 0.8, alpha: 0.75)
        nameField.layer.cornerRadius = 5
        nameField.textAlignment = .Center
        nameField.autocapitalizationType = .None
        nameField.text = group.name
    }
    
    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidBeginEditing(textField: UITextField) {
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = cancelButton
        nameField.textAlignment = .Left
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        navigationItem.leftBarButtonItem = editButton
        navigationItem.rightBarButtonItem = self.editButtonItem()
        nameField.textAlignment = .Center
        group.name = nameField.text
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return groupFeeds.count
        } else if section == 1 {
            return feeds.count
        }
        return 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as UITableViewCell
        
        switch (indexPath.section) {
        case 0:
            cell.textLabel?.text = groupFeeds[indexPath.row].title
        case 1:
            cell.textLabel?.text = feeds[indexPath.row].title
        default:
            cell.textLabel?.text = ""
        }

        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return indexPath.section == 0
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let rm = UITableViewRowAction(style: .Default, title: NSLocalizedString("Remove", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
            if indexPath.section == 0 {
                let feed = self.groupFeeds[indexPath.row]
                self.group.removeFeedsObject(feed)
                self.groupFeeds.removeAtIndex(indexPath.row)
                tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
            }
        })
        return [rm]
    }

    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        if fromIndexPath.section == toIndexPath.section {
            return
        }
        if fromIndexPath.section == 0 && toIndexPath.section == 1 {
            let feed = self.groupFeeds[fromIndexPath.row]
            self.group.removeFeedsObject(feed)
            self.groupFeeds.removeAtIndex(fromIndexPath.row)
        } else if fromIndexPath.section == 1 && toIndexPath.section == 1 {
            let feed = feeds[fromIndexPath.row]
            DataManager.sharedInstance().addFeed(feed, toGroup: group)
        }
        tableView.reloadSections(NSIndexSet(indexesInRange: NSMakeRange(0, 2)), withRowAnimation: .Automatic)
    }

    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
}
