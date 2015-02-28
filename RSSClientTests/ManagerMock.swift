//
//  ManagerMock.swift
//  RSSClient
//
//  Created by Rachel Brindle on 2/27/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

class RequestMock : Request {
    let responseObj : AnyObject

    init(response: AnyObject) {
        self.responseObj = response
        super.init(session: NSURLSession(), task: NSURLSessionTask())
    }

    override func progress(#closure: ((Int64, Int64, Int64) -> Void)?) -> Self {
        if let cl = closure {
            cl(0, 0, 0)
        }
        return self
    }

    override func response(completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        completionHandler(NSURLRequest(), nil, responseObj, nil)
        return self
    }
}

class ManagerMock : Manager {
    var responseObj : AnyObject = ""

    var callsToRequest: Int = 0

    required init(configuration: NSURLSessionConfiguration?) {
        super.init(configuration: configuration)
    }

    override func request(method: Method, _ URLString: URLStringConvertible, parameters: [String : AnyObject]?, encoding: ParameterEncoding) -> Request {
        callsToRequest++
        return RequestMock(response: responseObj)
    }
}