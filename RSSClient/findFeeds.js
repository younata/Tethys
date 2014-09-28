function autoDiscoverRSS() {
    var res = document.getElementsByTagName("link")
    for (var i = 0; i < res.length; i++) {
        if (res[i].type == "application/rss+xml" || res[i].type == "application/atom+xml") {
            return res[i].href
        }
    }
}

autoDiscoverRSS();