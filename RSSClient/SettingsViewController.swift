//
//  SettingsViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/25/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerClass(SettingsCell.self, forCellReuseIdentifier: "setting")
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (section) {
        case 0:
            return 1
        default:
            return 0
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        switch (indexPath.section) {
        case 0:
            let cell = tableView.dequeueReusableCellWithIdentifier("setting", forIndexPath: indexPath) as SettingsCell
            cell.name = NSLocalizedString("Use iCloud?", comment: "")
            let key = "use_iCloud"
            cell.onChange = {
                NSUserDefaults.standardUserDefaults().setBool($0 as Bool, forKey: key)
            }
            cell.configure(NSUserDefaults.standardUserDefaults().boolForKey(key))
            return cell
        default:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as UITableViewCell
            return cell
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
    }
}
