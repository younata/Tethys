function autoDiscoverRSS() {
    var res = document.getElementsByTagName("link")
    var links = []
    for (var i = 0; i < res.length; i++) {
        if (res[i].type == "application/rss+xml" || res[i].type == "application/atom+xml") {
            links.push(res[i].href)
        }
    }
    return links
}

autoDiscoverRSS();