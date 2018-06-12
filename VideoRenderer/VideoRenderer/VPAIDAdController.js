var videos = document.getElementsByTagName('video')
var videoTag = videos.item(0)
var element = document.getElementById('video-content')
var script = document.createElement('script')

var vpaidAd = {}
var version = 0

function initAd(url, adParameters) {
    script.type = "application/javascript"
    script.src = url
    script.onload = function() {
        vpaidAd = getVPAIDAd()
        
        vpaidAd.subscribe(onAdLoaded, 'AdLoaded', this)
        vpaidAd.subscribe(onAdStopped, 'AdStopped', this)
        vpaidAd.subscribe(onAdSkipped, 'AdSkipped', this)
        vpaidAd.subscribe(onAdVideoStart, 'AdStarted', this)
        vpaidAd.subscribe(onAdError, 'AdError', this)
        videoTag.ondurationchange = onDurationChange
        videoTag.ontimeupdate = onTimeUpdate
        
        vpaidAd.initAd(1000, 1000, 'normal', null,
                       {
                       AdParameters: adParameters
                       },
                       {
                       slot: document.getElementById('video-content'),
                       videoSlot: document.getElementById('video-player')
                       });
    }
    element.appendChild(script)
}

function onAdLoaded() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdLoaded',
                                                                      "value" : null
                                                                      }))
}
function onAdNotSupported(version) {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdNotSupported',
                                                                      "value" : "" + version
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
    vpaidAd.resizeAd(400,500,'normal')
}

function resumeAd() {
    vpaidAd.resumeAd()
    vpaidAd.resizeAd(700,700,'normal')
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



