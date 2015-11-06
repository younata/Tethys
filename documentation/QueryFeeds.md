Query Feeds are a meta-feed - a feed whose source is not a website, but other feeds. Query feeds work by querying each article to see if it belongs. For example, to create a feed that only consists of unread articles, you might write a script that only includes the article if `article.read == true`.

In rNews, Query feeds are written in JavaScript. You just need to return a function that takes a single argument (an Article object) and returns a boolean value:

```javascript
function(article) {
  // Returns true if you haven't yet read the article
  return !article.read
}
```

The `Article` object is a javascript object with the following properties:


|name|type|get/set?|
|----|----|--------|
|title|String|get/set|
|link|String|get/set|
|summary|String|get/set|
|author|String|get/set|
|published|NSDate|get/set|
|updatedAt|NSDate?|get/set|
|identifier|String|get/set|
|content|String|get/set|
|read|Bool|get/set|
|feed|Feed?|get/set|
|flags|Array\<String\>|get|
|enclosures|Array\<Enclosure\>|get|

The `Feed` object is a javascript object with the following properties:

|name|type|get/set?|
|----|----|--------|
|title|String|get set|
|displayTitle|String|get|
|url|NSURL?|get set|
|summary|String|get set|
|displaySummary|String|get|
|query|String?|get set|
|tags|Array\<String\>|get|
|waitPeriod|Int|get set|
|remainingWait|Int|get set|
|articles|Array\<Article\>|get|
|identifier|String|get|
|isQueryFeed|Bool|get|
|unreadArticles|Function returning Array\<Article\>||

And finally, the `Enclosure` object is a javascript object with the following properties:

|name|type|get/set?|
|----|----|--------|
|url|NSURL|get set|
|kind|String|get set|
|data|Data?|get set|
|article|Article?|get set|
|downloaded|Bool|get|

The conversion is done using Apple's JavaScriptCore APIs.