##Lepton

OPML parser written in swift 2.0.

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

###Usage

```swift
import Lepton

let myOPMLFile = String(contentsOfURL: "https://example.com/feeds.opml", encoding: NSUTF8StringEncoding)
let parser = Parser(string: myOPMLFile)

parser.success {
    print("Parsed: \($0)")
}
parser.failure {
    print("Failed to parse: \($0)")
}

parser.main() // or add to an NSOperationQueue
```

Lepton supports standard rss/atom feeds, as well as [rNews-style](https://github.com/younata/RSSClient) query feeds (javascript that can be used to construct a meta feed consisting of articles from other feeds).

Lepton is used with Muon in rNews, but they are independent of each other.

###Installing

####Carthage

Swift 2.0:

* add `github "younata/Lepton"`

####Cocoapods

Make sure that `user_frameworks!` is defined in your Podfile

Swift 2.0:

* add `Pod "Lepton" :git => "https://github.com/younata/Lepton.git"`

###ChangeLog

#### 0.1.0

- Initial release.

### License

[MIT](LICENSE)