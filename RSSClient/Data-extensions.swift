import Foundation

//extension CoreDataFeed {    
//    func asDict() -> [String: AnyObject] {
//        var ret = asDictNoArticles()
//        var theArticles : [[String: AnyObject]] = []
//        if let articles = self.articles as? Set<CoreDataArticle> {
//            for article in Array<CoreDataArticle>(articles) {
//                theArticles.append(article.asDictNoFeed())
//            }
//        }
//        ret["articles"] = theArticles
//        return ret
//    }
//    
//    func asDictNoArticles() -> [String: AnyObject] {
//        var ret : [String: AnyObject] = [:]
//        ret["title"] = title ?? ""
//        ret["url"] = url ?? ""
//        ret["summary"] = summary ?? ""
//        ret["query"] = query ?? ""
//        ret["tags"] = allTags()
//        ret["id"] = self.objectID.description
//        ret["remainingWait"] = remainingWait ?? 0
//        ret["waitPeriod"] = waitPeriod ?? 0
//        return ret
//    }
//}

//extension CoreDataArticle {
//    func asDict() -> [String: AnyObject] {
//        var ret = asDictNoFeed()
//        if let f = feed {
//            ret["feed"] = f.asDictNoArticles()
//        }
//        return ret
//    }
//    
//    func asDictNoFeed() -> [String: AnyObject] {
//        var ret : [String: AnyObject] = [:]
//        ret["title"] = title ?? ""
//        ret["link"] = link ?? ""
//        ret["summary"] = summary ?? ""
//        ret["author"] = author ?? ""
//        ret["published"] = published?.description ?? ""
//        ret["updatedAt"] = updatedAt?.description ?? ""
//        ret["identifier"] = objectID.URIRepresentation()
//        ret["content"] = content ?? ""
//        ret["read"] = read
//        ret["flags"] = allFlags()
//        ret["id"] = self.objectID.description
//        return ret
//    }
//}