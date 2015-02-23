//
//  SpecHelper.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation
import Ra

func injector() -> Injector {
    let injector = Ra.Injector()
    injector.bind(DataManager.self) {
        return DataManagerMock()
    }
    return injector
}