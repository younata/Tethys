function autoDiscoverICO() {
    var res = document.getElementsByTagName("link")
    for (var i = 0; i < res.length; i++) {
        if (res[i].rel == "shortcut icon") {
            return res[i].href
        }
    }
}

autoDiscoverICO();