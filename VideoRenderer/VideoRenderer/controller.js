var videos = document.getElementsByTagName('video')
var videoTag = videos.item(0)

videoTag.ondurationchange = function () {
    window.webkit.messageHandlers.observer.postMessage({ 
        body: {
            "name" : "durationChanged",
            "value" : videoTag.duration
        }
    })
}

function updateVideoTagWithSrc(src) {
    videoTag.src = src
}

function playVideo() {
    videoTag.play();
}
