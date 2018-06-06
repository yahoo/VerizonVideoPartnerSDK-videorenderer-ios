var videos = document.getElementsByTagName('video')
var videoTag = videos.item(0)

var vpaidAd = {}


function initAd() {
    vpaidAd = getVPAIDAd()
    var version = vpaidAd.handshakeVersion()
    if (version == '2.0') {
        vpaidAd.initAd(400, 500, null, null,
                       {
                       AdParameters: '{"videos": [{"mimetype":"video/mp4", "url":"http://cdn.vidible.tv/prod/2018-04/11/5ace36e5be3a230001e24677_v1.mp4"}]}'
                       },
                       {
                       slot: document.getElementById('video-content'),
                       videoSlot: document.getElementById('video-player')
                       });
    } else {
        return "VPAID " + version + " version is not supported"
    }
}

function subscribe() {
    vpaidAd.subscribe(onAdLoaded, 'AdLoaded', this)
    vpaidAd.subscribe(onAdStopped, 'AdStopped', this)
    vpaidAd.subscribe(onAdSkipped, 'AdSkipped', this)
    vpaidAd.subscribe(onAdVideoStart, 'AdStarted', this)
    vpaidAd.subscribe(onAdFirstQuartile, 'AdVideoFirstQuartile', this)
    vpaidAd.subscribe(onAdMidpoint, 'AdVideoMidpoint', this)
    vpaidAd.subscribe(onAdThirdQuartile, 'AdVideoThirdQuartile', this)
    vpaidAd.subscribe(onAdVideoComplete, 'AdVideoComplete', this)
    vpaidAd.subscribe(onAdError, 'AdError', this)
    
    videoTag.ondurationchange = onDurationChange
    videoTag.ontimeupdate = onTimeUpdate
}

function onAdLoaded() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdLoaded',
                                                                      "value" : null
                                                                      }))
}
function onAdStopped() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdStopped',
                                                                      "value" : null
                                                                      }))
}
function onAdVideoStart() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdStarted',
                                                                      "value" : null
                                                                      }))
}
function onAdFirstQuartile() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdVideoFirstQuartile',
                                                                      "value" : null
                                                                      }))
}
function onAdMidpoint() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdVideoMidpoint',
                                                                      "value" : null
                                                                      }))
}
function onAdThirdQuartile() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdVideoThirdQuartile',
                                                                      "value" : null
                                                                      }))
}
function onAdVideoComplete() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdVideoComplete',
                                                                      "value" : null
                                                                      }))
}
function onAdSkipped() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdSkipped',
                                                                      "value" : null
                                                                      }))
}
function onAdError() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdError',
                                                                      "value" : "" + video.error.code
                                                                      }))
}

function onDurationChange () {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdDurationChanged',
                                                                      "value" : "" + videoTag.duration
                                                                      }))
}

function onTimeUpdate () {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdCurrentTimeChanged',
                                                                      "value" : "" + videoTag.currentTime
                                                                      }))
}

function startAd() {
    vpaidAd.startAd()
}

function stopAd() {
    vpaidAd.stopAd()
}

function pauseAd() {
    vpaidAd.pauseAd()
}

function resumeAd() {
    vpaidAd.resumeAd()
}

function finishPlayback() {
    vpaidAd.stopAd()
}

function mute() {
    videoTag.muted = true
}

function unmute() {
    videoTag.muted = false
}



