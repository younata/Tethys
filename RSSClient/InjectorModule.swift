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
    }
}