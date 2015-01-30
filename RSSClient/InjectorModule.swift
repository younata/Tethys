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
        injector.setCreationMethod(DataManager.self) {
            return dataManager
        }

        // Views

        injector.setCreationMethod(UnreadCounter.self) {
            let unreadCounter = UnreadCounter(frame: CGRectZero)
            unreadCounter.setTranslatesAutoresizingMaskIntoConstraints(false)
            return unreadCounter
        }

        injector.setCreationMethod(LoadingView.self) {
            let loadingView = LoadingView(frame: CGRectZero)
            loadingView.setTranslatesAutoresizingMaskIntoConstraints(false)
            return loadingView
        }

        injector.setCreationMethod(TagPickerView.self) {
            let tagPicker = TagPickerView(frame: CGRectZero)
            tagPicker.setTranslatesAutoresizingMaskIntoConstraints(false)
            return tagPicker
        }

        injector.setCreationMethod(FeedsTableViewController.self) {
            return FeedsTableViewController(dataManager: injector.create(DataManager.self) as DataManager)
        }

        injector.setCreationMethod(LocalImportViewController.self) {
            return LocalImportViewController(dataManager: injector.create(DataManager.self) as DataManager)
        }
    }
}