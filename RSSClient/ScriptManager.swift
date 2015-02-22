//
//  ScriptManager.swift
//  RSSClient
//
//  Created by Rachel Brindle on 2/22/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import UIKit
import JavaScriptCore

class ScriptManager: NSObject {
    func setUpContext(ctx: JSContext) -> JSContext {
        ctx.exceptionHandler = {(context, value) in
            println("Javascript exception: \(value)")
        }
        ctx.evaluateScript("var console = {}")
        let console = ctx.objectForKeyedSubscript("console")
        var block : @objc_block (NSString) -> Void = {(message: NSString) in println("\(message)")}
        console.setObject(unsafeBitCast(block, AnyObject.self), forKeyedSubscript: "log")
        let script = "var include = function(article) { return true }"
        ctx.evaluateScript(script)
        return ctx
    }
    
    func console(ctx: JSContext) {
        ctx.evaluateScript("var console = {}")
        let console = ctx.objectForKeyedSubscript("console")
        var block : @objc_block (NSString) -> Void = {(message: NSString) in println("\(message)")}
        console.setObject(unsafeBitCast(block, AnyObject.self), forKeyedSubscript: "log")
    }
    
    func fetching(ctx: JSContext, isBackground: Bool) {
        let key = isBackground ? kBackgroundManagedObjectContext : kMainManagedObjectContext
        let moc = self.injector!.create(key) as NSManagedObjectContext
        let dataHelper = CoreDataHelper()
        
        ctx.evaluateScript("var data = {onNewFeed: [], onNewArticle: []}")
        let data = ctx.objectForKeyedSubscript("data")
        
        var articles : @objc_block (Void) -> [NSDictionary] = {
            return (dataHelper.entities("Article", matchingPredicate: NSPredicate(value: true), managedObjectContext: moc)! as [Article]).map {return $0.asDict()}
        }
        data.setObject(unsafeBitCast(articles, AnyObject.self), forKeyedSubscript: "articles")
        
        var queryArticles : @objc_block (NSString, [NSObject]) -> [NSDictionary] = {(query, args) in
            let predicate = NSPredicate(format: query, argumentArray: args)
            return (dataHelper.entities("Article", matchingPredicate: predicate, managedObjectContext: moc)! as [Article]).map {$0.asDict()}
        }
        data.setObject(unsafeBitCast(queryArticles, AnyObject.self), forKeyedSubscript: "articlesMatchingQuery")
        
        var feeds : @objc_block (Void) -> [NSDictionary] = {
            return (dataHelper.entities("Feed", matchingPredicate: NSPredicate(value: true), managedObjectContext: moc)! as [Feed]).map {return $0.asDict()}
        }
        data.setObject(unsafeBitCast(feeds, AnyObject.self), forKeyedSubscript: "feeds")
        
        var queryFeeds : @objc_block (NSString, [NSObject]) -> [NSDictionary] = {(query, args) in // queries for feeds, not to be confused with query feeds.
            let predicate = NSPredicate(format: query, argumentArray: args)
            return (dataHelper.entities("Feed", matchingPredicate: predicate, managedObjectContext: moc)! as [Feed]).map {$0.asDict()}
        }
        data.setObject(unsafeBitCast(queryFeeds, AnyObject.self), forKeyedSubscript: "feedsMatchingQuery")
        
        var addOnNewFeed : @objc_block (@objc_block (NSDictionary) -> Void) -> Void = {(block) in
            var onNewFeed = data.objectForKeyedSubscript("onNewFeed").toArray()
            onNewFeed.append(unsafeBitCast(block, AnyObject.self))
            data.setObject(onNewFeed, forKeyedSubscript: "onNewFeed")
        }
        data.setObject(unsafeBitCast(addOnNewFeed, AnyObject.self), forKeyedSubscript: "onNewFeed")
    }
}
