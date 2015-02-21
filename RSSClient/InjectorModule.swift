//
//  InjectorModule.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation
import Ra

class InjectorModule {
    func configure(injector: Ra.Injector) {
        let dataHelper = CoreDataHelper()
        let dataManager = DataManager(dataHelper: dataHelper)
        injector.bind(DataManager.self, to: dataManager)

        // Views

        injector.bind(UnreadCounter.self) {
            let unreadCounter = UnreadCounter(frame: CGRectZero);
            unreadCounter.setTranslatesAutoresizingMaskIntoConstraints(false);
            return unreadCounter;
        }

        injector.bind(LoadingView.self) {
            let loadingView = LoadingView(frame: CGRectZero)
            loadingView.setTranslatesAutoresizingMaskIntoConstraints(false)
            return loadingView
        }

        injector.bind(TagPickerView.self) {
            let tagPicker = TagPickerView(frame: CGRectZero)
            tagPicker.setTranslatesAutoresizingMaskIntoConstraints(false)
            return tagPicker
        }

        injector.bind(FeedsTableViewController.self) {
            let feeds = FeedsTableViewController()
            feeds.dataManager = injector.create(DataManager.self) as DataManager
            return feeds
        }

        injector.bind(LocalImportViewController.self) {
            let localImport = LocalImportViewController()
            localImport.dataManager = injector.create(DataManager.self) as DataManager
            return localImport
        }
    }
}