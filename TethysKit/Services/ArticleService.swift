import CBGPromise
import Result

public protocol ArticleService {
    func feed(of article: Article) -> Future<Result<Feed, TethysError>>
    func authors(of article: Article) -> String

    func related(to article: Article) -> Future<Result<AnyCollection<Article>, TethysError>>
    func recordRelation(of article: Article, to otherArticle: Article) -> Future<Result<Void, TethysError>>
    func removeRelation(of article: Article, to otherArticle: Article) -> Future<Result<Void, TethysError>>
}

import RealmSwift

final class RealmArticleService: ArticleService {
    private let realm: Realm
    private let mainQueue: OperationQueue
    private let workQueue: OperationQueue

    init(realm: Realm, mainQueue: OperationQueue, workQueue: OperationQueue) {
        self.realm = realm
        self.mainQueue = mainQueue
        self.workQueue = workQueue
    }

    func feed(of article: Article) -> Future<Result<Feed, TethysError>> {
        let promise = Promise<Result<Feed, TethysError>>()
        self.workQueue.addOperation {
            guard let feed = self.realm.objects(RealmArticle.self).filter("id = %@", article.identifier).first?.feed else {
                self.mainQueue.addOperation {
                    promise.resolve(.failure(TethysError.database(DatabaseError.entryNotFound)))
                }
                return
            }
            self.mainQueue.addOperation {
                promise.resolve(.success(Feed(realmFeed: feed)))
            }
        }
        return promise.future
    }

    func authors(of article: Article) -> String {
        return article.authors.map { $0.description }.joined(separator: ", ")
    }

    func related(to article: Article) -> Future<Result<AnyCollection<Article>, TethysError>> {
        let promise = Promise<Result<AnyCollection<Article>, TethysError>>()
        self.workQueue.addOperation {
            guard let realmArticle = self.realm.object(ofType: RealmArticle.self, forPrimaryKey: article.identifier) else {
                self.mainQueue.addOperation {
                    promise.resolve(.failure(.database(.entryNotFound)))
                }
                return
            }
            let items = AnyCollection(Array(realmArticle.relatedArticles.map {
                return Article(realmArticle: $0, feed: nil)
            }))
            self.mainQueue.addOperation {
                promise.resolve(.success(items))
            }
        }
        return promise.future
    }

    func recordRelation(of article: Article, to otherArticle: Article) -> Future<Result<Void, TethysError>> {
        let promise = Promise<Result<Void, TethysError>>()

        self.workQueue.addOperation {
            guard let article1 = self.realm.object(ofType: RealmArticle.self, forPrimaryKey: article.identifier) else {
                self.mainQueue.addOperation {
                    promise.resolve(.failure(.database(.entryNotFound)))
                }
                return
            }
            guard let article2 = self.realm.object(ofType: RealmArticle.self,
                                                   forPrimaryKey: otherArticle.identifier) else {
                                                    self.mainQueue.addOperation {
                                                        promise.resolve(.failure(.database(.entryNotFound)))
                                                    }
                                                    return
            }

            self.realm.beginWrite()
            if !article1.relatedArticles.contains(article2) {
                article1.relatedArticles.append(article2)
            }
            if !article2.relatedArticles.contains(article1) {
                article2.relatedArticles.append(article1)
            }

            do {
                try self.realm.commitWrite()
            } catch let exception {
                print("Exception writing to realm: \(exception)")
                dump(exception)
                self.mainQueue.addOperation {
                    promise.resolve(.failure(.database(.unknown)))
                }
                return
            }
            self.mainQueue.addOperation {
                promise.resolve(.success())
            }
        }

        return promise.future
    }

    func removeRelation(of article: Article, to otherArticle: Article) -> Future<Result<Void, TethysError>> {
        let promise = Promise<Result<Void, TethysError>>()
        self.workQueue.addOperation {
            guard let article1 = self.realm.object(ofType: RealmArticle.self, forPrimaryKey: article.identifier) else {
                self.mainQueue.addOperation {
                    promise.resolve(.failure(.database(.entryNotFound)))
                }
                return
            }
            guard let article2 = self.realm.object(ofType: RealmArticle.self,
                                                   forPrimaryKey: otherArticle.identifier) else {
                self.mainQueue.addOperation {
                    promise.resolve(.failure(.database(.entryNotFound)))
                }
                return
            }

            self.realm.beginWrite()
            if let article2Index = article1.relatedArticles.index(of: article2) {
                article1.relatedArticles.remove(at: article2Index)
            }
            if let article1Index = article2.relatedArticles.index(of: article1) {
                article2.relatedArticles.remove(at: article1Index)
            }

            do {
                try self.realm.commitWrite()
            } catch let exception {
                print("Exception writing to realm: \(exception)")
                dump(exception)
                self.mainQueue.addOperation {
                    promise.resolve(.failure(.database(.unknown)))
                }
                return
            }
            self.mainQueue.addOperation {
                promise.resolve(.success())
            }
        }
        return promise.future
    }
}
