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
        vpaidAd.subscribe(onAdStarted, 'AdStarted', this)
        vpaidAd.subscribe(onAdError, 'AdError', this)
        
        vpaidAd.subscribe(onDurationChange, 'AdDurationChange', this)
        vpaidAd.subscribe(onTimeUpdate, 'AdRemainingTimeChange', this)
        vpaidAd.subscribe(onAdPaused, 'AdPaused', this)
        vpaidAd.subscribe(onAdResumed, 'AdPlaying', this)
        
        vpaidAd.subscribe(onAdImpression, 'AdImpression', this)
        vpaidAd.subscribe(onAdVideoStart, 'AdVideoStart', this)
        vpaidAd.subscribe(onAdVideoFirstQuartile, 'AdVideoFirstQuartile', this)
        vpaidAd.subscribe(onAdVideoMidpoint, 'AdVideoMidpoint', this)
        vpaidAd.subscribe(onAdVideoThirdQuartile, 'AdVideoThirdQuartile', this)
        vpaidAd.subscribe(onAdVideoComplete, 'AdVideoComplete', this)
        vpaidAd.subscribe(onAdClickThru, 'AdClickThru', this)
        
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
function onAdStarted() {
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

function onDurationChange() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdDurationChange',
                                                                      "value" : "" + vpaidAd.getAdDuration()
                                                                      }))
}

function onTimeUpdate() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdRemainingTimeChange',
                                                                      "value" : "" + vpaidAd.getAdRemainingTime()
                                                                      }))
}
function onAdPaused() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdPaused',
                                                                      "value" : null
                                                                      }))
}

function onAdResumed() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdResumed',
                                                                      "value" : null
                                                                      }))
}

function onAdImpression() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdImpression',
                                                                      "value" : null
                                                                      }))
}
function onAdVideoStart() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdVideoStart',
                                                                      "value" : null
                                                                      }))
}
function onAdVideoFirstQuartile() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdVideoFirstQuartile',
                                                                      "value" : null
                                                                      }))
}
function onAdVideoMidpoint() {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdVideoMidpoint',
                                                                      "value" : null
                                                                      }))
}
function onAdVideoThirdQuartile() {
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

function onAdClickThru(url, id, isPlayerHandles) {
    window.webkit.messageHandlers.observer.postMessage(JSON.stringify({
                                                                      "name" : 'AdClickThru',
                                                                      "value" : "" + url
                                                                      }))
}

function startAd() {
    vpaidAd.startAd()
}

function pauseAd() {
    vpaidAd.pauseAd()
}

function resumeAd() {
    vpaidAd.resumeAd()
}

function finishPlayback() {
    vpaidAd.unsubscribe('AdLoaded')
    vpaidAd.unsubscribe('AdStopped')
    vpaidAd.unsubscribe('AdSkipped')
    vpaidAd.unsubscribe('AdStarted')
    vpaidAd.unsubscribe('AdError')
    
    vpaidAd.unsubscribe('AdDurationChange')
    vpaidAd.unsubscribe('AdRemainingTimeChange')
    vpaidAd.unsubscribe('AdPaused')
    vpaidAd.unsubscribe('AdPlaying')
    
    vpaidAd.unsubscribe('AdImpression')
    vpaidAd.unsubscribe('AdVideoStart')
    vpaidAd.unsubscribe('AdVideoFirstQuartile')
    vpaidAd.unsubscribe('AdVideoMidpoint')
    vpaidAd.unsubscribe('AdVideoThirdQuartile')
    vpaidAd.unsubscribe('AdVideoComplete')
    vpaidAd.unsubscribe('AdClickThru'
    vpaidAd.stopAd()
}

function mute() {
    //vpaidAd.setAdVolume(0)
    videoTag.muted = true
}

function unmute() {
    //vpaidAd.setAdVolume(100)
    videoTag.muted = false
}



