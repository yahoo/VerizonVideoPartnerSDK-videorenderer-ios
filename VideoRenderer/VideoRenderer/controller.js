var videos = document.getElementsByTagName('video')
var videoTag = videos.item(0)

videoTag.ondurationchange = function () {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
            "name" : "durationChanged",
            "value" : videoTag.duration
    }))
}
videoTag.ontimeupdate = function () {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
            "name" : "currentTimeChanged",
            "value" : videoTag.currentTime
    }))
}

videoTag.onended = function () {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
            "name" : "playbackFinished",
            "value" : null
    }))
}

videoTag.oncanplay = function () {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
            "name" : "playbackReady",
            "value" : null
    }))
}
videoTag.onerror = function () {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
            "name" : "playbackError",
            "value" : video.error.code
    }))
}

videoTag.onratechange = function () {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
            "name" : "playbackRateChanged",
            "value" : video.playbackRate
    }))
}

function updateVideoTagWithSrc(src) {
    videoTag.src = src
}

function playVideo() {
    videoTag.play();
}

function pauseVideo() {
    videoTag.pause()
}

function finishPlayback() {
    videoTag.ended = true
}

function mute() {
    videoTag.muted = true
}

function unmute() {
    videoTag.muted = false
}

